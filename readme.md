kind create cluster --name atu-playground --config kind-config.yaml

kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# forward port

kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 --decode && echo ""
kubectl port-forward svc/argocd-server 4000:80 -n argocd


# traefik & nginx access through traefik
kubectl port-forward svc/traefik 8080:80 -n traefik
nginx access through traefik: http://nginx.local:8080