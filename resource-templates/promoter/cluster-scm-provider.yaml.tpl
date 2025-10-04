apiVersion: promoter.argoproj.io/v1alpha1
kind: ClusterScmProvider
metadata:
  name: promoter-test
spec:
  secretRef:
    name: promoter-github-app
  github:
    appID: {{GITHUB_APP_ID}}
    installationID: {{GITHUB_APP_INSTALLATION_ID}}
    domain: {{GITHUB_DOMAIN}}

