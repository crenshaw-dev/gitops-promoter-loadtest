apiVersion: promoter.argoproj.io/v1alpha1
kind: GitRepository
metadata:
  name: promoter-test-{{ASSET_ID}}
  namespace: promoter-test-{{ASSET_ID}}
  annotations:
    argocd.argoproj.io/sync-wave: "-1"
spec:
  github:
    owner: {{REPO_OWNER}}
    name: promoter-test-{{ASSET_ID}}-deployment
  scmProviderRef:
    name: promoter-test
    kind: ClusterScmProvider
