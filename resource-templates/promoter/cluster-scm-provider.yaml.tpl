apiVersion: promoter.argoproj.io/v1alpha1
kind: ClusterScmProvider
metadata:
  name: promoter-test-{{TIMESTAMP}}
spec:
  secretRef:
    name: promoter-github-app-{{TIMESTAMP}}
  github:
    appID: {{GITHUB_APP_ID}}
    installationID: {{GITHUB_APP_INSTALLATION_ID}}
    domain: {{GITHUB_DOMAIN}}

