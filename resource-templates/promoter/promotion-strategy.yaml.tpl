apiVersion: promoter.argoproj.io/v1alpha1
kind: PromotionStrategy
metadata:
  name: promoter-test-{{ASSET_ID}}
  namespace: promoter-test-{{ASSET_ID}}
spec:
  activeCommitStatuses:
  # The ArgoCDCommitStatus CR will maintain this commit status based on the application health.
  - key: argocd-health
  environments:
  - branch: environment/dev-use2
    autoMerge: true
  - branch: environment/dev-usw2
    autoMerge: true
  - branch: environment/stg-use2
    autoMerge: true
  - branch: environment/stg-usw2
    autoMerge: true
  - branch: environment/prd-use2
    autoMerge: true
  - branch: environment/prd-usw2
    autoMerge: true
  gitRepositoryRef:
    name: promoter-test-{{ASSET_ID}}

