# atu-playground — Self-Hosted GitOps on kind

## Prerequisites
- Docker Desktop (≥ 8 GB RAM allocated)
- `kind`, `kubectl`, `helm`, `kubeseal` installed

---

## 1. Create the cluster
> ⚠️ `extraPortMappings` require recreating if the cluster already exists.
```bash
kind delete cluster --name atu-playground  # if exists
kind create cluster --name atu-playground --config kind-config.yaml
```

## 2. Bootstrap ArgoCD
```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=120s

# Get initial admin password
kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath='{.data.password}' | base64 --decode && echo ""

# Access ArgoCD UI
kubectl port-forward svc/argocd-server 4000:80 -n argocd
# → http://localhost:4000
```

## 3. Apply the App-of-Apps root
```bash
kubectl apply -f argocd-initial-app.yaml
```
This triggers ArgoCD to sync all apps in `infra/` via kustomization.

## 4. /etc/hosts — add *.local domain entries
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
127.0.0.1  nginx.local
127.0.0.1  traefik.local
EOF
```

## 5. Trust the self-signed CA (remove browser warnings)
```bash
# Export CA cert after cert-manager creates it
kubectl get secret local-ca-secret -n cert-manager \
  -o jsonpath='{.data.tls\.crt}' | base64 -d > local-ca.crt

# macOS — add to keychain and trust
sudo security add-trusted-cert -d -r trustRoot \
  -k /Library/Keychains/System.keychain local-ca.crt
```

---

## Service URLs (after cluster is up)

| Service       | URL                          | Default Credentials         |
|---------------|------------------------------|-----------------------------|
| ArgoCD        | http://localhost:4000        | admin / (see step 2)        |
| Gitea         | https://gitea.local          | admin / Ch@ngeMe123!        |
| Grafana       | https://grafana.local        | admin / Ch@ngeMe123!        |
| Prometheus    | https://prometheus.local     | —                           |
| AlertManager  | https://alertmanager.local   | —                           |
| Harbor        | https://harbor.local         | admin / Ch@ngeMe123!        |
| MinIO Console | https://minio.local          | minioadmin / Ch@ngeMe123!   |
| Traefik       | http://localhost:4000 (via port-forward) | —              |

> ⚠️ Change all default passwords immediately after first login!

---

## Phase 6 — Migrate ArgoCD from GitHub → Gitea

Once Gitea is running:

```bash
# 1. Create repo in Gitea UI: https://gitea.local/admin/monitoring-logging-stack

# 2. Push this repo to Gitea
git remote add gitea https://gitea.local/admin/monitoring-logging-stack.git
git push gitea main

# 3. Generate Gitea access token (UI: User Settings → Applications)
# 4. Update the repo secret
kubectl apply -f infra/argocd/gitea-repo-secret.yaml  # after filling the token

# 5. Update argocd-initial-app.yaml repoURL to:
#    http://gitea-http.gitea.svc.cluster.local:3000/admin/monitoring-logging-stack.git

# 6. Update all application.yaml files that reference github.com
#    (traefik, nginx, gitea itself, prometheus, loki, harbor)
#    Change: repoURL: https://github.com/Fettah/monitoring-logging-stack.git
#    To:     repoURL: http://gitea-http.gitea.svc.cluster.local:3000/admin/monitoring-logging-stack.git

# 7. Commit + push → ArgoCD now self-manages from Gitea!
```

## Gitea SSH (optional)
```bash
# Clone via SSH (port 2222 mapped to NodePort 30022)
git clone ssh://git@gitea.local:2222/admin/monitoring-logging-stack.git
```

## Seal a secret
```bash
# After sealed-secrets controller is running:
kubeseal --controller-namespace sealed-secrets \
  --format yaml < plain-secret.yaml > sealed-secret.yaml
```