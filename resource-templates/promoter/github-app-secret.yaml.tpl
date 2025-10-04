apiVersion: v1
kind: Secret
metadata:
  name: promoter-github-app
  namespace: promoter-system
type: Opaque

# githubAppPrivateKey should be patched after applying using:
# kubectl create secret generic promoter-github-app --from-file=githubAppPrivateKey=path/to/key.pem --dry-run=client -o yaml -n promoter-system | kubectl apply -f -
