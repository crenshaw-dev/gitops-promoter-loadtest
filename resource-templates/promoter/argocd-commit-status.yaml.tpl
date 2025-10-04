apiVersion: promoter.argoproj.io/v1alpha1
kind: ArgoCDCommitStatus
metadata:
  name: promoter-test-{{ASSET_ID}}
  namespace: promoter-test-{{ASSET_ID}}
spec:
  promotionStrategyRef:
    name: promoter-test-{{ASSET_ID}}
  applicationSelector:
    matchLabels:
      asset: promoter-test-{{ASSET_ID}}

