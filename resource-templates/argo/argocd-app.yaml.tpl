apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: promoter-test-{{ASSET_ID}}-{{ENV}}-{{REGION}}
  namespace: {{ARGOCD_NAMESPACE}}
  labels:
    asset: promoter-test-{{ASSET_ID}}
spec:
  project: promoter-test-{{ASSET_ID}}
  destination:
    server: {{DESTINATION_CLUSTER_URL}}
    namespace: promoter-test-{{ASSET_ID}}-{{ENV}}-{{REGION}}
  sourceHydrator:
    drySource:
      repoURL: {{GITHUB_URL}}/{{GITHUB_ORG}}/promoter-test-{{ASSET_ID}}
      path: .
      targetRevision: HEAD
    hydrateTo:
      targetBranch: environment/{{ENV}}-{{REGION}}-next
    syncSource:
      targetBranch: environment/{{ENV}}-{{REGION}}
      path: .
  syncPolicy:
    automated:
      selfHeal: true

