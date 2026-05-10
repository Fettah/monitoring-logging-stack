# atu-playground — Self-Hosted Air-Gapped GitOps Stack

This repository contains a fully automated, self-hosted GitOps infrastructure built for a local `kind` cluster. It uses the **App-of-Apps** pattern with ArgoCD to deploy Gitea, Prometheus, Grafana, Loki, Harbor, Traefik, and MinIO.

Once fully deployed, the cluster becomes completely "air-gapped" and self-sustaining by pulling its own configurations directly from the internal Gitea instance!

## Prerequisites
- Docker Desktop (≥ 8 GB RAM allocated)
- `kind`, `kubectl`, `helm`, `kubeseal`, and `git` installed

---

## 1. Create the Cluster
Create the local Kubernetes cluster with port mappings for Traefik (80/443) and Gitea SSH (2222).
```bash
# Delete the existing cluster if you are starting fresh
kind delete cluster --name atu-playground

# Create the new cluster
kind create cluster --name atu-playground --config kind-config.yaml
```

## 2. Install ArgoCD
```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=120s
```

## 3. The "Chicken-and-Egg" Bootstrap
Because this is an air-gapped setup, the final ArgoCD manifests point to the internal Gitea URL (`http://gitea-http.gitea.svc.cluster.local:3000/...`). However, since Gitea isn't running yet on a fresh cluster, you must temporarily bootstrap from your GitHub repository first.

**Step A:** Temporarily point the manifests to GitHub:
```bash
# Run this simple python script to swap the URLs back to GitHub
python3 -c 'import glob; [open(f, "w").write(open(f).read().replace("http://gitea-http.gitea.svc.cluster.local:3000/abdel/monitoring-logging-stack.git", "https://github.com/Fettah/monitoring-logging-stack.git")) for f in glob.glob("apps/*.yaml") + ["parent-app.yaml"]]'
```

**Step B:** Apply the root application:
```bash
kubectl apply -f parent-app.yaml
```
*ArgoCD will now spin up your entire infrastructure (Gitea, Grafana, Harbor, etc.) by pulling from GitHub.*

## 4. Local DNS (/etc/hosts)
Route your local `.local` domains to your `kind` cluster (which listens on localhost via Traefik).
```bash
sudo tee -a /etc/hosts <<'EOF'
# atu-playground kind cluster
127.0.0.1  gitea.local
127.0.0.1  argocd.local
127.0.0.1  grafana.local
127.0.0.1  prometheus.local
127.0.0.1  alertmanager.local
127.0.0.1  harbor.local
127.0.0.1  minio.local
127.0.0.1  minio-api.local
127.0.0.1  traefik.local
EOF
```

## 5. Seal the Air-Gap (Pivot to Gitea)
Once the `gitea` pod is fully running, you can sever the tie to GitHub and move the repo entirely inside the cluster!

1. Open `https://gitea.local` and log in with `gitea_admin` / `Ch@ngeMe123!`.
2. Create an empty repository named `monitoring-logging-stack` under a new user `abdel`.
3. In your terminal, swap the URLs back to the internal Gitea service:
```bash
python3 -c 'import glob; [open(f, "w").write(open(f).read().replace("https://github.com/Fettah/monitoring-logging-stack.git", "http://gitea-http.gitea.svc.cluster.local:3000/abdel/monitoring-logging-stack.git")) for f in glob.glob("apps/*.yaml") + ["parent-app.yaml"]]'
```
4. Push the repository to Gitea (bypassing the local self-signed cert warning):
```bash
git config http.sslVerify false
git add .
git commit -m "chore: pivot back to internal gitea"
git push -u https://gitea.local/abdel/monitoring-logging-stack.git main
```
5. Tell ArgoCD to look at the new internal source:
```bash
kubectl apply -f parent-app.yaml
```
**Mission Accomplished!** Your cluster is now 100% self-hosted and reading from its own internal Git server.

---

## Service URLs & Default Credentials

| Service       | URL                          | Default Credentials         |
|---------------|------------------------------|-----------------------------|
| Gitea         | https://gitea.local          | gitea_admin / Ch@ngeMe123!  |
| Grafana       | https://grafana.local        | admin / Ch@ngeMe123!        |
| Prometheus    | https://prometheus.local     | —                           |
| AlertManager  | https://alertmanager.local   | —                           |
| Harbor        | https://harbor.local         | admin / Ch@ngeMe123!        |
| MinIO Console | https://minio.local          | minioadmin / Ch@ngeMe123!   |
| Traefik       | https://traefik.local        | —                           |

> ⚠️ **Note:** Your browser will show a "Not Secure" warning for these `.local` domains because Cert-Manager generates a self-signed development certificate. Simply click "Advanced -> Proceed" to access them.