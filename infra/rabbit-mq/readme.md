# necessary for pods to start

kubectl create secret generic rabbitmq-credentials \
 --namespace=rabbitmq \
 --from-literal=rabbitmq-password="$(openssl rand -hex 16)" \
 --from-literal=rabbitmq-username=admin_user \
 --dry-run=client -o yaml | kubectl apply -f -

kubectl get secret -n rabbitmq rabbitmq-credentials -o jsonpath='{.data.rabbitmq-password}' | base64 -d; echo
