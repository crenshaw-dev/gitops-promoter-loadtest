apiVersion: v1
kind: Secret
metadata:
  name: promoter-github-app-{{TIMESTAMP}}
  namespace: promoter-system
type: Opaque
stringData:
  githubAppPrivateKey: |
{{GITHUB_APP_PRIVATE_KEY_INDENTED}}

