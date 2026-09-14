# ☸️ Kubernetes — End-to-End Commands & Practice Guide

Complete hands-on command reference covering every major Kubernetes concept.
Designed for learning, lab practice, and interview preparation.

---

## 📋 Table of Contents

1. [kubectl Basics](#1-kubectl-basics)
2. [Namespaces](#2-namespaces)
3. [Pods](#3-pods)
4. [Deployments](#4-deployments)
5. [ReplicaSets](#5-replicasets)
6. [Services](#6-services)
7. [ConfigMaps](#7-configmaps)
8. [Secrets](#8-secrets)
9. [Environment Variables](#9-environment-variables)
10. [Resource Requests & Limits](#10-resource-requests--limits)
11. [Probes — Liveness, Readiness, Startup](#11-probes--liveness-readiness-startup)
12. [Rolling Updates & Rollbacks](#12-rolling-updates--rollbacks)
13. [Scaling — Manual & HPA](#13-scaling--manual--hpa)
14. [DaemonSets](#14-daemonsets)
15. [StatefulSets](#15-statefulsets)
16. [Jobs & CronJobs](#16-jobs--cronjobs)
17. [Storage — PV, PVC, StorageClass](#17-storage--pv-pvc-storageclass)
18. [Ingress](#18-ingress)
19. [RBAC](#19-rbac)
20. [NetworkPolicies](#20-networkpolicies)
21. [Taints & Tolerations](#21-taints--tolerations)
22. [Node Affinity & Pod Affinity](#22-node-affinity--pod-affinity)
23. [Init Containers](#23-init-containers)
24. [Sidecar Containers](#24-sidecar-containers)
25. [Labels, Selectors & Annotations](#25-labels-selectors--annotations)
26. [Resource Quotas & LimitRanges](#26-resource-quotas--limitranges)
27. [Troubleshooting](#27-troubleshooting)
28. [etcd Backup & Restore](#28-etcd-backup--restore)
29. [Cluster Upgrade](#29-cluster-upgrade)
30. [Practice Scenarios](#30-practice-scenarios)

---

## 1. kubectl Basics

```bash
# Cluster info
kubectl cluster-info
kubectl version --short
kubectl get componentstatuses          # or: kubectl get cs

# Config / context
kubectl config view
kubectl config get-contexts
kubectl config current-context
kubectl config use-context <context>   # switch context

# API resources
kubectl api-resources
kubectl api-versions
kubectl explain pod
kubectl explain pod.spec
kubectl explain pod.spec.containers

# Help
kubectl --help
kubectl get --help
kubectl run --help
```

### Output formats

```bash
kubectl get pods                        # default table
kubectl get pods -o wide               # extra columns (IP, node)
kubectl get pods -o yaml               # full YAML spec
kubectl get pods -o json               # full JSON
kubectl get pods -o jsonpath='{.items[*].metadata.name}'
kubectl get pods --no-headers
kubectl get pods --watch               # live watch
kubectl get all                        # all common resources
kubectl get all -A                     # all namespaces
```

---

## 2. Namespaces

```bash
# List
kubectl get namespaces
kubectl get ns

# Create
kubectl create namespace dev
kubectl create namespace staging
kubectl create namespace production

# Delete
kubectl delete namespace dev

# Set default namespace for current context
kubectl config set-context --current --namespace=dev

# Run commands in a specific namespace
kubectl get pods -n kube-system
kubectl get pods --all-namespaces
kubectl get pods -A
```

### Namespace YAML

```yaml
# namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: dev
  labels:
    env: development
```

```bash
kubectl apply -f namespace.yaml
```

---

## 3. Pods

### Create pods

```bash
# Imperative (quick/test)
kubectl run nginx --image=nginx
kubectl run nginx --image=nginx --port=80
kubectl run busybox --image=busybox --command -- sleep 3600
kubectl run nginx --image=nginx --dry-run=client -o yaml  # generate YAML only

# In a namespace
kubectl run nginx --image=nginx -n dev
```

### Pod YAML

```yaml
# pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
  namespace: dev
  labels:
    app: nginx
    tier: frontend
spec:
  containers:
    - name: nginx
      image: nginx:1.25
      ports:
        - containerPort: 80
      resources:
        requests:
          memory: "64Mi"
          cpu: "250m"
        limits:
          memory: "128Mi"
          cpu: "500m"
```

```bash
kubectl apply -f pod.yaml
kubectl get pods
kubectl get pods -o wide
kubectl describe pod nginx-pod
kubectl logs nginx-pod
kubectl logs nginx-pod -f              # follow/stream logs
kubectl logs nginx-pod --previous      # crashed container logs
kubectl exec -it nginx-pod -- /bin/bash
kubectl exec -it nginx-pod -- /bin/sh  # if bash not available
kubectl exec nginx-pod -- ls /etc/nginx
kubectl delete pod nginx-pod
kubectl delete pod nginx-pod --force --grace-period=0   # force delete
```

### Multi-container pod

```yaml
# multi-container-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: multi-pod
spec:
  containers:
    - name: main-app
      image: nginx
      ports:
        - containerPort: 80
    - name: logger
      image: busybox
      command: ["sh", "-c", "while true; do echo logging; sleep 5; done"]
```

```bash
kubectl apply -f multi-container-pod.yaml
kubectl logs multi-pod -c main-app     # specify container
kubectl logs multi-pod -c logger
kubectl exec -it multi-pod -c main-app -- /bin/bash
```

---

## 4. Deployments

```bash
# Imperative
kubectl create deployment nginx-deploy --image=nginx
kubectl create deployment nginx-deploy --image=nginx --replicas=3
kubectl create deployment nginx-deploy --image=nginx --replicas=3 --dry-run=client -o yaml
```

### Deployment YAML

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deploy
  namespace: dev
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
        - name: nginx
          image: nginx:1.25
          ports:
            - containerPort: 80
          resources:
            requests:
              memory: "64Mi"
              cpu: "250m"
            limits:
              memory: "128Mi"
              cpu: "500m"
```

```bash
kubectl apply -f deployment.yaml
kubectl get deployments
kubectl get deploy
kubectl get deploy -o wide
kubectl describe deployment nginx-deploy
kubectl get replicasets
kubectl get rs

# Edit live
kubectl edit deployment nginx-deploy

# Set image (trigger update)
kubectl set image deployment/nginx-deploy nginx=nginx:1.26

# Scale
kubectl scale deployment nginx-deploy --replicas=5

# Delete
kubectl delete deployment nginx-deploy
kubectl delete -f deployment.yaml
```

---

## 5. ReplicaSets

> ReplicaSets are usually managed by Deployments. Rarely created standalone.

```yaml
# replicaset.yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: nginx-rs
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
        - name: nginx
          image: nginx:1.25
```

```bash
kubectl apply -f replicaset.yaml
kubectl get replicasets
kubectl get rs
kubectl describe rs nginx-rs
kubectl scale rs nginx-rs --replicas=5
kubectl delete rs nginx-rs
```

---

## 6. Services

### Types

| Type | Use Case |
|---|---|
| `ClusterIP` | Internal cluster access only (default) |
| `NodePort` | Expose on each node's IP + static port |
| `LoadBalancer` | Cloud load balancer (AWS/GCP/Azure) |
| `ExternalName` | Maps to external DNS name |

### ClusterIP

```yaml
# service-clusterip.yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-svc
  namespace: dev
spec:
  selector:
    app: nginx
  ports:
    - protocol: TCP
      port: 80          # Service port
      targetPort: 80    # Pod port
  type: ClusterIP
```

### NodePort

```yaml
# service-nodeport.yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-nodeport
spec:
  selector:
    app: nginx
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
      nodePort: 30080   # 30000-32767 range
  type: NodePort
```

### LoadBalancer

```yaml
# service-lb.yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-lb
spec:
  selector:
    app: nginx
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
  type: LoadBalancer
```

```bash
# Imperative
kubectl expose deployment nginx-deploy --port=80 --type=NodePort
kubectl expose deployment nginx-deploy --port=80 --type=ClusterIP
kubectl expose pod nginx-pod --port=80 --name=nginx-svc

kubectl get services
kubectl get svc
kubectl describe svc nginx-svc
kubectl delete svc nginx-svc

# Access from within cluster (test)
kubectl run curl-test --image=curlimages/curl --rm -it --restart=Never -- curl http://nginx-svc
```

---

## 7. ConfigMaps

```bash
# Imperative — from literals
kubectl create configmap app-config \
  --from-literal=APP_ENV=production \
  --from-literal=APP_PORT=8080

# From file
kubectl create configmap nginx-conf --from-file=nginx.conf

# From env file
kubectl create configmap env-config --from-env-file=app.env

# View
kubectl get configmaps
kubectl get cm
kubectl describe cm app-config
kubectl get cm app-config -o yaml
```

### ConfigMap YAML

```yaml
# configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: dev
data:
  APP_ENV: "production"
  APP_PORT: "8080"
  APP_NAME: "my-app"
  config.properties: |
    server.port=8080
    server.host=0.0.0.0
    log.level=INFO
```

### Use ConfigMap in Pod — as env vars

```yaml
spec:
  containers:
    - name: app
      image: nginx
      envFrom:
        - configMapRef:
            name: app-config
```

### Use ConfigMap — specific keys

```yaml
spec:
  containers:
    - name: app
      image: nginx
      env:
        - name: ENVIRONMENT
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: APP_ENV
```

### Use ConfigMap — as volume

```yaml
spec:
  volumes:
    - name: config-vol
      configMap:
        name: app-config
  containers:
    - name: app
      image: nginx
      volumeMounts:
        - name: config-vol
          mountPath: /etc/config
```

---

## 8. Secrets

> Secrets store sensitive data (passwords, tokens, keys). Stored base64-encoded (not encrypted by default — enable etcd encryption in production).

```bash
# Create
kubectl create secret generic db-secret \
  --from-literal=DB_USER=admin \
  --from-literal=DB_PASSWORD=supersecret

# From file
kubectl create secret generic tls-secret \
  --from-file=tls.crt \
  --from-file=tls.key

# TLS secret
kubectl create secret tls my-tls-secret \
  --cert=tls.crt \
  --key=tls.key

# Docker registry
kubectl create secret docker-registry regcred \
  --docker-server=registry.example.com \
  --docker-username=user \
  --docker-password=password \
  --docker-email=user@example.com

kubectl get secrets
kubectl describe secret db-secret
kubectl get secret db-secret -o yaml

# Decode a secret value
kubectl get secret db-secret -o jsonpath='{.data.DB_PASSWORD}' | base64 -d
```

### Secret YAML

```yaml
# secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-secret
  namespace: dev
type: Opaque
data:
  DB_USER: YWRtaW4=         # echo -n 'admin' | base64
  DB_PASSWORD: c3VwZXJzZWNyZXQ=  # echo -n 'supersecret' | base64
```

```bash
# Encode values for YAML
echo -n 'admin' | base64
echo -n 'supersecret' | base64
```

### Use Secret in Pod — as env vars

```yaml
spec:
  containers:
    - name: app
      image: nginx
      envFrom:
        - secretRef:
            name: db-secret
```

### Use Secret — specific key

```yaml
spec:
  containers:
    - name: app
      image: nginx
      env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: DB_PASSWORD
```

### Use Secret — as volume

```yaml
spec:
  volumes:
    - name: secret-vol
      secret:
        secretName: db-secret
  containers:
    - name: app
      image: nginx
      volumeMounts:
        - name: secret-vol
          mountPath: /etc/secrets
          readOnly: true
```

---

## 9. Environment Variables

```yaml
# All methods in one pod spec
spec:
  containers:
    - name: app
      image: nginx
      env:
        # Direct value
        - name: APP_NAME
          value: "my-app"

        # From ConfigMap
        - name: APP_ENV
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: APP_ENV

        # From Secret
        - name: DB_PASS
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: DB_PASSWORD

        # Downward API — pod info
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
```

---

## 10. Resource Requests & Limits

```yaml
spec:
  containers:
    - name: app
      image: nginx
      resources:
        requests:
          memory: "128Mi"   # guaranteed minimum
          cpu: "250m"       # 250 millicores = 0.25 CPU
        limits:
          memory: "256Mi"   # maximum allowed
          cpu: "500m"       # 0.5 CPU
```

```bash
# Check resource usage (metrics-server required)
kubectl top nodes
kubectl top pods
kubectl top pods -n dev
kubectl top pods --sort-by=memory
kubectl top pods --sort-by=cpu
```

---

## 11. Probes — Liveness, Readiness, Startup

| Probe | Purpose | Failure Action |
|---|---|---|
| `livenessProbe` | Is the container alive? | Restart container |
| `readinessProbe` | Is the container ready for traffic? | Remove from Service endpoints |
| `startupProbe` | Has the app started? | Disables liveness/readiness during startup |

```yaml
spec:
  containers:
    - name: app
      image: nginx
      ports:
        - containerPort: 80

      livenessProbe:
        httpGet:
          path: /healthz
          port: 80
        initialDelaySeconds: 10
        periodSeconds: 10
        failureThreshold: 3
        timeoutSeconds: 5

      readinessProbe:
        httpGet:
          path: /ready
          port: 80
        initialDelaySeconds: 5
        periodSeconds: 5
        failureThreshold: 3

      startupProbe:
        httpGet:
          path: /healthz
          port: 80
        failureThreshold: 30
        periodSeconds: 10
```

### TCP probe (for databases, etc.)

```yaml
livenessProbe:
  tcpSocket:
    port: 3306
  initialDelaySeconds: 15
  periodSeconds: 20
```

### Exec probe

```yaml
livenessProbe:
  exec:
    command:
      - cat
      - /tmp/healthy
  initialDelaySeconds: 5
  periodSeconds: 5
```

---

## 12. Rolling Updates & Rollbacks

```bash
# Check rollout status
kubectl rollout status deployment/nginx-deploy

# View rollout history
kubectl rollout history deployment/nginx-deploy
kubectl rollout history deployment/nginx-deploy --revision=2

# Update image (triggers rolling update)
kubectl set image deployment/nginx-deploy nginx=nginx:1.26
kubectl set image deployment/nginx-deploy nginx=nginx:1.27 --record

# Pause / resume rollout
kubectl rollout pause deployment/nginx-deploy
kubectl rollout resume deployment/nginx-deploy

# Rollback to previous version
kubectl rollout undo deployment/nginx-deploy

# Rollback to specific revision
kubectl rollout undo deployment/nginx-deploy --to-revision=1

# Force restart (re-pull image, cycle pods)
kubectl rollout restart deployment/nginx-deploy
```

### Rolling update strategy in YAML

```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1          # max pods above desired count during update
      maxUnavailable: 0    # max pods that can be unavailable during update
```

### Recreate strategy (downtime — kill all, then start new)

```yaml
spec:
  strategy:
    type: Recreate
```

---

## 13. Scaling — Manual & HPA

### Manual scaling

```bash
kubectl scale deployment nginx-deploy --replicas=5
kubectl scale deployment nginx-deploy --replicas=1
kubectl scale rs nginx-rs --replicas=3
```

### Horizontal Pod Autoscaler (HPA)

> Requires metrics-server.

```bash
# Install metrics-server (for local lab)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# For VirtualBox/local lab — patch to skip TLS verification
kubectl patch deployment metrics-server -n kube-system \
  --type='json' \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
```

```bash
# Create HPA imperatively
kubectl autoscale deployment nginx-deploy \
  --min=2 \
  --max=10 \
  --cpu-percent=50

# View HPA
kubectl get hpa
kubectl describe hpa nginx-deploy
kubectl delete hpa nginx-deploy
```

### HPA YAML

```yaml
# hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: nginx-hpa
  namespace: dev
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: nginx-deploy
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 50
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 70
```

---

## 14. DaemonSets

> Runs exactly one Pod on every node (or selected nodes). Used for log collectors, monitoring agents, network plugins.

```yaml
# daemonset.yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: log-collector
  namespace: kube-system
spec:
  selector:
    matchLabels:
      app: log-collector
  template:
    metadata:
      labels:
        app: log-collector
    spec:
      tolerations:
        - key: node-role.kubernetes.io/control-plane
          operator: Exists
          effect: NoSchedule
      containers:
        - name: log-collector
          image: fluentd:latest
          volumeMounts:
            - name: varlog
              mountPath: /var/log
      volumes:
        - name: varlog
          hostPath:
            path: /var/log
```

```bash
kubectl apply -f daemonset.yaml
kubectl get daemonsets
kubectl get ds
kubectl describe ds log-collector
kubectl delete ds log-collector
```

---

## 15. StatefulSets

> For stateful apps (databases, queues) that need stable network IDs, stable storage, and ordered deployment.

```yaml
# statefulset.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql
spec:
  serviceName: mysql-headless
  replicas: 3
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
        - name: mysql
          image: mysql:8.0
          env:
            - name: MYSQL_ROOT_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: mysql-secret
                  key: ROOT_PASSWORD
          ports:
            - containerPort: 3306
          volumeMounts:
            - name: data
              mountPath: /var/lib/mysql
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 1Gi
---
# Headless Service (required for StatefulSet DNS)
apiVersion: v1
kind: Service
metadata:
  name: mysql-headless
spec:
  clusterIP: None
  selector:
    app: mysql
  ports:
    - port: 3306
```

```bash
kubectl apply -f statefulset.yaml
kubectl get statefulsets
kubectl get sts
kubectl describe sts mysql

# Pods are named: mysql-0, mysql-1, mysql-2
kubectl get pods -l app=mysql

# DNS: mysql-0.mysql-headless.default.svc.cluster.local
kubectl exec -it mysql-0 -- mysql -u root -p

kubectl delete sts mysql
```

---

## 16. Jobs & CronJobs

### Job (runs to completion once)

```yaml
# job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: pi-job
spec:
  completions: 3          # run 3 times total
  parallelism: 2          # run 2 at a time
  backoffLimit: 4         # retry on failure
  template:
    spec:
      restartPolicy: OnFailure   # Never or OnFailure
      containers:
        - name: pi
          image: perl:5.34
          command: ["perl", "-Mbignum=bpi", "-wle", "print bpi(2000)"]
```

```bash
kubectl apply -f job.yaml
kubectl get jobs
kubectl describe job pi-job
kubectl logs job/pi-job
kubectl delete job pi-job
```

### CronJob (runs on schedule)

```yaml
# cronjob.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: backup-job
spec:
  schedule: "0 2 * * *"    # every day at 2am (cron syntax)
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
            - name: backup
              image: busybox
              command:
                - /bin/sh
                - -c
                - "echo Backup started at $(date)"
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1
  concurrencyPolicy: Forbid    # Allow | Forbid | Replace
```

```bash
kubectl apply -f cronjob.yaml
kubectl get cronjobs
kubectl get cj
kubectl describe cj backup-job

# Trigger manually
kubectl create job --from=cronjob/backup-job manual-backup

kubectl delete cj backup-job
```

---

## 17. Storage — PV, PVC, StorageClass

### Persistent Volume (PV) — cluster-wide

```yaml
# pv.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: my-pv
spec:
  capacity:
    storage: 5Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce       # RWO: one node read/write
    # - ReadOnlyMany      # ROX: many nodes read-only
    # - ReadWriteMany     # RWX: many nodes read/write
  persistentVolumeReclaimPolicy: Retain  # Retain | Recycle | Delete
  storageClassName: manual
  hostPath:
    path: /mnt/data       # for local lab only
```

### Persistent Volume Claim (PVC) — namespace-scoped

```yaml
# pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
  namespace: dev
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: manual
```

### Use PVC in Pod

```yaml
spec:
  volumes:
    - name: storage
      persistentVolumeClaim:
        claimName: my-pvc
  containers:
    - name: app
      image: nginx
      volumeMounts:
        - name: storage
          mountPath: /usr/share/nginx/html
```

```bash
kubectl apply -f pv.yaml
kubectl apply -f pvc.yaml
kubectl get pv
kubectl get pvc
kubectl describe pv my-pv
kubectl describe pvc my-pvc
```

### StorageClass (dynamic provisioning)

```yaml
# storageclass.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast
provisioner: rancher.io/local-path   # or docker.io/hostpath, etc.
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
```

### EmptyDir (ephemeral, shared between containers)

```yaml
spec:
  volumes:
    - name: shared-data
      emptyDir: {}
  containers:
    - name: writer
      image: busybox
      command: ["sh", "-c", "echo hello > /data/file.txt && sleep 3600"]
      volumeMounts:
        - name: shared-data
          mountPath: /data
    - name: reader
      image: busybox
      command: ["sh", "-c", "cat /data/file.txt && sleep 3600"]
      volumeMounts:
        - name: shared-data
          mountPath: /data
```

### HostPath (mount host directory)

```yaml
spec:
  volumes:
    - name: host-vol
      hostPath:
        path: /var/log/app
        type: DirectoryOrCreate
  containers:
    - name: app
      image: nginx
      volumeMounts:
        - name: host-vol
          mountPath: /var/log/nginx
```

---

## 18. Ingress

> Routes external HTTP/HTTPS traffic to internal services.

```bash
# Install NGINX Ingress Controller (for bare metal / local lab)
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.1/deploy/static/provider/baremetal/deploy.yaml

kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
```

### Basic Ingress

```yaml
# ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-ingress
  namespace: dev
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
    - host: app.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: nginx-svc
                port:
                  number: 80
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: api-svc
                port:
                  number: 8080
```

### TLS Ingress

```yaml
spec:
  tls:
    - hosts:
        - app.example.com
      secretName: app-tls-secret
  rules:
    - host: app.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: nginx-svc
                port:
                  number: 80
```

```bash
kubectl apply -f ingress.yaml
kubectl get ingress
kubectl describe ingress my-ingress
```

---

## 19. RBAC

### Components

```
ServiceAccount → RoleBinding → Role
                                 ↓
                           (verbs on resources)
```

### Role (namespace-scoped)

```yaml
# role.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: dev
rules:
  - apiGroups: [""]           # "" means core API group
    resources: ["pods", "pods/log"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
```

### ClusterRole (cluster-wide)

```yaml
# clusterrole.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: node-reader
rules:
  - apiGroups: [""]
    resources: ["nodes"]
    verbs: ["get", "list", "watch"]
```

### ServiceAccount

```yaml
# serviceaccount.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-sa
  namespace: dev
```

### RoleBinding

```yaml
# rolebinding.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: pod-reader-binding
  namespace: dev
subjects:
  - kind: ServiceAccount
    name: app-sa
    namespace: dev
  - kind: User
    name: jane
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

### ClusterRoleBinding

```yaml
# clusterrolebinding.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: node-reader-binding
subjects:
  - kind: ServiceAccount
    name: app-sa
    namespace: dev
roleRef:
  kind: ClusterRole
  name: node-reader
  apiGroup: rbac.authorization.k8s.io
```

```bash
# Imperative
kubectl create serviceaccount app-sa -n dev
kubectl create role pod-reader --verb=get,list,watch --resource=pods -n dev
kubectl create rolebinding pod-reader-binding --role=pod-reader --serviceaccount=dev:app-sa -n dev
kubectl create clusterrole node-reader --verb=get,list,watch --resource=nodes
kubectl create clusterrolebinding node-reader-binding --clusterrole=node-reader --serviceaccount=dev:app-sa

# Check permissions
kubectl auth can-i get pods --as=system:serviceaccount:dev:app-sa -n dev
kubectl auth can-i create deployments --as=jane -n dev
kubectl auth can-i '*' '*' --as=system:serviceaccount:kube-system:default
```

---

## 20. NetworkPolicies

> Controls Pod-to-Pod traffic. Requires a CNI that supports NetworkPolicy (Calico does ✅).

### Deny all ingress (default deny)

```yaml
# deny-all.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
  namespace: dev
spec:
  podSelector: {}    # applies to all pods
  policyTypes:
    - Ingress
```

### Allow ingress from specific pods

```yaml
# allow-from-frontend.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-frontend
  namespace: dev
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: frontend
      ports:
        - protocol: TCP
          port: 8080
```

### Allow ingress from specific namespace

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-monitoring
  namespace: dev
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: monitoring
```

### Allow egress to specific port

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns-egress
  namespace: dev
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
```

```bash
kubectl apply -f deny-all.yaml
kubectl get networkpolicies
kubectl get netpol
kubectl describe netpol deny-all-ingress
kubectl delete netpol deny-all-ingress
```

---

## 21. Taints & Tolerations

> Taints repel pods from nodes. Tolerations allow pods to schedule onto tainted nodes.

```bash
# Add taint to node
kubectl taint nodes k8s-worker key=value:NoSchedule
kubectl taint nodes k8s-worker key=value:NoExecute
kubectl taint nodes k8s-worker key=value:PreferNoSchedule

# Remove taint
kubectl taint nodes k8s-worker key=value:NoSchedule-

# View taints
kubectl describe node k8s-worker | grep Taint
```

### Toleration in Pod spec

```yaml
spec:
  tolerations:
    - key: "key"
      operator: "Equal"
      value: "value"
      effect: "NoSchedule"

    # Tolerate any taint with key "dedicated"
    - key: "dedicated"
      operator: "Exists"
      effect: "NoExecute"
      tolerationSeconds: 3600  # evict after 3600s
```

---

## 22. Node Affinity & Pod Affinity

### Node Affinity — schedule pods on specific nodes

```yaml
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:  # hard rule
        nodeSelectorTerms:
          - matchExpressions:
              - key: disktype
                operator: In
                values:
                  - ssd
      preferredDuringSchedulingIgnoredDuringExecution:  # soft rule
        - weight: 1
          preference:
            matchExpressions:
              - key: region
                operator: In
                values:
                  - us-east-1
```

```bash
# Label a node
kubectl label node k8s-worker disktype=ssd
kubectl label node k8s-worker region=us-east-1

# Remove label
kubectl label node k8s-worker disktype-
```

### Pod Anti-Affinity — spread pods across nodes

```yaml
spec:
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchExpressions:
              - key: app
                operator: In
                values:
                  - nginx
          topologyKey: kubernetes.io/hostname  # different nodes
```

### nodeSelector (simple version)

```yaml
spec:
  nodeSelector:
    disktype: ssd
```

---

## 23. Init Containers

> Run to completion before main containers start. Used for setup, waiting for dependencies.

```yaml
# init-container.yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-init
spec:
  initContainers:
    - name: wait-for-db
      image: busybox
      command:
        - sh
        - -c
        - "until nc -z mysql-svc 3306; do echo waiting for db; sleep 2; done"

    - name: init-migrations
      image: my-app:latest
      command: ["python", "manage.py", "migrate"]
      env:
        - name: DB_HOST
          value: mysql-svc

  containers:
    - name: app
      image: my-app:latest
      ports:
        - containerPort: 8000
```

```bash
kubectl apply -f init-container.yaml
kubectl get pods
kubectl describe pod app-with-init  # watch init container progress
kubectl logs app-with-init -c wait-for-db
kubectl logs app-with-init -c init-migrations
```

---

## 24. Sidecar Containers

> Run alongside the main container to add functionality (logging, proxying, syncing).

```yaml
# sidecar.yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-sidecar
spec:
  volumes:
    - name: shared-logs
      emptyDir: {}

  containers:
    - name: main-app
      image: nginx
      volumeMounts:
        - name: shared-logs
          mountPath: /var/log/nginx

    - name: log-shipper          # sidecar
      image: busybox
      command:
        - sh
        - -c
        - "tail -F /logs/access.log"
      volumeMounts:
        - name: shared-logs
          mountPath: /logs
```

---

## 25. Labels, Selectors & Annotations

```bash
# Add labels
kubectl label pod nginx-pod env=production
kubectl label node k8s-worker disktype=ssd

# Remove labels
kubectl label pod nginx-pod env-

# Update label
kubectl label pod nginx-pod env=staging --overwrite

# Select by label
kubectl get pods -l app=nginx
kubectl get pods -l 'env in (production,staging)'
kubectl get pods -l 'env notin (dev)'
kubectl get pods -l app=nginx,tier=frontend

# Annotations (metadata, not for selection)
kubectl annotate pod nginx-pod description="main nginx pod"
kubectl annotate pod nginx-pod owner=team-a
kubectl annotate pod nginx-pod description-   # remove

# List labels
kubectl get pods --show-labels
kubectl get nodes --show-labels
```

---

## 26. Resource Quotas & LimitRanges

### ResourceQuota — limits total resources per namespace

```yaml
# resourcequota.yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: dev-quota
  namespace: dev
spec:
  hard:
    pods: "20"
    requests.cpu: "4"
    requests.memory: 4Gi
    limits.cpu: "8"
    limits.memory: 8Gi
    persistentvolumeclaims: "10"
    services: "10"
    secrets: "20"
    configmaps: "20"
```

### LimitRange — sets default/min/max per pod/container

```yaml
# limitrange.yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: dev-limits
  namespace: dev
spec:
  limits:
    - type: Container
      default:
        cpu: "500m"
        memory: "256Mi"
      defaultRequest:
        cpu: "250m"
        memory: "128Mi"
      max:
        cpu: "2"
        memory: "2Gi"
      min:
        cpu: "50m"
        memory: "32Mi"
```

```bash
kubectl apply -f resourcequota.yaml
kubectl apply -f limitrange.yaml
kubectl get resourcequota -n dev
kubectl describe resourcequota dev-quota -n dev
kubectl get limitrange -n dev
kubectl describe limitrange dev-limits -n dev
```

---

## 27. Troubleshooting

### Pod issues

```bash
# Check pod status
kubectl get pods
kubectl get pods -o wide
kubectl describe pod <pod-name>       # events section is key
kubectl logs <pod-name>
kubectl logs <pod-name> --previous    # crashed container
kubectl logs <pod-name> -c <container>

# Common states
# Pending      → no node available, insufficient resources, PVC not bound
# CrashLoopBackOff → container crashing repeatedly, check logs
# ImagePullBackOff → image not found or no pull secret
# OOMKilled    → out of memory, increase limits
# Terminating  → stuck, may need force delete
# Error        → container exited with non-zero code

# Force delete stuck pod
kubectl delete pod <pod-name> --force --grace-period=0

# Exec into running pod
kubectl exec -it <pod-name> -- /bin/bash

# Run debug container
kubectl debug -it <pod-name> --image=busybox --target=<container>
```

### Node issues

```bash
kubectl get nodes
kubectl describe node k8s-worker
kubectl get events --sort-by=.metadata.creationTimestamp
kubectl get events -n <namespace>

# Check node conditions
kubectl get node k8s-worker -o jsonpath='{.status.conditions[*].type}'
```

### Service / networking issues

```bash
# Check endpoints (pod IPs behind service)
kubectl get endpoints nginx-svc
kubectl describe svc nginx-svc

# DNS test
kubectl run dns-test --image=busybox --rm -it --restart=Never -- nslookup nginx-svc
kubectl run dns-test --image=busybox --rm -it --restart=Never -- nslookup kubernetes.default

# Connectivity test
kubectl run curl-test --image=curlimages/curl --rm -it --restart=Never -- curl http://nginx-svc:80
```

### Deployment issues

```bash
kubectl rollout status deployment/nginx-deploy
kubectl describe deployment nginx-deploy
kubectl get rs                         # check replicasets
kubectl describe rs <rs-name>
```

### etcd / control plane issues

```bash
kubectl get cs                         # componentstatuses
kubectl get pods -n kube-system

# Logs of control plane components (static pods)
kubectl logs -n kube-system kube-apiserver-k8s-master
kubectl logs -n kube-system etcd-k8s-master
kubectl logs -n kube-system kube-controller-manager-k8s-master
kubectl logs -n kube-system kube-scheduler-k8s-master
```

### Useful one-liners

```bash
# Get all resource types in a namespace
kubectl get all -n dev

# Count pods per node
kubectl get pods -o wide --all-namespaces | awk '{print $8}' | sort | uniq -c

# Find pods not running
kubectl get pods -A | grep -v Running | grep -v Completed

# Watch pods in real time
kubectl get pods -w

# Get recent events (sorted)
kubectl get events --sort-by=.lastTimestamp -n dev

# Port-forward for local testing
kubectl port-forward pod/nginx-pod 8080:80
kubectl port-forward deployment/nginx-deploy 8080:80
kubectl port-forward svc/nginx-svc 8080:80

# Copy files to/from pod
kubectl cp nginx-pod:/etc/nginx/nginx.conf ./nginx.conf
kubectl cp ./index.html nginx-pod:/usr/share/nginx/html/index.html
```

---

## 28. etcd Backup & Restore

```bash
# Install etcdctl
sudo apt install -y etcd-client

# Backup etcd
ETCDCTL_API=3 etcdctl snapshot save /opt/etcd-backup.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Verify backup
ETCDCTL_API=3 etcdctl snapshot status /opt/etcd-backup.db --write-out=table

# Restore etcd
ETCDCTL_API=3 etcdctl snapshot restore /opt/etcd-backup.db \
  --data-dir=/var/lib/etcd-restore

# Update etcd static pod manifest to point to restored data dir
sudo nano /etc/kubernetes/manifests/etcd.yaml
# Change: --data-dir=/var/lib/etcd
# To:     --data-dir=/var/lib/etcd-restore
```

---

## 29. Cluster Upgrade

```bash
# Check available versions
sudo apt-cache madison kubeadm

# On CONTROL PLANE first
sudo apt-mark unhold kubeadm
sudo apt install -y kubeadm=1.XX.Y-*
sudo apt-mark hold kubeadm

# Plan upgrade
sudo kubeadm upgrade plan

# Apply upgrade
sudo kubeadm upgrade apply v1.XX.Y

# Drain control plane node
kubectl drain k8s-master --ignore-daemonsets

# Upgrade kubelet + kubectl on master
sudo apt-mark unhold kubelet kubectl
sudo apt install -y kubelet=1.XX.Y-* kubectl=1.XX.Y-*
sudo apt-mark hold kubelet kubectl
sudo systemctl daemon-reload
sudo systemctl restart kubelet

# Uncordon master
kubectl uncordon k8s-master

# On each WORKER NODE
kubectl drain k8s-worker --ignore-daemonsets --delete-emptydir-data

# SSH into worker, then:
sudo apt-mark unhold kubeadm
sudo apt install -y kubeadm=1.XX.Y-*
sudo apt-mark hold kubeadm
sudo kubeadm upgrade node

sudo apt-mark unhold kubelet kubectl
sudo apt install -y kubelet=1.XX.Y-* kubectl=1.XX.Y-*
sudo apt-mark hold kubelet kubectl
sudo systemctl daemon-reload
sudo systemctl restart kubelet

# Back on master
kubectl uncordon k8s-worker

# Verify
kubectl get nodes
```

---

## 30. Practice Scenarios

Work through these end-to-end to solidify your skills.

---

### 🏋️ Scenario 1 — Deploy a web app

**Goal:** Deploy Nginx with 3 replicas, expose it on NodePort 30080, verify from browser.

```bash
kubectl create namespace practice
kubectl create deployment webapp --image=nginx:1.25 --replicas=3 -n practice
kubectl expose deployment webapp --port=80 --type=NodePort --name=webapp-svc -n practice
kubectl get svc -n practice
# Visit: http://192.168.56.110:<NodePort>
kubectl scale deployment webapp --replicas=5 -n practice
kubectl rollout status deployment/webapp -n practice
```

---

### 🏋️ Scenario 2 — ConfigMap + Secret injection

**Goal:** Mount app config and database credentials into a pod.

```bash
kubectl create configmap app-cfg \
  --from-literal=APP_ENV=production \
  --from-literal=APP_PORT=8080 \
  -n practice

kubectl create secret generic db-creds \
  --from-literal=DB_USER=admin \
  --from-literal=DB_PASS=secret123 \
  -n practice
```

```yaml
# scenario2-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: config-demo
  namespace: practice
spec:
  containers:
    - name: app
      image: nginx
      envFrom:
        - configMapRef:
            name: app-cfg
        - secretRef:
            name: db-creds
```

```bash
kubectl apply -f scenario2-pod.yaml
kubectl exec -it config-demo -n practice -- env | grep -E 'APP|DB'
```

---

### 🏋️ Scenario 3 — Rolling update + rollback

**Goal:** Deploy v1, upgrade to v2, verify rollout, rollback to v1.

```bash
kubectl create deployment roll-demo --image=nginx:1.24 --replicas=3 -n practice
kubectl rollout status deployment/roll-demo -n practice

kubectl set image deployment/roll-demo nginx=nginx:1.25 -n practice
kubectl rollout status deployment/roll-demo -n practice
kubectl rollout history deployment/roll-demo -n practice

# Simulate bad image
kubectl set image deployment/roll-demo nginx=nginx:broken-tag -n practice
kubectl get pods -n practice   # see ImagePullBackOff

# Rollback
kubectl rollout undo deployment/roll-demo -n practice
kubectl rollout status deployment/roll-demo -n practice
```

---

### 🏋️ Scenario 4 — Persistent storage

**Goal:** Create PV + PVC, mount to nginx, write a file, verify persistence.

```yaml
# scenario4.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: practice-pv
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  storageClassName: manual
  hostPath:
    path: /tmp/k8s-practice
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: practice-pvc
  namespace: practice
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi
  storageClassName: manual
---
apiVersion: v1
kind: Pod
metadata:
  name: storage-demo
  namespace: practice
spec:
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: practice-pvc
  containers:
    - name: nginx
      image: nginx
      volumeMounts:
        - name: data
          mountPath: /usr/share/nginx/html
```

```bash
kubectl apply -f scenario4.yaml
kubectl get pv,pvc -n practice
kubectl exec -it storage-demo -n practice -- sh -c "echo 'Hello from PV' > /usr/share/nginx/html/index.html"
kubectl exec -it storage-demo -n practice -- cat /usr/share/nginx/html/index.html
```

---

### 🏋️ Scenario 5 — RBAC setup

**Goal:** Create a ServiceAccount that can only read pods in the `practice` namespace.

```bash
kubectl create serviceaccount readonly-sa -n practice
kubectl create role pod-reader \
  --verb=get,list,watch \
  --resource=pods \
  -n practice
kubectl create rolebinding readonly-binding \
  --role=pod-reader \
  --serviceaccount=practice:readonly-sa \
  -n practice

# Test permissions
kubectl auth can-i get pods --as=system:serviceaccount:practice:readonly-sa -n practice     # yes
kubectl auth can-i delete pods --as=system:serviceaccount:practice:readonly-sa -n practice  # no
kubectl auth can-i get pods --as=system:serviceaccount:practice:readonly-sa -n kube-system  # no
```

---

### 🏋️ Scenario 6 — HPA under load

**Goal:** Deploy an app, configure HPA, generate load, watch scaling.

```bash
kubectl create deployment hpa-demo --image=nginx --replicas=1 -n practice
kubectl set resources deployment hpa-demo \
  --requests=cpu=100m,memory=64Mi \
  --limits=cpu=200m,memory=128Mi \
  -n practice

kubectl autoscale deployment hpa-demo \
  --min=1 --max=8 --cpu-percent=30 \
  -n practice

kubectl get hpa -n practice

# Generate load (in separate terminal)
kubectl run load-gen --image=busybox --rm -it --restart=Never -n practice -- \
  sh -c "while true; do wget -q -O- http://hpa-demo; done"

# Watch scaling
kubectl get hpa -n practice -w
kubectl get pods -n practice -w
```

---

### 🏋️ Scenario 7 — NetworkPolicy

**Goal:** Deny all ingress to a namespace, then allow only from a specific pod.

```bash
kubectl create namespace secure
kubectl run backend --image=nginx -n secure --labels=app=backend
kubectl expose pod backend --port=80 -n secure

# Test connectivity (should work before policy)
kubectl run test --image=curlimages/curl --rm -it --restart=Never -- curl http://backend.secure

# Apply deny-all
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: secure
spec:
  podSelector: {}
  policyTypes:
    - Ingress
EOF

# Test (should fail now)
kubectl run test --image=curlimages/curl --rm -it --restart=Never -- curl --max-time 5 http://backend.secure

# Allow from pods with label: role=allowed
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-allowed
  namespace: secure
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              role: allowed
EOF

# Test with label (should succeed)
kubectl run allowed-pod --image=curlimages/curl --rm -it --restart=Never \
  --labels=role=allowed -- curl http://backend.secure
```

---

### 🏋️ Scenario 8 — Init container + sidecar

**Goal:** Use init container to wait for a service, sidecar to tail logs.

```yaml
# scenario8.yaml
apiVersion: v1
kind: Pod
metadata:
  name: full-demo
  namespace: practice
spec:
  initContainers:
    - name: wait-service
      image: busybox
      command: ['sh', '-c', 'until nslookup webapp-svc.practice.svc.cluster.local; do echo waiting; sleep 2; done']

  volumes:
    - name: logs
      emptyDir: {}

  containers:
    - name: main-app
      image: nginx
      volumeMounts:
        - name: logs
          mountPath: /var/log/nginx

    - name: log-sidecar
      image: busybox
      command: ['sh', '-c', 'tail -F /logs/access.log 2>/dev/null || sleep 3600']
      volumeMounts:
        - name: logs
          mountPath: /logs
```

```bash
kubectl apply -f scenario8.yaml
kubectl get pods -n practice
kubectl logs full-demo -c wait-service -n practice
kubectl logs full-demo -c log-sidecar -n practice
```

---

## 🔑 Quick Reference Card

### Most-used verbs

```
get | list | describe | create | apply | delete | edit | patch | scale | exec | logs | rollout
```

### Resource shortcuts

| Short | Full |
|---|---|
| `po` | pods |
| `deploy` | deployments |
| `svc` | services |
| `ns` | namespaces |
| `rs` | replicasets |
| `sts` | statefulsets |
| `ds` | daemonsets |
| `cm` | configmaps |
| `pv` | persistentvolumes |
| `pvc` | persistentvolumeclaims |
| `sc` | storageclasses |
| `hpa` | horizontalpodautoscalers |
| `netpol` | networkpolicies |
| `sa` | serviceaccounts |
| `rb` | rolebindings |
| `cj` | cronjobs |

### Dry-run to generate YAML

```bash
# Generate YAML without creating resource
kubectl create deployment nginx --image=nginx --dry-run=client -o yaml > deploy.yaml
kubectl run nginx --image=nginx --dry-run=client -o yaml > pod.yaml
kubectl create service nodeport nginx --tcp=80:80 --dry-run=client -o yaml > svc.yaml
kubectl create configmap app-cfg --from-literal=key=value --dry-run=client -o yaml > cm.yaml
kubectl create secret generic mysecret --from-literal=pass=secret --dry-run=client -o yaml > secret.yaml
```

### JSONPath examples

```bash
kubectl get pods -o jsonpath='{.items[*].metadata.name}'
kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}'
kubectl get pod nginx-pod -o jsonpath='{.spec.containers[0].image}'
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.phase}{"\n"}{end}'
```

---

*Practice every scenario in your VirtualBox lab. The best way to learn Kubernetes is to break it and fix it.*
