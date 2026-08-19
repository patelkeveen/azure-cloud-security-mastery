// =============================================================================
// Hybrid identity lab - one domain controller, one sync server.
//
// WHY IT IS SHAPED LIKE THIS (this is the production-level part):
//   1. The DC has NO PUBLIC IP. A domain controller is never internet-facing.
//      You reach it privately, from the sync server, which is the jump host.
//   2. RDP is allowed from ONE /32 - yours - not from Internet. Exposed 3389 is
//      still one of the most reliably exploited things on the internet.
//   3. The DC gets a STATIC private IP, allocated by AZURE, never inside the
//      guest OS. Setting a static IP inside a Windows guest on Azure breaks its
//      networking - the platform DHCP lease IS the correct config.
//   4. Everything is tagged with an expiry. Untagged lab resources are how
//      personal cloud bills happen.
//   5. Auto-shutdown is on by default. Cost control is a design decision, not a
//      thing you remember to do at 2am.
//
// COST (live retail, centralindia, pulled 2026-08-20):
//   B2s Windows = INR 5.0503/hr. Two of them 24/7 for 21 days = ~INR 5,091.
//   Against a INR 19,130 credit expiring 2026-09-10 that is ~27%.
//   Money is NOT the binding constraint here. vCPU quota and your time are.
// =============================================================================

@description('Azure region. Keep it the same as your existing lab RG.')
param location string = resourceGroup().location

@description('Local admin username for both VMs. NOT "administrator" - that name is disallowed by Azure.')
param adminUsername string = 'labadmin'

@description('Local admin password. 12+ chars, 3 of 4 character classes.')
@secure()
param adminPassword string

@description('YOUR public IP as CIDR, e.g. 203.0.113.45/32. The deploy script fills this in.')
param allowedSourceIp string

@description('VM size. B2s = 2 vCPU / 4 GB, enough for AD DS + Entra Connect in a lab.')
param vmSize string = 'Standard_B2s'

@description('Deallocate both VMs at this time daily (24h, HHmm).')
param autoShutdownTime string = '2100'

@description('IANA-ish timezone name used by the DevTestLab schedule resource.')
param autoShutdownTimeZone string = 'India Standard Time'

@description('Hard expiry tag. Everything here should be deleted by this date.')
param expiresTag string = '2026-09-10'

@description('Prefix for every resource name.')
param prefix string = 'sc300lab'

// -----------------------------------------------------------------------------
// 10.50.1.4 is the first address Azure lets you use in a /24.
// Azure reserves .0 (network), .1 (gateway), .2 and .3 (DNS/platform), and the
// broadcast address. This trips people up constantly - it is not a /24 with 254
// usable addresses, it is 251.
// -----------------------------------------------------------------------------
var vnetAddressSpace = '10.50.0.0/16'
var subnetPrefix     = '10.50.1.0/24'
var dcStaticIp       = '10.50.1.4'

var commonTags = {
  owner:       'keveen'
  environment: 'lab'
  expires:     expiresTag
  costCenter:  'personal'
  purpose:     'sc300-hybrid-identity'
  managedBy:   'bicep'
}

// -----------------------------------------------------------------------------
// Network security group.
// Rule order matters: lower priority number wins. The explicit deny at 4096 is
// redundant against Azure's default rules, but stating it is the habit you want
// - an NSG you have to reason about is an NSG that will eventually surprise you.
// -----------------------------------------------------------------------------
resource nsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: '${prefix}-nsg'
  location: location
  tags: commonTags
  properties: {
    securityRules: [
      {
        name: 'Allow-RDP-From-My-IP-Only'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: allowedSourceIp   // <- the whole control
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '3389'
          description: 'RDP from one operator IP. Re-run the deploy script when your ISP rotates it.'
        }
      }
      {
        name: 'Deny-All-Other-Inbound'
        properties: {
          priority: 4000
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
          description: 'Explicit. Intra-VNet traffic still flows via the default AllowVnetInBound rule at 65000.'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: '${prefix}-vnet'
  location: location
  tags: commonTags
  properties: {
    addressSpace: { addressPrefixes: [ vnetAddressSpace ] }
    // NOTE: dhcpOptions.dnsServers is deliberately NOT set here.
    // The DC does not exist yet, so pointing DNS at it now would break the
    // sync server's ability to reach the internet and install anything.
    // Deploy-HybridLab.ps1 sets it AFTER the forest is promoted. Order matters.
    subnets: [
      {
        name: 'snet-servers'
        properties: {
          addressPrefix: subnetPrefix
          networkSecurityGroup: { id: nsg.id }
        }
      }
    ]
  }
}

// Only the sync server gets a public IP. The DC does not. That is the point.
resource syncPip 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: '${prefix}-sync01-pip'
  location: location
  tags: commonTags
  sku: { name: 'Standard' }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: { domainNameLabel: '${prefix}-sync01-${uniqueString(resourceGroup().id)}' }
  }
}

resource dcNic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: '${prefix}-dc01-nic'
  location: location
  tags: commonTags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          // Static AT THE AZURE LAYER. Inside Windows this still shows as DHCP,
          // and that is correct - do not "fix" it in the guest.
          privateIPAllocationMethod: 'Static'
          privateIPAddress: dcStaticIp
          subnet: { id: vnet.properties.subnets[0].id }
          // no publicIPAddress - intentional
        }
      }
    ]
  }
}

resource syncNic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: '${prefix}-sync01-nic'
  location: location
  tags: commonTags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: { id: vnet.properties.subnets[0].id }
          publicIPAddress: { id: syncPip.id }
        }
      }
    ]
  }
}

// -----------------------------------------------------------------------------
// The two VMs.
// StandardSSD_LRS, not Premium: a lab DC does not need P-tier IOPS, and Premium
// roughly doubles the disk line on the bill for zero learning value.
// -----------------------------------------------------------------------------
var imageRef = {
  publisher: 'MicrosoftWindowsServer'
  offer:     'WindowsServer'
  sku:       '2022-datacenter-azure-edition'
  version:   'latest'
}

resource dcVm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: '${prefix}-dc01'
  location: location
  tags: union(commonTags, { role: 'domain-controller' })
  properties: {
    hardwareProfile: { vmSize: vmSize }
    osProfile: {
      computerName: 'DC01'
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
        provisionVMAgent: true
      }
    }
    storageProfile: {
      imageReference: imageRef
      osDisk: {
        createOption: 'FromImage'
        managedDisk: { storageAccountType: 'StandardSSD_LRS' }
        deleteOption: 'Delete'   // no orphaned disks quietly billing after you delete the VM
      }
    }
    networkProfile: {
      networkInterfaces: [ { id: dcNic.id, properties: { deleteOption: 'Delete' } } ]
    }
    securityProfile: {
      securityType: 'TrustedLaunch'
      uefiSettings: { secureBootEnabled: true, vTpmEnabled: true }
    }
  }
}

resource syncVm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: '${prefix}-sync01'
  location: location
  tags: union(commonTags, { role: 'entra-connect-sync' })
  properties: {
    hardwareProfile: { vmSize: vmSize }
    osProfile: {
      computerName: 'SYNC01'
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
        provisionVMAgent: true
      }
    }
    storageProfile: {
      imageReference: imageRef
      osDisk: {
        createOption: 'FromImage'
        managedDisk: { storageAccountType: 'StandardSSD_LRS' }
        deleteOption: 'Delete'
      }
    }
    networkProfile: {
      networkInterfaces: [ { id: syncNic.id, properties: { deleteOption: 'Delete' } } ]
    }
    securityProfile: {
      securityType: 'TrustedLaunch'
      uefiSettings: { secureBootEnabled: true, vTpmEnabled: true }
    }
  }
}

// -----------------------------------------------------------------------------
// Auto-shutdown. Deallocated VMs bill only for disk (~INR 25/day each here),
// so this is roughly a 4x cost reduction if you work office hours.
// There is deliberately NO auto-START: forgetting to start costs you nothing.
// -----------------------------------------------------------------------------
resource dcShutdown 'Microsoft.DevTestLab/schedules@2018-09-15' = {
  name: 'shutdown-computevm-${dcVm.name}'
  location: location
  tags: commonTags
  properties: {
    status: 'Enabled'
    taskType: 'ComputeVmShutdownTask'
    dailyRecurrence: { time: autoShutdownTime }
    timeZoneId: autoShutdownTimeZone
    targetResourceId: dcVm.id
    notificationSettings: { status: 'Disabled', timeInMinutes: 30 }
  }
}

resource syncShutdown 'Microsoft.DevTestLab/schedules@2018-09-15' = {
  name: 'shutdown-computevm-${syncVm.name}'
  location: location
  tags: commonTags
  properties: {
    status: 'Enabled'
    taskType: 'ComputeVmShutdownTask'
    dailyRecurrence: { time: autoShutdownTime }
    timeZoneId: autoShutdownTimeZone
    targetResourceId: syncVm.id
    notificationSettings: { status: 'Disabled', timeInMinutes: 30 }
  }
}

output syncPublicFqdn string   = syncPip.properties.dnsSettings.fqdn
output syncPublicIp string     = syncPip.properties.ipAddress
output dcPrivateIp string      = dcStaticIp
output vnetName string         = vnet.name
output rdpCommand string       = 'mstsc /v:${syncPip.properties.dnsSettings.fqdn}'
output nextStep string         = 'RDP to sync01, then run Initialize-LabForest.ps1 ON dc01 (reach it at ${dcStaticIp} via mstsc from sync01).'
