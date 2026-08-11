# Virtualization and Containers

> Written to [`CONTENT-STANDARD.md`](../../CONTENT-STANDARD.md).
> Applies the boundary model from
> [`../computing-and-operating-systems/`](../computing-and-operating-systems/) §1.
> Feeds [`../../30-identity-and-nhi/workload-identity-for-aks/`](../../30-identity-and-nhi/workload-identity-for-aks/).

---

## 1. ⭐ The distinction that decides everything

> **A VM is virtualised hardware. ⭐ A container is a process with a restricted view.**

```
VM                                  CONTAINER
┌──────────────┐                    ┌──────────────┐
│ guest kernel │ ⭐ its OWN kernel   │  the process │ ⭐ NO kernel of its own
├──────────────┤                    ├──────────────┤
│  hypervisor  │ hardware-enforced  │ ⭐ SHARED HOST KERNEL
└──────────────┘                    └──────────────┘
```

⭐ **A container is not a small VM.** It is a normal Linux process that has been given:

| Mechanism | What it restricts |
|---|---|
| **Namespaces** | ⭐ what the process can **see** — PIDs, mounts, network, users |
| **cgroups** | what it can **consume** — CPU, memory, IO |
| **Capabilities / seccomp** | ⭐ which **syscalls** it may make |

**Everything else is shared with the host, most importantly the kernel.**

⭐ **So the security consequence is a single sentence:** *a container escape is a kernel bug or a
misconfiguration, and the kernel is shared with every other container on that host.* **A VM escape
requires defeating hardware-assisted virtualisation; a container escape sometimes requires only a
flag.**

> ⭐ **This is the honest answer to "are containers secure?"** — they are an **isolation** mechanism,
> not a **security boundary of the same strength as a VM**. Where you need a hard boundary between
> tenants, the boundary is a VM (or a sandboxed runtime), not a namespace.

---

## 2. The three flags that undo it all

⭐ **Most container compromises are not exploits. They are configuration:**

| Setting | ⭐ What it actually means |
|---|---|
| `--privileged` | ⭐ **All capabilities, host devices** — effectively root on the host |
| `-v /:/host` or `/var/run/docker.sock` | ⭐ **The socket is the API** — mount it and you control the daemon |
| `hostPID` / `hostNetwork` / `hostIPC` | Removes the namespace that was doing the isolating |
| Running as **root** in the container | ⭐ Root inside maps to root outside unless user namespaces are on |

⭐ **Mounting the Docker socket is the one that looks reasonable.** It is how "a container that builds
containers" is usually done, and it is **equivalent to giving that container root on the host** —
because the daemon runs as root and will start a privileged container on request.

```bash
# The audit. Anything true here is a finding, not a preference.
docker ps -q | xargs -r docker inspect --format \
 '{{.Name}} privileged={{.HostConfig.Privileged}} pid={{.HostConfig.PidMode}} \
net={{.HostConfig.NetworkMode}} user={{.Config.User}} mounts={{range .Mounts}}{{.Source}} {{end}}'
```

```
/ci-runner   privileged=true  pid=host  net=host  user=       mounts=/var/run/docker.sock /
                    ▲              ▲        ▲         ▲              ▲
                    └──────────────┴────────┴─────────┴──────────────┘
                          ⭐ five findings on one line — this is root on the host
```

⭐ **`user=` being empty means root.** It is the most common finding and the easiest fix, and it is
the container equivalent of the same-token problem in
[`../computing-and-operating-systems/`](../computing-and-operating-systems/) §3.

---

## 3. Worked example — Kubernetes, where the identity questions land

```bash
# ① Which workloads are privileged or host-namespaced?
kubectl get pods -A -o json | jq -r '
  .items[] | select(
    (.spec.hostPID // false) or (.spec.hostNetwork // false) or
    (.spec.containers[]?.securityContext.privileged // false)
  ) | "\(.metadata.namespace)/\(.metadata.name)"'

# ② ⭐ Which service accounts can create pods? (= can run anything, as anything)
kubectl get clusterrolebindings -o json | jq -r '
  .subjects[]? as $s | select(.roleRef.name=="cluster-admin") |
  "\($s.kind) \($s.name)"'

# ③ ⭐ Is the default service account token auto-mounted into every pod?
kubectl get sa default -A -o json | jq -r '
  "\(.metadata.namespace) automount=\(.automountServiceAccountToken // "true(default)")"'
```

⭐ **Step ③ is the finding people miss.** By default a pod receives a mounted service account token —
so **anything that achieves code execution in any pod immediately holds a cluster credential.** Set
`automountServiceAccountToken: false` unless the pod needs the API.

⭐ **And "can create pods" is effectively cluster-admin**, because a pod can be created privileged,
with host mounts, running as root. **A role that grants pod creation is not a limited role**, which is
the same shape as the `sudo … /usr/bin/find` finding in
[`../linux-and-windows/`](../linux-and-windows/) §4 — ⭐ **a control that looks narrow and is not.**

**Then the identity question, which is where your background matters most:**

```bash
# ④ Are workloads using federated identity, or a mounted secret?
kubectl get sa -A -o json | jq -r '
  .items[] | select(.metadata.annotations["azure.workload.identity/client-id"]) |
  "\(.metadata.namespace)/\(.metadata.name) → \(.metadata.annotations["azure.workload.identity/client-id"])"'
```

⭐ **A service account annotated for workload identity federation holds no secret at all** — it
exchanges a projected Kubernetes token for an Entra token. **Anything not on that list is probably
carrying a stored credential**, which is the finding in
[`../../30-identity-and-nhi/workload-identity-for-aks/`](../../30-identity-and-nhi/workload-identity-for-aks/).

---

## 4. ⭐ The image is a supply chain

**An image is a stack of layers, and you inherit every one of them:**

```
FROM node:20            ⭐ someone else's OS + libraries, updated when THEY choose
  ├─ apt-get install …  more third-party code
  ├─ npm install        ⭐ hundreds of packages, transitively
  └─ COPY . .           ⭐ including .env and .git if you forgot .dockerignore
```

| Control | ⭐ Why |
|---|---|
| ⭐ **Pin by digest**, not tag | `node:20` moves; `node@sha256:…` cannot |
| **Scan for CVEs** | Defender for Containers / Trivy — ⭐ *and act on it* |
| ⭐ **Verify provenance** | Signed images, admission control — the same argument as **AI-1** in [`../../60-ai-and-secure-ai/data-poisoning/`](../../60-ai-and-secure-ai/data-poisoning/) §4 |
| **Minimal base** | distroless/alpine — ⭐ no shell means no shell to escalate in |
| ⭐ **`.dockerignore`** | Stops `.env`, `.git` and credentials being baked in |

⭐ **"Pin by digest, verify provenance, admit only approved images" is exactly the approved-models
control from the AI domain**, arriving in a different product. **Same argument, same shape, and
recognising that is worth more than either instance.**

```bash
# ⭐ Secrets baked into layers - they survive even if a later layer deletes them.
#    Same principle as git: the layer is still there.  (git-and-github §2)
docker history --no-trunc <image> | grep -iE 'password|secret|token|key'
```

⭐ **A `RUN` that used a secret and a later `RUN` that deleted it leaves the secret in the earlier
layer.** ⭐ **This is the git lesson again — an append-only structure does not forget** — and the fix
is the same: **rotate, then use build secrets / multi-stage builds.**

---

## 5. When to choose which boundary

```
Hard tenant separation, hostile neighbours   → ⭐ VM (or a sandboxed runtime)
Your own microservices, one trust domain     → containers are fine
Untrusted CODE (customer builds, AI tools)   → ⭐ VM-level, every time
Regulatory "physical separation"             → separate cluster/subscription, not a namespace
```

⭐ **A namespace is not a compliance boundary.** It is a naming and RBAC convenience with a shared
kernel and, usually, a shared network. **If someone is presenting namespaces as tenant isolation to
an auditor, that is the finding.**

---

## 6. What breaks

**Treating a container as a small VM.** §1 — ⭐ the kernel is shared.

**`--privileged` in production.** §2 — root on the host.

**Mounting the Docker socket.** §2 — ⭐ it looks reasonable and it is root.

**Running as root inside the container.** §2 — `user=` empty.

**Default service account token auto-mounted.** §3 — ⭐ any code execution gets a cluster credential.

**Granting pod-create as a "limited" role.** §3 — it is cluster-admin in effect.

**Images pinned to tags.** §4 — the tag moves.

**Secrets in image layers.** §4 — ⭐ a later `RUN rm` does not remove them.

**No `.dockerignore`.** `.env` and `.git` baked into the image.

**Namespaces presented as tenant isolation.** §5.

**Scanning without acting.** ⭐ A CVE report nobody triages is documentation of a known risk.

---

## 7. Customer discovery questions

1. Any workloads running **privileged**, **hostPID** or **hostNetwork**? *(§2/§3.)*
2. Is the **Docker socket** mounted anywhere?
3. Do containers run as **root**?
4. Is **`automountServiceAccountToken`** disabled by default? *(§3.)*
5. Who can **create pods**, and do they realise that is cluster-admin?
6. Are workloads using **workload identity federation**, or mounted secrets? *(§3.)*
7. Are images pinned by **digest** and **admission-controlled by provenance**? *(§4.)*
8. Has anyone checked **layers for secrets**?
9. Are **namespaces** being presented as tenant isolation? *(§5.)*

---

## 8. Remember it

**Hook — "A container is a process with a restricted view."** ⭐ Shared kernel.

**Analogy — offices versus buildings.** ⭐ **VMs are separate buildings**: separate foundations,
separate utilities, and getting from one to another means going outside and defeating real
structures. ⭐ **Containers are offices on one floor with partition walls** — genuinely useful,
genuinely stop casual wandering, **and they all share the same ceiling void, the same air handling,
and the same fire.** Partitions are the right answer for your own teams. **They are the wrong answer
for a hostile tenant**, and no amount of thicker partition makes a building.

**The one thing:** ⭐ **the default service account token is mounted into every pod, so any code
execution anywhere in the cluster immediately holds a cluster credential.** It is one YAML line to
turn off, it is on by default, and it converts "a container ran something unexpected" into "an
attacker has an API credential for the cluster." ⭐ **Combine it with the fact that pod-create is
effectively cluster-admin, and you have the two findings that turn a container incident into a
cluster incident.**

**Runner-up:** ⭐ **mounting the Docker socket is root on the host** — and it is the most
reasonable-looking line in the file.

> Folded into the interleaved deck in [`RETENTION.md`](../../RETENTION.md).

---

## 9. Self-test

1. State the VM/container difference in one sentence.
2. Name the three mechanisms that make a container a container.
3. Why is a container escape categorically easier than a VM escape?
4. Name four configurations that remove container isolation.
5. ⭐ Why is mounting `/var/run/docker.sock` equivalent to host root?
6. What does an empty `user=` mean?
7. ⭐ What does `automountServiceAccountToken` default to, and why does it matter?
8. Why is "can create pods" effectively cluster-admin?
9. Why do secrets survive in image layers, and which earlier topic is this the same as?
10. When must you use a VM rather than a container?
11. Why is a namespace not a compliance boundary?

<details>
<summary>Answers</summary>

1. ⭐ **A VM is virtualised hardware; a container is a process with a restricted view** — and a
   **shared host kernel**.
2. **Namespaces** (what it can see), **cgroups** (what it can consume), **capabilities/seccomp**
   (which syscalls it may make).
3. ⭐ A container escape is a **kernel bug or a misconfiguration**, and the kernel is shared; a VM
   escape must defeat **hardware-assisted virtualisation**.
4. `--privileged`, mounting the **Docker socket** or host root, `hostPID`/`hostNetwork`/`hostIPC`,
   and **running as root**.
5. ⭐ The socket **is the daemon's API**, the daemon runs as **root**, and it will start a privileged
   container on request.
6. ⭐ **Root inside the container** — which is root outside unless user namespaces are enabled.
7. ⭐ **True by default.** So ⭐ **any code execution in any pod immediately holds a cluster
   credential.**
8. ⭐ Because a pod can be created **privileged, host-mounted and running as root** — the role looks
   narrow and is not.
9. ⭐ Layers are **append-only**; a later `RUN rm` adds a layer rather than removing the earlier one.
   ⭐ **Exactly the git lesson** — [`../git-and-github/`](../git-and-github/) §2 — and the fix is the
   same: **rotate**.
10. ⭐ **Untrusted code** (customer builds, AI-generated code), hostile multi-tenancy, and anywhere a
    hard boundary is required.
11. ⭐ It is a **naming and RBAC convenience** over a **shared kernel** and usually a shared network.

</details>

---

## 10. Evidence this topic needs

- **`lab/`** ⭐ — the §2 `docker inspect` audit and the §3 Kubernetes queries against any cluster,
  including a local kind/minikube. **Runnable now with no Azure subscription.**
- **`break-fix/`** ⭐ — start a container with `-v /var/run/docker.sock:/var/run/docker.sock`, use it
  to launch a privileged container and read a host file, then remove the mount and show the failure.
  **Escaping your own container in two commands is the moment §1 stops being theory.** Then disable
  `automountServiceAccountToken` and show the in-pod credential disappear.
- **`security/`** — privileged/host-namespace inventory; who can create pods; service accounts using
  federation versus stored secrets; image pinning and provenance; layer secret scan.
- **`operations/`** — admission policy enforcing non-root, no privileged, digest-pinned images;
  CVE triage with an owner.
- **`architecture-decisions/`** — ADR: VM-level isolation for untrusted code; namespaces are not a
  tenant boundary; workload identity federation instead of mounted secrets.
- **`customer-use-cases/`** — §7 answered against a real cluster.
