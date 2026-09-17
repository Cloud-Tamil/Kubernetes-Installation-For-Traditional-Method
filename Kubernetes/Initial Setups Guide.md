# 🚀 Kubernetes Home Lab — VirtualBox + kubeadm + Calico

A step-by-step guide to building a real, production-like Kubernetes cluster on a Windows host using Oracle VirtualBox. This lab uses **kubeadm + containerd + Calico** — the same toolchain used in real-world administration.

---

## 📐 Architecture Overview

```
Windows Host
     │
     │ Oracle VirtualBox
     │
     ├── Ubuntu VM 1  ──  k8s-master / Control Plane  ──  192.168.56.109
     │
     └── Ubuntu VM 2  ──  k8s-worker                  ──  192.168.56.110
```

```
                 Kubernetes Cluster
                       │
          ┌────────────┴────────────┐
          │                         │
   Control Plane                 Worker Node
   Ubuntu VM 1                   Ubuntu VM 2
   192.168.56.109                192.168.56.110
          │                         │
     kube-apiserver              kubelet
     etcd                        kube-proxy
     scheduler                   containerd
     controller-manager
     kubelet
     kubectl
          │
          └──────── Calico Network ────────┘
```

---

## 🗺️ What You'll Learn

| Category | Topics |
|---|---|
| **Infrastructure** | VirtualBox networking, Ubuntu VM prep, Static IPs, Hostnames, `/etc/hosts` |
| **OS Prep** | Disable swap, Kernel modules, Sysctl networking |
| **Runtime** | containerd installation and configuration |
| **Kubernetes** | kubeadm, kubelet, kubectl, Control plane init, Worker join |
| **Networking** | Calico CNI |
| **Workloads** | Nginx deployment, Services, ConfigMaps, Secrets, Deployments |
| **Operations** | Scaling, Rolling updates, Rollbacks, Ingress, Storage |
| **Security** | RBAC, NetworkPolicies |
| **Autoscaling** | HPA (Horizontal Pod Autoscaler) |
| **Observability** | Troubleshooting, GUI via Cockpit |
| **GitOps / CI-CD** | Argo CD, Jenkins, Docker, Trivy *(planned)* |

---

## 🖥️ VM Requirements

| Role | CPU | RAM | Disk | OS |
|---|---|---|---|---|
| Control Plane | 2 cores | 4 GB | 30+ GB | Ubuntu Server/Desktop 22.04 or 24.04 |
| Worker | 2 cores | 4 GB | 30+ GB | Ubuntu Server/Desktop 22.04 or 24.04 |

---

## 📋 Phases

- [Phase 0 — VirtualBox VM Setup](#phase-0--virtualbox-vm-setup)
- [Phase 1 — VirtualBox Networking](#phase-1--virtualbox-networking)
- [Phase 2 — Find Network Interfaces](#phase-2--find-network-interfaces)
- [Phase 3 — Set Hostnames](#phase-3--set-hostnames)
- [Phase 4 — Configure /etc/hosts](#phase-4--configure-etchosts)
- [Phase 5 — Update Ubuntu](#phase-5--update-ubuntu)
- [Phase 6 — Disable Swap](#phase-6--disable-swap)
- [Phase 7 — Load Kernel Modules](#phase-7--load-kernel-modules)
- [Phase 8 — Kubernetes Networking (sysctl)](#phase-8--kubernetes-networking-sysctl)
- [Phase 9 — Install containerd](#phase-9--install-containerd)
- [Phase 10 — Install Kubernetes Packages](#phase-10--install-kubernetes-packages)
- [Phase 11 — Verify Container Runtime](#phase-11--verify-container-runtime)
- [Phase 12 — Initialize Control Plane](#phase-12--initialize-control-plane)
- [Phase 13 — Configure kubectl](#phase-13--configure-kubectl)
- [Phase 14 — Install Calico CNI](#phase-14--install-calico-cni)
- [Phase 15 — Join Worker Node](#phase-15--join-worker-node)
- [Phase 16 — Verify the Cluster](#phase-16--verify-the-cluster)
- [Phase 17 — Explore Cluster Info](#phase-17--explore-cluster-info)
- [Phase 18 — Check System Pods](#phase-18--check-system-pods)
- [Phase 19 — Kubernetes Architecture](#phase-19--kubernetes-architecture)

---

## Phase 0 — VirtualBox VM Setup

Create **two** Ubuntu VMs in VirtualBox with the following resources each:

| Setting | Control Plane | Worker |
|---|---|---|
| CPU | 2 cores | 2 cores |
| RAM | 4 GB | 4 GB |
| Disk | 30+ GB | 30+ GB |
| OS | Ubuntu 22.04 / 24.04 | Ubuntu 22.04 / 24.04 |

> 💡 This is sufficient for a learning lab.

---

## Phase 1 — VirtualBox Networking

Proper networking is **critical**. Each VM needs **two** network adapters.

Go to: `VirtualBox → VM → Settings → Network`

### Adapter 1 — Internet Access
```
Attached to: NAT
```

### Adapter 2 — Host-only Communication
```
Attached to: Host-only Adapter
Name       : vboxnet0
```

**Resulting topology:**

```
Internet
   │
 Windows Host
   │
 VirtualBox NAT
   │
 ┌─┴───────────────┐
 │                 │
Ubuntu Master   Ubuntu Worker
192.168.56.109  192.168.56.110
       │              │
       └──────────────┘
         Host-only Network
```

---

## Phase 2 — Find Network Interfaces

Run this on **both VMs**:

```bash
ip addr
```

You'll typically see two interfaces, e.g.:
- `enp0s3` — NAT (internet)
- `enp0s8` — Host-only (cluster communication)

Additional helpers:

```bash
ip route
hostname -I
```

**IP assignments for this lab:**

| Node | IP |
|---|---|
| Control Plane | `192.168.56.109` |
| Worker | `192.168.56.110` |

> If your worker has a different IP, substitute it throughout this guide.

---

## Phase 3 — Set Hostnames

### On Control Plane

```bash
sudo hostnamectl set-hostname k8s-master
hostname
# Expected: k8s-master
```

### On Worker

```bash
sudo hostnamectl set-hostname k8s-worker
hostname
# Expected: k8s-worker
```

---

## Phase 4 — Configure /etc/hosts

Run on **both machines**:

```bash
sudo nano /etc/hosts
```

Add these lines:

```
192.168.56.109 k8s-master
192.168.56.110 k8s-worker
```

**Verify connectivity:**

```bash
# From master
ping -c 3 k8s-worker

# From worker
ping -c 3 k8s-master
```

Both should receive replies.

---

## Phase 5 — Update Ubuntu

Run on **both nodes**:

```bash
sudo apt update
sudo apt upgrade -y
sudo reboot
```

Reconnect after reboot.

---

## Phase 6 — Disable Swap

> ⚠️ Kubernetes requires swap to be **disabled**.

Run on **both nodes**:

```bash
sudo swapoff -a
```

**Verify:**

```bash
free -h
# Swap line should show 0B
```

**Make it permanent** — open fstab:

```bash
sudo nano /etc/fstab
```

Comment out the swap entry:

```
# /swap.img none swap sw 0 0
```

Apply and verify:

```bash
sudo swapoff -a
swapon --show
# Should return nothing
```

---

## Phase 7 — Load Kernel Modules

Run on **both nodes**:

```bash
sudo modprobe overlay
sudo modprobe br_netfilter
```

**Make persistent:**

```bash
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
```

**Verify:**

```bash
lsmod | grep overlay
lsmod | grep br_netfilter
```

---

## Phase 8 — Kubernetes Networking (sysctl)

Run on **both nodes**:

```bash
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF
```

Apply:

```bash
sudo sysctl --system
```

**Verify:**

```bash
sysctl net.ipv4.ip_forward
# Expected: net.ipv4.ip_forward = 1

sysctl net.bridge.bridge-nf-call-iptables
# Expected: net.bridge.bridge-nf-call-iptables = 1
```

---

## Phase 9 — Install containerd

Kubernetes needs a container runtime. We use **containerd**.

Run on **both nodes**:

```bash
sudo apt update
sudo apt install -y containerd
```

**Configure:**

```bash
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
```

**Enable SystemdCgroup** — open the config:

```bash
sudo nano /etc/containerd/config.toml
```

Find and change:

```toml
# Before
SystemdCgroup = false

# After
SystemdCgroup = true
```

**Restart and enable:**

```bash
sudo systemctl restart containerd
sudo systemctl enable containerd
sudo systemctl status containerd
# Expected: active (running)
```

---

## Phase 10 — Install Kubernetes Packages

We need three tools:

| Tool | Purpose |
|---|---|
| `kubeadm` | Creates and configures the Kubernetes cluster |
| `kubelet` | Agent running on every node |
| `kubectl` | CLI for managing Kubernetes |
| `docker.io` | docker manage |

Install on **both nodes**.

> 📌 **Important:** Use the [official Kubernetes documentation](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/) for the current stable minor version repository URL and installation steps. Repository URLs change across versions — do not rely on outdated tutorials.

**General steps (check official docs for current commands):**

```bash
# 1. Install dependencies
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

# 2. Add the Kubernetes apt repository (use current version from official docs)
# Example for v1.32:
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | \
  sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
  https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | \
  sudo tee /etc/apt/sources.list.d/kubernetes.list

# 3. Install packages
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl docker.io

# 4. Pin versions to prevent accidental upgrades
sudo apt-mark hold kubelet kubeadm kubectl

# 5. Enable kubelet
sudo systemctl enable --now kubelet

# 6. Start docker
sudo systemctl start docker && sudo systemctl enable docker 
```

> 🔗 Always refer to: https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/

---

## Phase 11 — Verify Container Runtime

On **both nodes**:

```bash
sudo systemctl status containerd
sudo systemctl status kubelet
```

> ℹ️ `kubelet` may not be fully running yet — that's expected until the cluster is initialized.

---

## Phase 12 — Initialize Control Plane

> ⚠️ Run **ONLY on k8s-master**.

```bash
sudo kubeadm init \
  --apiserver-advertise-address=192.168.56.109 \
  --pod-network-cidr=192.168.0.0/16
```

This takes a few minutes. On success you'll see:

```
Your Kubernetes control-plane has initialized successfully!
```

And crucially — a join command like:

```
kubeadm join 192.168.56.109:6443 \
  --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash>
```

> 🚨 **Save this command immediately.** You need it to join the worker node.

If you lose the join command, regenerate it:

```bash
kubeadm token create --print-join-command
```

---

## Phase 13 — Configure kubectl

Still on **k8s-master**:

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

**Test:**

```bash
kubectl get nodes
```

Expected output (before CNI):

```
NAME         STATUS     ROLES           AGE
k8s-master   NotReady   control-plane   ...
```

> `NotReady` is expected — we haven't installed the network plugin yet.

---

## Phase 14 — Install Calico CNI

Kubernetes does not include a Pod network. We use **Calico**.

```
Pod
 │
 │ CNI
 ↓
Calico
 │
 ↓
Node network
```

> 📌 Use the [official Calico documentation](https://docs.tigera.io/calico/latest/getting-started/kubernetes/self-managed-onprem/onpremises) for the version compatible with your Kubernetes version.

**General steps:**

```bash
# Install the Tigera Calico operator
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.0/manifests/tigera-operator.yaml

# Install Calico custom resources
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.0/manifests/custom-resources.yaml
```

> ⚙️ If you used `--pod-network-cidr=192.168.0.0/16`, the default Calico config matches. Otherwise adjust `custom-resources.yaml` to match your CIDR.

**Wait for all pods to become ready:**

```bash
kubectl get pods -A
# Wait until all pods show Running or Completed

kubectl get nodes
```

Expected:

```
NAME         STATUS   ROLES           AGE
k8s-master   Ready    control-plane   ...
```

---

## Phase 15 — Join Worker Node

Move to your **k8s-worker** VM.

Run the join command generated by `kubeadm init`:

```bash
sudo kubeadm join 192.168.56.109:6443 \
    --token YOUR_TOKEN \
    --discovery-token-ca-cert-hash sha256:YOUR_HASH
```

On success:

```
This node has joined the cluster
```

> ⏰ Tokens expire after 24 hours. Regenerate with `kubeadm token create --print-join-command` on the master if needed.

---

## Phase 16 — Verify the Cluster

Back on **k8s-master**:

```bash
kubectl get nodes
```

Expected:

```
NAME         STATUS   ROLES           AGE
k8s-master   Ready    control-plane   ...
k8s-worker   Ready    <none>          ...
```

🎉 **You now have a working Kubernetes cluster!**

---

## Phase 17 — Explore Cluster Info

```bash
kubectl get nodes -o wide
```

This shows:

| Column | Description |
|---|---|
| NAME | Node name |
| STATUS | Ready / NotReady |
| ROLES | control-plane / worker |
| VERSION | Kubernetes version |
| INTERNAL-IP | Node IP address |
| OS-IMAGE | Ubuntu version |
| KERNEL-VERSION | Linux kernel |
| CONTAINER-RUNTIME | containerd version |

> 💼 This command is commonly asked about in Kubernetes interviews.

---

## Phase 18 — Check System Pods

```bash
kubectl get pods -A
```

```bash
kubectl get pods -n kube-system
```

You'll see system components:

| Component | Role |
|---|---|
| `coredns` | DNS resolution inside the cluster |
| `kube-proxy` | Network proxy on each node |
| `calico-*` | Pod networking |
| `kube-apiserver` | API server |
| `kube-scheduler` | Pod scheduling |
| `kube-controller-manager` | Reconciliation loops |
| `etcd` | Cluster state store |

---

## Phase 19 — Kubernetes Architecture

```
                   kubectl
                      │
                      ▼
              kube-apiserver
                      │
       ┌──────────────┼──────────────┐
       │              │              │
      etcd       scheduler     controller-manager
       │
       ▼
 ┌───────────────┐
 │ Control Plane │
 └───────────────┘
         │
         │ Kubernetes API
         ▼
 ┌────────────────────┐
 │     Worker Node    │
 │                    │
 │ kubelet            │
 │ kube-proxy         │
 │ containerd         │
 │                    │
 │ ┌────┐ ┌────┐      │
 │ │Pod │ │Pod │      │
 │ └────┘ └────┘      │
 └────────────────────┘
```

| Component | Location | Role |
|---|---|---|
| `kube-apiserver` | Control Plane | Central API gateway; all components talk through it |
| `etcd` | Control Plane | Key-value store — the cluster's source of truth |
| `kube-scheduler` | Control Plane | Assigns Pods to nodes based on resources |
| `kube-controller-manager` | Control Plane | Runs reconciliation loops (deployments, replicasets, etc.) |
| `kubelet` | Every Node | Ensures containers in Pods are running |
| `kube-proxy` | Every Node | Manages networking rules for Services |
| `containerd` | Every Node | Container runtime that runs the actual containers |

---

## 🔭 What's Next

After completing the base cluster setup, continue with:

- [ ] **Deploy Nginx** — Your first workload
- [ ] **Services** — Expose Pods inside and outside the cluster
- [ ] **ConfigMaps & Secrets** — Manage configuration and sensitive data
- [ ] **Deployments** — Declarative Pod management
- [ ] **Scaling** — Manual and automatic scaling
- [ ] **Rolling Updates & Rollbacks** — Zero-downtime deployments
- [ ] **Ingress** — HTTP routing into the cluster
- [ ] **Storage (PV/PVC)** — Persistent data for stateful apps
- [ ] **RBAC** — Role-based access control
- [ ] **NetworkPolicies** — Pod-level firewall rules
- [ ] **HPA** — Horizontal Pod Autoscaler
- [ ] **Troubleshooting** — Debugging real cluster issues
- [ ] **Cockpit** — GUI management for the cluster nodes
- [ ] **Argo CD** — GitOps continuous delivery
- [ ] **Jenkins** — CI/CD pipelines
- [ ] **Docker** — Building images
- [ ] **Trivy** — Container image vulnerability scanning

---

## 🛠️ Quick Reference — Common Commands

```bash
# Node status
kubectl get nodes
kubectl get nodes -o wide

# All pods across namespaces
kubectl get pods -A

# System pods only
kubectl get pods -n kube-system

# Describe a resource (great for debugging)
kubectl describe node k8s-worker
kubectl describe pod <pod-name> -n <namespace>

# Logs
kubectl logs <pod-name> -n <namespace>

# Regenerate join command (run on master)
kubeadm token create --print-join-command

# Check component status
sudo systemctl status kubelet
sudo systemctl status containerd

# Apply a manifest
kubectl apply -f <file>.yaml

# Delete a resource
kubectl delete -f <file>.yaml
```

---

## 🔗 Official References

| Resource | Link |
|---|---|
| Kubernetes Docs | https://kubernetes.io/docs/ |
| kubeadm Install Guide | https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/ |
| Calico Docs | https://docs.tigera.io/calico/latest/getting-started/kubernetes/ |
| containerd | https://containerd.io/ |

---

## ⚠️ Common Issues & Fixes

| Issue | Cause | Fix |
|---|---|---|
| `kubectl get nodes` shows NotReady | CNI not installed | Install Calico |
| Worker can't join | Token expired | Run `kubeadm token create --print-join-command` on master |
| kubelet not starting | Swap enabled | Run `sudo swapoff -a` and check `/etc/fstab` |
| Pods stuck in Pending | No worker joined, or taints | Check `kubectl describe pod <name>` |
| containerd not running | Config issue | Check `sudo systemctl status containerd` and logs |
| `br_netfilter` errors | Module not loaded | Run `sudo modprobe br_netfilter` |

---

*Built for learning real Kubernetes administration on a local VirtualBox lab.*
