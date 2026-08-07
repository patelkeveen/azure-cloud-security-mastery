# Slice 4 — Azure Secure Workload

Scenario: deploy a private application workload with VNet, subnets, NSGs, UDRs, private endpoint, private DNS, monitoring, and security operations.

## Required layers

Decision Stack, Azure Well-Architected review, HLD/LLD, IaC, identity, network path, data path, egress, logs, alerts, cost, capacity, backup, restore, and DR.

## Failure scenario

A missing private-DNS link breaks database resolution, while an unauthorized NSG change exposes a management port. Repair both, prove the data path, detect the change, and record prevention.

## Evidence

IaC, architecture diagrams, deployment logs, DNS tests, flow evidence, KQL detection, remediation, cost review, restore test, and runbook.
