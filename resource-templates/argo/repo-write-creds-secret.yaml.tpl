apiVersion: v1
kind: Secret
metadata:
  name: promoter-test-{{ASSET_ID}}-repo-write-creds
  namespace: {{ARGOCD_NAMESPACE}}
  labels:
    argocd.argoproj.io/secret-type: repository-write
type: Opaque
stringData:
  type: git
  url: {{GITHUB_URL}}/{{GITHUB_ORG}}/promoter-test-{{ASSET_ID}}-deployment
  githubAppID: "{{GITHUB_APP_ID}}"
  githubAppInstallationID: "{{GITHUB_APP_INSTALLATION_ID}}"
  githubAppPrivateKey: |
{{GITHUB_APP_PRIVATE_KEY_INDENTED}}

