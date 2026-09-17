# Kubernetes Home Lab — VirtualBox + kubeadm + Calico

> A step-by-step guide to building a real, production-like Kubernetes cluster on a Windows host using Oracle VirtualBox. This lab uses **kubeadm + containerd + Calico** — the same toolchain used in real-world administration.

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
 Control Plane               Worker Node
 Ubuntu VM 1                 Ubuntu VM 2
 192.168.56.109              192.168.56.110
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

> ⚠️ **Lab vs. Production:** This is a single control plane setup — there is no HA. etcd runs as a single instance. It mirrors production tooling, not production resilience. For HA you'd need 3+ control planes with stacked or external etcd.

---

## 📋 Table of Contents

- [What You'll Learn](#-what-youll-learn)
- [VM Requirements](#-vm-requirements)
- [Phase 0 — VirtualBox VM Setup](#phase-0--virtualbox-vm-setup)
- [Phase 0.5 — User Setup & sudo Privileges](#phase-05--user-setup--sudo-privileges)
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
- [Phase 11 — Pre-flight Check Before Init](#phase-11--pre-flight-check-before-init)
- [Phase 12 — Initialize Control Plane](#phase-12--initialize-control-plane)
- [Phase 13 — Configure kubectl](#phase-13--configure-kubectl)
- [Phase 14 — Install Calico CNI](#phase-14--install-calico-cni)
- [Phase 15 — Join Worker Node](#phase-15--join-worker-node)
- [Phase 16 — Verify the Cluster](#phase-16--verify-the-cluster)
- [Phase 17 — Explore Cluster Info](#phase-17--explore-cluster-info)
- [Phase 18 — Check System Pods](#phase-18--check-system-pods)
- [Phase 19 — Kubernetes Architecture](#phase-19--kubernetes-architecture)
- [What's Next](#-whats-next)
- [Quick Reference — Common Commands](#-quick-reference--common-commands)
- [Official References](#-official-references)
- [Common Issues & Fixes](#-common-issues--fixes)

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

> 💡 This is sufficient for a learning lab.

---

## Phase 0 — VirtualBox VM Setup

Create two Ubuntu VMs in VirtualBox with the following resources each:

| Setting | Control Plane | Worker |
|---|---|---|
| CPU | 2 cores | 2 cores |
| RAM | 4 GB | 4 GB |
| Disk | 30+ GB | 30+ GB |
| OS | Ubuntu 22.04 / 24.04 | Ubuntu 22.04 / 24.04 |

> 💡 This is sufficient for a learning lab.

---

## Phase 0.5 — User Setup & sudo Privileges

> 🔐 Run these steps on **both VMs** right after OS installation, before anything else.

### Step 1 — Switch to root directly

```bash
su - root
```

### Step 2 — Add your user to the sudo group (as root, no sudo needed)

```bash
usermod -aG sudo liunx-2
```

### Step 3 — Verify

```bash
groups liunx-2
# Expected: liunx-2 : liunx-2 sudo
```

### Step 4 — Log out and back in (mandatory)

Group changes only take effect after a fresh login:

```bash
exit        # exit root
exit        # exit liunx-2 session
# Log back in as liunx-2
```

### Step 5 — Test sudo works

```bash
sudo whoami
# Expected: root
```

---

### 1. Check the Current User

```bash
whoami
# Shows your current logged-in username

id
# Shows uid, gid, and all groups the user belongs to
```

### 2. Create a New User (if needed)

If you installed Ubuntu with a root-only setup or want a dedicated lab user:

```bash
sudo adduser k8suser
# Follow the prompts: set password, fill in details (or press Enter to skip)
```

> 💡 Replace `k8suser` with any username you prefer. This guide uses it as an example.

### 3. Add User to the sudo Group

```bash
sudo usermod -aG sudo k8suser

getent group
```

Verify the user is in the sudo group:

```bash
groups k8suser
# Expected output includes: k8suser : k8suser sudo
```

Or check with:

```bash
id k8suser
# Expected: uid=1001(k8suser) gid=1001(k8suser) groups=1001(k8suser),27(sudo)
```

### 4. Switch to the New User

```bash
su - k8suser
```

Test sudo access:

```bash
sudo whoami
# Expected: root
```

### 5. Grant Passwordless sudo (Optional — Lab Only)

For a smoother lab experience, you can allow passwordless sudo. **Do not do this in production.**

```bash
sudo visudo
```

Add this line at the end of the file:

```
k8suser ALL=(ALL) NOPASSWD:ALL
```

Save and exit (`Ctrl+X` → `Y` → `Enter` in nano).

Verify:

```bash
sudo apt update
# Should run without asking for a password
```

### 6. Allow SSH Login for the New User (Optional)

If you SSH into the VMs from your Windows host:

```bash
# On the VM — copy SSH authorized keys from root (if any)
sudo mkdir -p /home/k8suser/.ssh
sudo cp /root/.ssh/authorized_keys /home/k8suser/.ssh/ 2>/dev/null || true
sudo chown -R k8suser:k8suser /home/k8suser/.ssh
sudo chmod 700 /home/k8suser/.ssh
sudo chmod 600 /home/k8suser/.ssh/authorized_keys
```

Or set a password and enable password auth in SSH:

```bash
sudo nano /etc/ssh/sshd_config
# Set: PasswordAuthentication yes

sudo systemctl restart ssh
```

### 7. Add User to Additional Useful Groups

```bash
# Allow reading system logs
sudo usermod -aG adm k8suser

# Allow using docker (if/when installed later for CI-CD phase)
sudo usermod -aG docker k8suser

# Verify all groups
groups k8suser
```

### 8. Quick Reference — User Management Commands

| Task | Command |
|---|---|
| Create a user | `sudo adduser <username>` |
| Delete a user | `sudo deluser --remove-home <username>` |
| Add to sudo group | `sudo usermod -aG sudo <username>` |
| Add to any group | `sudo usermod -aG <group> <username>` |
| List all groups for user | `groups <username>` |
| List all users on system | `cut -d: -f1 /etc/passwd` |
| List all sudoers | `grep -Po '^sudo.+:\K.*$' /etc/group` |
| Switch to user | `su - <username>` |
| Check current user | `whoami` |
| Check user ID & groups | `id` |

> ⚠️ **Security note:** Always use a non-root user with sudo for day-to-day lab work. Running everything as root is a bad habit — even in a home lab.

---

## Phase 1 — VirtualBox Networking

Proper networking is critical. Each VM needs **two network adapters**.

Go to: **VirtualBox → VM → Settings → Network**

**Adapter 1 — Internet Access**
```
Attached to: NAT
```

**Adapter 2 — Host-only Communication**
```
Attached to: Host-only Adapter
Name       : vboxnet0
```

Resulting topology:

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

> ⚠️ **CIDR note:** The host-only network `192.168.56.0/24` will overlap with the default Calico pod CIDR `192.168.0.0/16`. It works, but if you want clean separation, use `--pod-network-cidr=10.244.0.0/16` in Phase 12 instead. This guide uses `10.244.0.0/16` to avoid the overlap.

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

IP assignments for this lab:

| Node | IP |
|---|---|
| Control Plane | `192.168.56.109` |
| Worker | `192.168.56.110` |

> If your worker has a different IP, substitute it throughout this guide.

---

## Phase 3 — Set Hostnames

**On Control Plane:**

```bash
sudo hostnamectl set-hostname k8s-master
hostname
# Expected: k8s-master
```

**On Worker:**

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

Verify connectivity:

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

> ⚠️ Kubernetes requires swap to be disabled.

Run on **both nodes**:

```bash
sudo swapoff -a
```

Verify:

```bash
free -h
# Swap line should show 0B
```

Make it permanent — open fstab:

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

Make persistent:

```bash
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
```

Verify:

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

Verify:

```bash
sysctl net.ipv4.ip_forward
# Expected: net.ipv4.ip_forward = 1

sysctl net.bridge.bridge-nf-call-iptables
# Expected: net.bridge.bridge-nf-call-iptables = 1
```

---

## Phase 9 — Install containerd

Kubernetes needs a container runtime. We use **containerd**.

> 📌 Docker is not required. containerd is the runtime; Docker is only useful later if you want to build images for CI/CD (covered in "What's Next").

Run on **both nodes**:

```bash
sudo apt update
sudo apt install -y containerd
```

Configure:

```bash
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
```

Enable SystemdCgroup — open the config:

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

Restart and enable:

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

Install on **both nodes**.

> 📌 **Important:** Use the [official Kubernetes documentation](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/) for the current stable minor version repository URL and installation steps. Repository URLs change across versions — do not rely on outdated tutorials.

General steps (check official docs for current commands):

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
sudo apt-get install -y kubelet kubeadm kubectl

# 4. Pin versions to prevent accidental upgrades
sudo apt-mark hold kubelet kubeadm kubectl

# 5. Enable kubelet
sudo systemctl enable --now kubelet
```

> 🔗 Always refer to: https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/

> ℹ️ **Note:** kubelet will crash-loop (restart every few seconds) until `kubeadm init` or `kubeadm join` runs. This is expected — don't try to fix it.

---

## Phase 11 — Pre-flight Check Before Init

Before initializing the control plane, confirm everything is in order. Run on **k8s-master only**:

```bash
# Hostname
hostname
# Expected: k8s-master

# Host-only IP
ip addr show enp0s8 | grep 192.168.56.109

# Swap off
free -h
# Swap line should show 0B

# IP forwarding on
sysctl net.ipv4.ip_forward
# Expected: net.ipv4.ip_forward = 1

# bridge-nf-call-iptables on
sysctl net.bridge.bridge-nf-call-iptables
# Expected: 1

# Modules loaded
lsmod | grep -E 'overlay|br_netfilter'

# containerd running
systemctl is-active containerd
# Expected: active

# kubelet enabled (may be restarting — that's fine)
systemctl is-enabled kubelet
# Expected: enabled
```

> If any of these fail, fix them before proceeding. Most `kubeadm init` failures trace back to one of these.

---

## Phase 12 — Initialize Control Plane

> ⚠️ Run **ONLY** on **k8s-master**.

```bash
sudo kubeadm init \
  --apiserver-advertise-address=192.168.56.109 \
  --pod-network-cidr=10.244.0.0/16
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

> ⏰ Tokens expire after 24 hours. For a lab, you can create a non-expiring token with:

```bash
kubeadm token create --ttl 0 --print-join-command
```

---

## Phase 13 — Configure kubectl

Still on **k8s-master**:

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

Test:

```bash
kubectl get nodes
```

Expected output (before CNI):

```
NAME         STATUS     ROLES           AGE
k8s-master   NotReady   control-plane   ...
```

> `NotReady` is expected — we haven't installed the network plugin yet.

> 💡 Worker nodes do not need `kubectl` for this lab. If you want `kubectl` on the worker, copy `/etc/kubernetes/kubelet.conf` and configure a limited kubeconfig — but it's not required to run the cluster.

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

> 📌 Use the [official Calico documentation](https://docs.tigera.io/calico/latest/getting-started/kubernetes/) for the version compatible with your Kubernetes version.

General steps:

```bash
# Install the Tigera Calico operator
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.0/manifests/tigera-operator.yaml

# Download the custom resources manifest so you can edit it if needed
curl -O https://raw.githubusercontent.com/projectcalico/calico/v3.29.0/manifests/custom-resources.yaml

# If your pod CIDR is NOT 192.168.0.0/16, edit the ipPool cidr:
#   spec.calicoNetwork.ipPools[].cidr
# For this guide (10.244.0.0/16):
#   cidr: 10.244.0.0/16
nano custom-resources.yaml

# Apply it
kubectl create -f custom-resources.yaml
```

> ⚙️ If you used `--pod-network-cidr=10.244.0.0/16` (recommended in this guide), you **must** update `custom-resources.yaml` — the default Calico ipPool is `192.168.0.0/16`.

Wait for all pods to become ready:

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

> ⏰ If the token expired, regenerate on the master with `kubeadm token create --print-join-command`.

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
| `NAME` | Node name |
| `STATUS` | Ready / NotReady |
| `ROLES` | control-plane / worker |
| `VERSION` | Kubernetes version |
| `INTERNAL-IP` | Node IP address |
| `OS-IMAGE` | Ubuntu version |
| `KERNEL-VERSION` | Linux kernel |
| `CONTAINER-RUNTIME` | containerd version |

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
| `kube-proxy` | Network proxy on each node (runs as a DaemonSet) |
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
| `kube-proxy` | Every Node | Manages networking rules for Services (DaemonSet) |
| `containerd` | Every Node | Container runtime that runs the actual containers |

---

## 🔭 What's Next

After completing the base cluster setup, continue with:

- [ ] Deploy Nginx — Your first workload
- [ ] Services — Expose Pods inside and outside the cluster
- [ ] ConfigMaps & Secrets — Manage configuration and sensitive data
- [ ] Deployments — Declarative Pod management
- [ ] Scaling — Manual and automatic scaling
- [ ] Rolling Updates & Rollbacks — Zero-downtime deployments
- [ ] Ingress — HTTP routing into the cluster
- [ ] Storage (PV/PVC) — Persistent data for stateful apps
- [ ] RBAC — Role-based access control
- [ ] NetworkPolicies — Pod-level firewall rules
- [ ] HPA — Horizontal Pod Autoscaler
- [ ] Troubleshooting — Debugging real cluster issues
- [ ] Cockpit — GUI management for the cluster nodes
- [ ] Argo CD — GitOps continuous delivery
- [ ] Jenkins — CI/CD pipelines
- [ ] Docker — Building images (only needed here, not for the cluster runtime)
- [ ] Trivy — Container image vulnerability scanning

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

# Non-expiring join token (lab only)
kubeadm token create --ttl 0 --print-join-command

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
| `sudo: command not found` | User not in sudo group | Run `sudo usermod -aG sudo <username>`, then log out and back in |
| Permission denied running `kubectl` | Wrong user or missing kubeconfig | Ensure `$HOME/.kube/config` exists and is owned by your user |
| `kubectl get nodes` shows `NotReady` | CNI not installed | Install Calico |
| Worker can't join | Token expired | Run `kubeadm token create --print-join-command` on master |
| kubelet not starting | Swap enabled | Run `sudo swapoff -a` and check `/etc/fstab` |
| kubelet crash-looping before init | Normal — no cluster config yet | Run `kubeadm init` / `kubeadm join` |
| Pods stuck in `Pending` | No worker joined, or taints | Check `kubectl describe pod <name>` |
| Pods stuck in `ContainerCreating` | CNI not ready or wrong CIDR | Check Calico pods and `custom-resources.yaml` ipPool CIDR |
| containerd not running | Config issue | Check `sudo systemctl status containerd` and logs |
| `br_netfilter` errors | Module not loaded | Run `sudo modprobe br_netfilter` |
| Calico pods CrashLooping | Pod CIDR mismatch | Edit `custom-resources.yaml` ipPool to match `--pod-network-cidr` |

---

> Built for learning real Kubernetes administration on a local VirtualBox lab.
Phase 8 — Kubernetes Networking (sysctl)

Run on both nodes.

First, make sure the required kernel modules are loaded:

sudo modprobe overlay
sudo modprobe br_netfilter

Configure the required Kubernetes networking parameters:

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

Apply the configuration:

sudo sysctl --system

Verify:

sysctl net.ipv4.ip_forward

Expected:

net.ipv4.ip_forward = 1

Verify bridge traffic:

sysctl net.bridge.bridge-nf-call-iptables

Expected:

net.bridge.bridge-nf-call-iptables = 1

You can also verify the modules:

lsmod | grep -E 'overlay|br_netfilter'
Phase 9 — Install containerd

Kubernetes requires a container runtime. In this setup, we use containerd.

Docker is not required as the Kubernetes container runtime. Docker can still be used later to build application images for your CI/CD pipeline.

Run on both nodes:

sudo apt update
sudo apt install -y containerd

Create the containerd configuration directory:

sudo mkdir -p /etc/containerd

Generate the default configuration:

containerd config default | sudo tee /etc/containerd/config.toml

Open the configuration:

sudo nano /etc/containerd/config.toml

Find:

SystemdCgroup = false

Change it to:

SystemdCgroup = true

Save the file.

Restart and enable containerd:

sudo systemctl restart containerd
sudo systemctl enable containerd

Verify:

sudo systemctl status containerd

Expected:

active (running)

You can also verify with:

sudo systemctl is-active containerd

Expected:

active
Phase 10 — Install Kubernetes Packages

Kubernetes requires three main components:

Component	Purpose
kubeadm	Bootstraps and configures the Kubernetes cluster
kubelet	Agent that runs on every Kubernetes node
kubectl	Command-line tool for managing the cluster

Install them on both nodes.

Important: Kubernetes package repositories are version-specific. Do not blindly copy an old repository URL such as v1.32. Select the Kubernetes minor version you want to install and use the corresponding repository from the official Kubernetes documentation.

Install prerequisites:

sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

Create the keyrings directory:

sudo mkdir -p -m 755 /etc/apt/keyrings

For example, if you have decided to use Kubernetes v1.34, configure the corresponding repository:

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key | \
  sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

Then:

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /' | \
sudo tee /etc/apt/sources.list.d/kubernetes.list

Replace v1.34 with the minor version you have selected. Check the official Kubernetes documentation before installation.

Install:

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl

Prevent automatic upgrades:

sudo apt-mark hold kubelet kubeadm kubectl

Enable kubelet:

sudo systemctl enable --now kubelet

Verify:

sudo systemctl is-enabled kubelet

Expected:

enabled

Note: Before kubeadm init or kubeadm join is executed, kubelet may repeatedly restart. This is expected because kubelet is waiting for Kubernetes configuration.

Official installation documentation:

Kubernetes — Installing kubeadm

Phase 11 — Pre-flight Check Before Init

Before initializing the control plane, perform these checks on k8s-master.

1. Verify hostname
hostname

Expected:

k8s-master
2. Verify the control-plane IP

If your VirtualBox interface is enp0s8:

ip addr show enp0s8

Verify that the expected IP is present:

192.168.56.109

If your interface has a different name, use ip addr to identify it.

3. Verify swap is disabled
free -h

The Swap row should show:

0B

You can also verify:

swapon --show

Expected: no output.

4. Verify IP forwarding
sysctl net.ipv4.ip_forward

Expected:

net.ipv4.ip_forward = 1
5. Verify bridge networking
sysctl net.bridge.bridge-nf-call-iptables

Expected:

net.bridge.bridge-nf-call-iptables = 1
6. Verify kernel modules
lsmod | grep -E 'overlay|br_netfilter'

You should see both modules.

7. Verify containerd
systemctl is-active containerd

Expected:

active
8. Verify kubelet
systemctl is-enabled kubelet

Expected:

enabled

If all checks pass, proceed to kubeadm init.

Phase 12 — Initialize Control Plane

⚠️ Run this command ONLY on k8s-master.

For your configuration:

sudo kubeadm init \
  --apiserver-advertise-address=192.168.56.109 \
  --pod-network-cidr=10.244.0.0/16

Here:

192.168.56.109

is the control-plane IP.

And:

10.244.0.0/16

is the Pod CIDR.

Important: The Pod CIDR must match the networking plugin you install later. 10.244.0.0/16 is commonly used with Flannel.

If initialization succeeds, you should see:

Your Kubernetes control-plane has initialized successfully!

You will also receive a worker-node join command similar to:

kubeadm join 192.168.56.109:6443 \
  --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash>

Save this command.

You will execute it on the worker node in the next phase.

If you lose the command, regenerate it on the control-plane node:

sudo kubeadm token create --print-join-command

For a temporary lab, you can create a token with no expiration:

sudo kubeadm token create --ttl 0 --print-join-command

For production environments, avoid creating unnecessarily long-lived bootstrap tokens.

Phase 13 — Configure kubectl

Still on k8s-master, configure kubectl for your current user:

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

Test:

kubectl get nodes

Before installing the CNI plugin, you will typically see:

NAME         STATUS     ROLES           AGE
k8s-master   NotReady   control-plane   ...
Why is the node NotReady?

This is expected at this stage.

You have created the Kubernetes control plane, but you have not installed the Pod network/CNI plugin yet.

The next step is therefore:

Control Plane initialized
        ↓
kubectl configured
        ↓
Worker joins cluster
        ↓
Install CNI
        ↓
Nodes become Ready

Once the CNI is installed, verify again:

kubectl get nodes

Expected:

NAME         STATUS   ROLES           AGE
k8s-master   Ready    control-plane   ...
k8s-worker   Ready    <none>          ...
One important correction to your original guide

Your overall sequence is good:

Phase 8  → Networking/sysctl
Phase 9  → containerd
Phase 10 → kubeadm/kubelet/kubectl
Phase 11 → Pre-flight checks
Phase 12 → kubeadm init
Phase 13 → kubectl configuration

The main thing I would not hard-code in a permanent guide is:

v1.32

because Kubernetes package repositories are tied to minor versions. Instead, explicitly state that the reader must select the desired supported Kubernetes minor version and use its corresponding pkgs.k8s.io repository.

Markdown# Kubernetes Home Lab — VirtualBox + kubeadm + Calico

> A complete, step-by-step guide to building a production-like Kubernetes cluster on a local host using Oracle VirtualBox, `kubeadm`, `containerd`, and Calico CNI.

---

## 📐 Architecture Overview

```text
Host Machine (Windows / Linux / macOS)
     │
     │ Oracle VirtualBox
     │
     ├── Ubuntu VM 1  ──  k8s-master / Control Plane  ──  192.168.56.109
     │
     └── Ubuntu VM 2  ──  k8s-worker                 ──  192.168.56.110
Plaintext               Kubernetes Cluster
                       │
         ┌─────────────┴─────────────┐
         │                           │
   Control Plane                Worker Node
    Ubuntu VM 1                 Ubuntu VM 2
   192.168.56.109              192.168.56.110
         │                           │
   kube-apiserver                 kubelet
   etcd                           kube-proxy
   scheduler                      containerd
   controller-manager
   kubelet
   kubectl
         │
         └───────── Calico Network ─────────┘
⚠️ Lab vs. Production: This lab deploys a single control plane (no High Availability). etcd runs as a single instance. It mirrors production tooling and standard operations, but not fault tolerance. For production HA, deploy 3+ stacked or external control plane nodes.📋 Table of ContentsVM RequirementsPhase 0 — VirtualBox VM CreationPhase 0.5 — User Setup & Sudo PrivilegesPhase 1 — VirtualBox Dual-Adapter NetworkingPhase 2 — Identify Network Interfaces & IPsPhase 3 — Configure HostnamesPhase 4 — Configure Local DNS (/etc/hosts)Phase 5 — System UpdatesPhase 6 — Disable Linux SwapPhase 7 — Load Required Kernel ModulesPhase 8 — Configure Networking Parameters (sysctl)Phase 9 — Install & Configure containerd RuntimePhase 10 — Install Kubernetes Packages (kubeadm, kubelet, kubectl)Phase 11 — Pre-flight ChecksPhase 12 — Initialize Control Plane (Master Node)Phase 13 — Configure Cluster Access (kubectl)Phase 14 — Deploy Calico CNI Network PluginPhase 15 — Join Worker Node to the ClusterPhase 16 — Verify Cluster StatusPhase 17 — Workload Validation🛠️ Quick Reference Commands⚠️ Common Issues & Troubleshooting🖥️ VM RequirementsAllocate these minimum resources to each VM in VirtualBox:SettingControl Plane (k8s-master)Worker (k8s-worker)vCPU2 Cores2 CoresRAM4 GB4 GBDisk30+ GB30+ GBOSUbuntu Server 22.04 or 24.04 LTSUbuntu Server 22.04 or 24.04 LTSPhase 0 — VirtualBox VM CreationDownload the official Ubuntu Server ISO (22.04 LTS or 24.04 LTS).Create two VirtualBox machines:Name: k8s-masterName: k8s-workerUnder System → Processor, assign at least 2 CPUs to each VM.Under System → Motherboard, assign at least 4096 MB RAM to each VM.Phase 0.5 — User Setup & Sudo PrivilegesRun on both VMs after OS installation.Log in as root (or use an existing administrative account) to set up a dedicated lab user:Bash# Create user (replace k8suser with your preference)
sudo adduser k8suser

# Add to the sudo group
sudo usermod -aG sudo k8suser

# Optional: Enable passwordless sudo for smoother lab operations
echo "k8suser ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/k8suser
sudo chmod 0440 /etc/sudoers.d/k8suser

# Switch to the new user
su - k8suser
Phase 1 — VirtualBox Dual-Adapter NetworkingEach virtual machine requires two separate adapters configured in VirtualBox:Adapter 1 — Internet AccessAttached to: NATAdapter 2 — Internal Cluster CommunicationAttached to: Host-only AdapterName: vboxnet0 (or VirtualBox Host-Only Ethernet Adapter on Windows)Promiscuous Mode: Allow AllPlaintextInternet
   │
Host Machine
   │
   ├─ Adapter 1 (NAT) ─────── Internet access for updates/container images
   │
   └─ Adapter 2 (Host-Only) ── Static inter-node communication
         ├── k8s-master: 192.168.56.109
         └── k8s-worker: 192.168.56.110
Phase 2 — Identify Network Interfaces & IPsRun on both VMs:Baship -br addr
Locate your interface names:NAT interface is typically enp0s3 (assigned a DHCP address like 10.0.2.15).Host-only interface is typically enp0s8 (assigned an address on 192.168.56.x).Make sure your node IPs are predictable:Control Plane: 192.168.56.109 (Interface enp0s8)Worker: 192.168.56.110 (Interface enp0s8)(If your environment uses different IP addresses or interface names, adjust accordingly).Phase 3 — Configure HostnamesSet unique hostnames on each machine.On Control Plane:Bashsudo hostnamectl set-hostname k8s-master
exec bash
On Worker:Bashsudo hostnamectl set-hostname k8s-worker
exec bash
Phase 4 — Configure Local DNS (/etc/hosts)Run on both VMs:Bashsudo tee -a /etc/hosts <<EOF # ## && **both --- -c -y 192.168.56.109 192.168.56.110 3 5 6 Disable EOF Linux Master: On Phase Run Swap System Updates VMs**: Verify Worker: ``` ```bash across apt connectivity k8s-master k8s-worker nodes: on ping reboot sudo update upgrade —> ⚠️ Kubernetes requires swap memory to be completely disabled for kubelet stability.

Run on **both VMs**:

```bash
# Disable swap immediately
sudo swapoff -a

# Disable swap permanently across reboots
sudo sed -i '/swap/s/^/#/' /etc/fstab

# Confirm swap is inactive (should return 0B or empty output)
free -h
swapon --show
Phase 7 — Load Required Kernel ModulesRun on both VMs:Bash# Load kernel modules into running kernel
sudo modprobe overlay
sudo modprobe br_netfilter

# Persist modules across reboots
sudo tee /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF

# Verify modules are active
lsmod | grep -E 'overlay|br_netfilter'
Phase 8 — Configure Networking Parameters (sysctl)Run on both VMs:Bash# Apply required sysctl parameters
sudo tee /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

# Load sysctl parameters without rebooting
sudo sysctl --system

# Verification
sysctl net.ipv4.ip_forward
sysctl net.bridge.bridge-nf-call-iptables
Phase 9 — Install & Configure containerd RuntimeRun on both VMs:Bash# 1. Install containerd package
sudo apt update
sudo apt install -y containerd

# 2. Generate default configuration
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null

# 3. Configure systemd cgroup driver (crucial for Kubernetes)
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

# 4. Restart and enable containerd
sudo systemctl restart containerd
sudo systemctl enable containerd

# 5. Verify service status
systemctl is-active containerd
Phase 10 — Install Kubernetes Packages (kubeadm, kubelet, kubectl)Kubernetes package repositories are tied to minor versions. Choose your desired minor version (e.g., v1.30, v1.31, v1.32) and export it below.Run on both VMs:Bash# 1. Define the target Kubernetes minor version
export K8S_VERSION="v1.32"

# 2. Install base dependencies
sudo apt update
sudo apt install -y apt-transport-https ca-certificates curl gpg

# 3. Set up Kubernetes repository signing key
sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/Release.key | \
  sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# 4. Add the repository to APT sources
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/ /" | \
  sudo tee /etc/apt/sources.list.d/kubernetes.list

# 5. Install Kubernetes tooling
sudo apt update
sudo apt install -y kubelet kubeadm kubectl

# 6. Lock packages to prevent unintentional upgrades
sudo apt-mark hold kubelet kubeadm kubectl

# 7. Enable kubelet service
sudo systemctl enable --now kubelet
ℹ️ Note: The kubelet daemon will crash-loop until kubeadm init or kubeadm join has finished configuring it. This is standard behavior.Phase 11 — Pre-flight ChecksRun on k8s-master only to verify prerequisites before bootstrapping:Bash# 1. Hostname verification
[[ "$(hostname)" == "k8s-master" ]] && echo "Hostname: OK" || echo "Hostname: ERROR"

# 2. IP binding verification
ip -4 addr show enp0s8 | grep -q "192.168.56.109" && echo "Host IP: OK" || echo "Host IP: ERROR"

# 3. Swap check
[[ $(swapon --show | wc -l) -eq 0 ]] && echo "Swap Disabled: OK" || echo "Swap: ACTIVE"

# 4. Kernel forwarding
[[ $(sysctl -n net.ipv4.ip_forward) -eq 1 ]] && echo "IP Forwarding: OK" || echo "IP Forwarding: ERROR"

# 5. Runtime check
[[ $(systemctl is-active containerd) == "active" ]] && echo "containerd: OK" || echo "containerd: ERROR"
Phase 12 — Initialize Control Plane (Master Node)⚠️ Execute this command ONLY on k8s-master.Bashsudo kubeadm init \
  --apiserver-advertise-address=192.168.56.109 \
  --pod-network-cidr=10.244.0.0/16
Once the initialization routine completes, save the printed kubeadm join block. It will look like:Bashkubeadm join 192.168.56.109:6443 \
  --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash>
(If the token expires or is lost later, regenerate it at any time on k8s-master using: sudo kubeadm token create --print-join-command).Phase 13 — Configure Cluster Access (kubectl)Run on k8s-master as your regular non-root user (k8suser):Bashmkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Test cluster access
kubectl get nodes
Expected output:PlaintextNAME         STATUS     ROLES           AGE   VERSION
k8s-master   NotReady   control-plane   1m    v1.32.x
Why is the status NotReady?The control plane cannot accept pod scheduling until a Container Network Interface (CNI) plugin is installed to manage Pod-to-Pod routing.Phase 14 — Deploy Calico CNI Network PluginRun on k8s-master:Bash# 1. Install Tigera Calico Operator
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.0/manifests/tigera-operator.yaml

# 2. Download Calico custom resource template
curl -O https://raw.githubusercontent.com/projectcalico/calico/v3.29.0/manifests/custom-resources.yaml

# 3. Match the CIDR pool to our kubeadm init setting (10.244.0.0/16)
sed -i 's|192.168.0.0/16|10.244.0.0/16|g' custom-resources.yaml

# 4. Apply the custom resource
kubectl create -f custom-resources.yaml

# 5. Handle VirtualBox Dual-NIC routing:
# Instruct Calico to bind specifically to the Host-only network (enp0s8) rather than NAT
kubectl set env daemonset/calico-node -n calico-system IP_AUTODETECTION_METHOD=interface=enp0s8
Wait until all pods in the calico-system namespace are in the Running state:Bashkubectl get pods -n calico-system -w
Phase 15 — Join Worker Node to the ClusterSwitch to k8s-worker and execute the join command generated during Phase 12 (with sudo):Bashsudo kubeadm join 192.168.56.109:6443 \
  --token <your-token> \
  --discovery-token-ca-cert-hash sha256:<your-hash>
On success, the console will output:PlaintextThis node has joined the cluster:
* Certificate signing request was sent to apiserver and a response was received.
* The Kubelet was informed of the new secure connection details.

Run 'kubectl get nodes' on the control-plane to see this node join the cluster.
Phase 16 — Verify Cluster StatusReturn to k8s-master and verify both nodes:Bashkubectl get nodes -o wide
Expected output:PlaintextNAME         STATUS   ROLES           AGE     VERSION   INTERNAL-IP      OS-IMAGE             KERNEL-VERSION     CONTAINER-RUNTIME
k8s-master   Ready    control-plane   10m     v1.32.x   192.168.56.109   Ubuntu 22.04.x LTS   x.x.x-generic      containerd://...
k8s-worker   Ready    <none>          2m      v1.32.x   192.168.56.110   Ubuntu 22.04.x LTS   x.x.x-generic      containerd://...
Verify that all control plane and system pods are running cleanly:Bashkubectl get pods -A
Phase 17 — Workload ValidationRun on k8s-master to test cross-node deployment and cluster DNS:Bash# 1. Deploy test Nginx deployment with 2 replicas
kubectl create deployment nginx-test --image=nginx --replicas=2

# 2. Check pod locations (one should run on k8s-worker)
kubectl get pods -o wide

# 3. Expose the deployment as a NodePort service
kubectl expose deployment nginx-test --port=80 --type=NodePort

# 4. Check assigned NodePort
kubectl get svc nginx-test

# 5. Test connectivity from the master node (replace <NODE_PORT> with actual port)
curl http://192.168.56.110:<NODE_PORT>

# 6. Cleanup test resources
kubectl delete service nginx-test
kubectl delete deployment nginx-test
🛠️ Quick Reference CommandsBash# Cluster inspection
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl cluster-info

# Logs & troubleshooting
journalctl -u kubelet -f
journalctl -u containerd -f
kubectl describe node <node-name>
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>

# Bootstrap token management
sudo kubeadm token list
sudo kubeadm token create --print-join-command
sudo kubeadm token create --ttl 0 --print-join-command  # Non-expiring (lab only)
⚠️ Common Issues & TroubleshootingSymptomRoot CauseSolutionkubectl returns The connection to the server was refusedkube-apiserver is down or kubelet is inactiveCheck sudo systemctl status kubelet. Ensure swap is off (sudo swapoff -a).Nodes stuck indefinitely in NotReadyCalico pods are not running or cannot scheduleRun kubectl get pods -n calico-system. Verify tigera-operator logs.Calico pods in CrashLoopBackOffMulti-NIC route confusion or CIDR mismatchEnsure IP_AUTODETECTION_METHOD is set to interface=enp0s8 and custom-resources.yaml CIDR matches --pod-network-cidr.Worker join fails with connection refused or timeoutPort 6443 unreachable or wrong interface boundVerify connectivity with nc -zv 192.168.56.109 6443. Confirm ufw firewall is disabled or permits traffic on both nodes.kubeadm init pre-flight errors on sysctlMissing bridge or forwarding flagsRerun sudo sysctl --system and check /etc/sysctl.d/k8s.conf.
