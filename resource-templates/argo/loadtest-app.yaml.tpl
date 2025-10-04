apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: promoter-loadtest
  namespace: {{ARGOCD_NAMESPACE}}
spec:
  project: promoter-loadtest
  source:
    repoURL: '{{LOADTEST_REPO_URL}}/{{LOADTEST_REPO_ORG}}/{{LOADTEST_REPO_NAME}}'
    targetRevision: HEAD
    path: runs/{{TIMESTAMP}}/manifests/promoter
  destination:
    server: '{{PROMOTER_CLUSTER_URL}}'
    namespace: default
  syncPolicy:
    syncOptions:
    - CreateNamespace=false

