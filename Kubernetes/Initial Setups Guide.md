Markdown

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML``   # Kubernetes Home Lab — VirtualBox + kubeadm + Calico  > A complete, step-by-step guide to building a production-like Kubernetes cluster on a local host using Oracle VirtualBox, `kubeadm`, `containerd`, and Calico CNI.  ---  ## 📐 Architecture Overview  ```text  Host Machine (Windows / Linux / macOS)       │       │ Oracle VirtualBox       │       ├── Ubuntu VM 1  ──  k8s-master / Control Plane  ──  192.168.56.109       │       └── Ubuntu VM 2  ──  k8s-worker                 ──  192.168.56.110   ``

Plaintext

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML               `Kubernetes Cluster                         │           ┌─────────────┴─────────────┐           │                           │     Control Plane                Worker Node      Ubuntu VM 1                 Ubuntu VM 2     192.168.56.109              192.168.56.110           │                           │     kube-apiserver                 kubelet     etcd                           kube-proxy     scheduler                      containerd     controller-manager     kubelet     kubectl           │           └───────── Calico Network ─────────┘`

> ⚠️ **Lab vs. Production:** This lab deploys a single control plane (no High Availability). etcd runs as a single instance. It mirrors production tooling and standard operations, but not fault tolerance. For production HA, deploy 3+ stacked or external control plane nodes.

📋 Table of Contents
--------------------

*   [VM Requirements](https://www.google.com/search?q=#-vm-requirements)
    
*   [Phase 0 — VirtualBox VM Creation](https://www.google.com/search?q=#phase-0--virtualbox-vm-creation)
    
*   [Phase 0.5 — User Setup & Sudo Privileges](https://www.google.com/search?q=#phase-05--user-setup--sudo-privileges)
    
*   [Phase 1 — VirtualBox Dual-Adapter Networking](https://www.google.com/search?q=#phase-1--virtualbox-dual-adapter-networking)
    
*   [Phase 2 — Identify Network Interfaces & IPs](https://www.google.com/search?q=#phase-2--identify-network-interfaces--ips)
    
*   [Phase 3 — Configure Hostnames](https://www.google.com/search?q=#phase-3--configure-hostnames)
    
*   [Phase 4 — Configure Local DNS (/etc/hosts)](https://www.google.com/search?q=#phase-4--configure-local-dns-etchosts)
    
*   [Phase 5 — System Updates](https://www.google.com/search?q=#phase-5--system-updates)
    
*   [Phase 6 — Disable Linux Swap](https://www.google.com/search?q=#phase-6--disable-swap)
    
*   [Phase 7 — Load Required Kernel Modules](https://www.google.com/search?q=#phase-7--load-required-kernel-modules)
    
*   [Phase 8 — Configure Networking Parameters (sysctl)](https://www.google.com/search?q=#phase-8--configure-networking-parameters-sysctl)
    
*   [Phase 9 — Install & Configure containerd Runtime](https://www.google.com/search?q=#phase-9--install--configure-containerd-runtime)
    
*   [Phase 10 — Install Kubernetes Packages (kubeadm, kubelet, kubectl)](https://www.google.com/search?q=#phase-10--install-kubernetes-packages-kubeadm-kubelet-kubectl)
    
*   [Phase 11 — Pre-flight Checks](https://www.google.com/search?q=#phase-11--pre-flight-checks)
    
*   [Phase 12 — Initialize Control Plane (Master Node)](https://www.google.com/search?q=#phase-12--initialize-control-plane-master-node)
    
*   [Phase 13 — Configure Cluster Access (kubectl)](https://www.google.com/search?q=#phase-13--configure-cluster-access-kubectl)
    
*   [Phase 14 — Deploy Calico CNI Network Plugin](https://www.google.com/search?q=#phase-14--deploy-calico-cni-network-plugin)
    
*   [Phase 15 — Join Worker Node to the Cluster](https://www.google.com/search?q=#phase-15--join-worker-node-to-the-cluster)
    
*   [Phase 16 — Verify Cluster Status](https://www.google.com/search?q=#phase-16--verify-cluster-status)
    
*   [Phase 17 — Workload Validation](https://www.google.com/search?q=#phase-17--workload-validation)
    
*   [🛠️ Quick Reference Commands](https://www.google.com/search?q=#️-quick-reference-commands)
    
*   [⚠️ Common Issues & Troubleshooting](https://www.google.com/search?q=#️-common-issues--troubleshooting)
    

🖥️ VM Requirements
-------------------

Allocate these minimum resources to each VM in VirtualBox:

SettingControl Plane (k8s-master)Worker (k8s-worker)**vCPU**2 Cores2 Cores**RAM**4 GB4 GB**Disk**30+ GB30+ GB**OS**Ubuntu Server 22.04 or 24.04 LTSUbuntu Server 22.04 or 24.04 LTS

Phase 0 — VirtualBox VM Creation
--------------------------------

1.  Download the official **Ubuntu Server ISO** (22.04 LTS or 24.04 LTS).
    
2.  Create two VirtualBox machines:
    
    *   Name: k8s-master
        
    *   Name: k8s-worker
        
3.  Under **System → Processor**, assign at least **2 CPUs** to each VM.
    
4.  Under **System → Motherboard**, assign at least **4096 MB RAM** to each VM.
    

Phase 0.5 — User Setup & Sudo Privileges
----------------------------------------

> Run on **both VMs** after OS installation.

Log in as root (or use an existing administrative account) to set up a dedicated lab user:

Bash

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   # Create user (replace k8suser with your preference)  sudo adduser k8suser  # Add to the sudo group  sudo usermod -aG sudo k8suser  # Optional: Enable passwordless sudo for smoother lab operations  echo "k8suser ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/k8suser  sudo chmod 0440 /etc/sudoers.d/k8suser  # Switch to the new user  su - k8suser   `

Phase 1 — VirtualBox Dual-Adapter Networking
--------------------------------------------

Each virtual machine requires **two separate adapters** configured in VirtualBox:

1.  **Adapter 1 — Internet Access**
    
    *   Attached to: NAT
        
2.  **Adapter 2 — Internal Cluster Communication**
    
    *   Attached to: Host-only Adapter
        
    *   Name: vboxnet0 (or VirtualBox Host-Only Ethernet Adapter on Windows)
        
    *   Promiscuous Mode: Allow All
        

Plaintext

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   Internet     │  Host Machine     │     ├─ Adapter 1 (NAT) ─────── Internet access for updates/container images     │     └─ Adapter 2 (Host-Only) ── Static inter-node communication           ├── k8s-master: 192.168.56.109           └── k8s-worker: 192.168.56.110   `

Phase 2 — Identify Network Interfaces & IPs
-------------------------------------------

Run on **both VMs**:

Bash

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   ip -br addr   `

Locate your interface names:

*   NAT interface is typically enp0s3 (assigned a DHCP address like 10.0.2.15).
    
*   Host-only interface is typically enp0s8 (assigned an address on 192.168.56.x).
    

Make sure your node IPs are predictable:

*   **Control Plane:** 192.168.56.109 (Interface enp0s8)
    
*   **Worker:** 192.168.56.110 (Interface enp0s8)
    

_(If your environment uses different IP addresses or interface names, adjust accordingly)._

Phase 3 — Configure Hostnames
-----------------------------

Set unique hostnames on each machine.

On **Control Plane**:

Bash

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   sudo hostnamectl set-hostname k8s-master  exec bash   `

On **Worker**:

Bash

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   sudo hostnamectl set-hostname k8s-worker  exec bash   `

Phase 4 — Configure Local DNS (/etc/hosts)
------------------------------------------

Run on **both VMs**:

Bash

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   sudo tee -a /etc/hosts < ⚠️ Kubernetes requires swap memory to be completely disabled for kubelet stability.  Run on **both VMs**:  ```bash  # Disable swap immediately  sudo swapoff -a  # Disable swap permanently across reboots  sudo sed -i '/swap/s/^/#/' /etc/fstab  # Confirm swap is inactive (should return 0B or empty output)  free -h  swapon --show   `

Phase 7 — Load Required Kernel Modules
--------------------------------------

Run on **both VMs**:

Bash

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   # Load kernel modules into running kernel  sudo modprobe overlay  sudo modprobe br_netfilter  # Persist modules across reboots   `

`sudo tee /etc/modules-load.d/k8s.conf <  overlay  br_netfilter  EOF  # Verify modules are active  lsmod | grep -E 'overlay|br_netfilter'  `

Phase 8 — Configure Networking Parameters (sysctl)
--------------------------------------------------

Run on **both VMs**:

Bash

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   # Apply required sysctl parameters   `

`sudo tee /etc/sysctl.d/k8s.conf <  net.bridge.bridge-nf-call-iptables = 1  net.bridge.bridge-nf-call-ip6tables = 1  net.ipv4.ip_forward = 1  EOF  # Load sysctl parameters without rebooting  sudo sysctl --system  # Verification  sysctl net.ipv4.ip_forward  sysctl net.bridge.bridge-nf-call-iptables  `

Phase 9 — Install & Configure containerd Runtime
------------------------------------------------

Run on **both VMs**:

Bash

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   # 1. Install containerd package  sudo apt update  sudo apt install -y containerd  # 2. Generate default configuration  sudo mkdir -p /etc/containerd  containerd config default | sudo tee /etc/containerd/config.toml > /dev/null  # 3. Configure systemd cgroup driver (crucial for Kubernetes)  sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml  # 4. Restart and enable containerd  sudo systemctl restart containerd  sudo systemctl enable containerd  # 5. Verify service status  systemctl is-active containerd   `

Phase 10 — Install Kubernetes Packages (kubeadm, kubelet, kubectl)
------------------------------------------------------------------

Kubernetes package repositories are tied to minor versions. Choose your desired minor version (e.g., v1.30, v1.31, v1.32) and export it below.

Run on **both VMs**:

Bash

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   # 1. Define the target Kubernetes minor version  export K8S_VERSION="v1.32"  # 2. Install base dependencies  sudo apt update  sudo apt install -y apt-transport-https ca-certificates curl gpg  # 3. Set up Kubernetes repository signing key  sudo mkdir -p -m 755 /etc/apt/keyrings  curl -fsSL https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/Release.key | \    sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg  # 4. Add the repository to APT sources  echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/ /" | \    sudo tee /etc/apt/sources.list.d/kubernetes.list  # 5. Install Kubernetes tooling  sudo apt update  sudo apt install -y kubelet kubeadm kubectl  # 6. Lock packages to prevent unintentional upgrades  sudo apt-mark hold kubelet kubeadm kubectl  # 7. Enable kubelet service  sudo systemctl enable --now kubelet   `

> ℹ️ **Note:** The kubelet daemon will crash-loop until kubeadm init or kubeadm join has finished configuring it. This is standard behavior.

Phase 11 — Pre-flight Checks
----------------------------

Run on **k8s-master only** to verify prerequisites before bootstrapping:

Bash

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   # 1. Hostname verification  [[ "$(hostname)" == "k8s-master" ]] && echo "Hostname: OK" || echo "Hostname: ERROR"  # 2. IP binding verification  ip -4 addr show enp0s8 | grep -q "192.168.56.109" && echo "Host IP: OK" || echo "Host IP: ERROR"  # 3. Swap check  [[ $(swapon --show | wc -l) -eq 0 ]] && echo "Swap Disabled: OK" || echo "Swap: ACTIVE"  # 4. Kernel forwarding  [[ $(sysctl -n net.ipv4.ip_forward) -eq 1 ]] && echo "IP Forwarding: OK" || echo "IP Forwarding: ERROR"  # 5. Runtime check  [[ $(systemctl is-active containerd) == "active" ]] && echo "containerd: OK" || echo "containerd: ERROR"   `

Phase 12 — Initialize Control Plane (Master Node)
-------------------------------------------------

> ⚠️ Execute this command **ONLY** on **k8s-master**.

Bash

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   sudo kubeadm init \    --apiserver-advertise-address=192.168.56.109 \    --pod-network-cidr=10.244.0.0/16   `

Once the initialization routine completes, save the printed kubeadm join block. It will look like:

Bash

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   kubeadm join 192.168.56.109:6443 \    --token  \    --discovery-token-ca-cert-hash sha256:   `

_(If the token expires or is lost later, regenerate it at any time on k8s-master using: sudo kubeadm token create --print-join-command)_.

Phase 13 — Configure Cluster Access (kubectl)
---------------------------------------------

Run on **k8s-master** as your regular non-root user (k8suser):

Bash

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   mkdir -p $HOME/.kube  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config  sudo chown $(id -u):$(id -g) $HOME/.kube/config  # Test cluster access  kubectl get nodes   `

Expected output:

Plaintext

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   NAME         STATUS     ROLES           AGE   VERSION  k8s-master   NotReady   control-plane   1m    v1.32.x   `

> **Why is the status NotReady?**
> 
> The control plane cannot accept pod scheduling until a Container Network Interface (CNI) plugin is installed to manage Pod-to-Pod routing.

Phase 14 — Deploy Calico CNI Network Plugin
-------------------------------------------

Run on **k8s-master**:

Bash

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   # 1. Install Tigera Calico Operator  kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.0/manifests/tigera-operator.yaml  # 2. Download Calico custom resource template  curl -O https://raw.githubusercontent.com/projectcalico/calico/v3.29.0/manifests/custom-resources.yaml  # 3. Match the CIDR pool to our kubeadm init setting (10.244.0.0/16)  sed -i 's|192.168.0.0/16|10.244.0.0/16|g' custom-resources.yaml  # 4. Apply the custom resource  kubectl create -f custom-resources.yaml  # 5. Handle VirtualBox Dual-NIC routing:  # Instruct Calico to bind specifically to the Host-only network (enp0s8) rather than NAT  kubectl set env daemonset/calico-node -n calico-system IP_AUTODETECTION_METHOD=interface=enp0s8   `

Wait until all pods in the calico-system namespace are in the Running state:

Bash

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   kubectl get pods -n calico-system -w   `

Phase 15 — Join Worker Node to the Cluster
------------------------------------------

Switch to **k8s-worker** and execute the join command generated during Phase 12 (with sudo):

Bash

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   sudo kubeadm join 192.168.56.109:6443 \    --token  \    --discovery-token-ca-cert-hash sha256:   `

On success, the console will output:

Plaintext

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   This node has joined the cluster:  * Certificate signing request was sent to apiserver and a response was received.  * The Kubelet was informed of the new secure connection details.  Run 'kubectl get nodes' on the control-plane to see this node join the cluster.   `

Phase 16 — Verify Cluster Status
--------------------------------

Return to **k8s-master** and verify both nodes:

Bash

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   kubectl get nodes -o wide   `

Expected output:

Plaintext

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   NAME         STATUS   ROLES           AGE     VERSION   INTERNAL-IP      OS-IMAGE             KERNEL-VERSION     CONTAINER-RUNTIME  k8s-master   Ready    control-plane   10m     v1.32.x   192.168.56.109   Ubuntu 22.04.x LTS   x.x.x-generic      containerd://...  k8s-worker   Ready              2m      v1.32.x   192.168.56.110   Ubuntu 22.04.x LTS   x.x.x-generic      containerd://...   `

Verify that all control plane and system pods are running cleanly:

Bash

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   kubectl get pods -A   `

Phase 17 — Workload Validation
------------------------------

Run on **k8s-master** to test cross-node deployment and cluster DNS:

Bash

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   # 1. Deploy test Nginx deployment with 2 replicas  kubectl create deployment nginx-test --image=nginx --replicas=2  # 2. Check pod locations (one should run on k8s-worker)  kubectl get pods -o wide  # 3. Expose the deployment as a NodePort service  kubectl expose deployment nginx-test --port=80 --type=NodePort  # 4. Check assigned NodePort  kubectl get svc nginx-test  # 5. Test connectivity from the master node (replace  with actual port)  curl http://192.168.56.110:  # 6. Cleanup test resources  kubectl delete service nginx-test  kubectl delete deployment nginx-test   `

🛠️ Quick Reference Commands
----------------------------

Bash

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   # Cluster inspection  kubectl get nodes -o wide  kubectl get pods -A -o wide  kubectl cluster-info  # Logs & troubleshooting  journalctl -u kubelet -f  journalctl -u containerd -f  kubectl describe node   kubectl describe pod -n   kubectl logs -n   # Bootstrap token management  sudo kubeadm token list  sudo kubeadm token create --print-join-command  sudo kubeadm token create --ttl 0 --print-join-command  # Non-expiring (lab only)   `

⚠️ Common Issues & Troubleshooting
----------------------------------

SymptomRoot CauseSolutionkubectl returns The connection to the server was refusedkube-apiserver is down or kubelet is inactiveCheck sudo systemctl status kubelet. Ensure swap is off (sudo swapoff -a).Nodes stuck indefinitely in NotReadyCalico pods are not running or cannot scheduleRun kubectl get pods -n calico-system. Verify tigera-operator logs.Calico pods in CrashLoopBackOffMulti-NIC route confusion or CIDR mismatchEnsure IP\_AUTODETECTION\_METHOD is set to interface=enp0s8 and custom-resources.yaml CIDR matches --pod-network-cidr.Worker join fails with connection refused or timeoutPort 6443 unreachable or wrong interface boundVerify connectivity with nc -zv 192.168.56.109 6443. Confirm ufw firewall is disabled or permits traffic on both nodes.kubeadm init pre-flight errors on sysctlMissing bridge or forwarding flagsRerun sudo sysctl --system and check /etc/sysctl.d/k8s.conf.
