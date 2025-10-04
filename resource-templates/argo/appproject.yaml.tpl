apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: promoter-test-{{ASSET_ID}}
  namespace: {{ARGOCD_NAMESPACE}}
  labels:
    asset: promoter-test-{{ASSET_ID}}
  finalizers:
  - resources-finalizer.argocd.argoproj.io
spec:
  description: Load test project for asset {{ASSET_ID}}
  sourceRepos:
  - '{{GITHUB_URL}}/{{GITHUB_ORG}}/promoter-test-{{ASSET_ID}}'
  - '{{GITHUB_URL}}/{{GITHUB_ORG}}/promoter-test-{{ASSET_ID}}-deployment'
  destinations:
  - namespace: 'promoter-test-{{ASSET_ID}}-*'
    server: '{{DESTINATION_CLUSTER_URL}}'
  namespaceResourceWhitelist:
  - group: '*'
    kind: '*'

