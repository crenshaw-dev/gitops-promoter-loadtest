apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: promoter-loadtest
  namespace: {{ARGOCD_NAMESPACE}}
spec:
  description: Load test project for deploying promoter manifests
  sourceRepos:
  - '{{LOADTEST_REPO_URL}}/{{LOADTEST_REPO_ORG}}/{{LOADTEST_REPO_NAME}}'
  destinations:
  - namespace: '*'
    server: '{{PROMOTER_CLUSTER_URL}}'
  namespaceResourceWhitelist:
  - group: '*'
    kind: '*'

