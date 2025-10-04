apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ASSET_NAME}}-config
  labels:
    app: {{ASSET_NAME}}
    asset-id: "{{ASSET_ID}}"
data:
  # Example configuration
  asset.id: "{{ASSET_ID}}"
  asset.name: "{{ASSET_NAME}}"
  github.org: "{{GITHUB_ORG}}"
  github.url: "{{GITHUB_URL}}"
  
  # Environment will be set by Argo CD based on the target branch
  # Available template variables:
  # - ASSET_ID: {{ASSET_ID}}
  # - ASSET_NAME: {{ASSET_NAME}}
  # - GITHUB_ORG: {{GITHUB_ORG}}
  # - GITHUB_URL: {{GITHUB_URL}}
  # - GITHUB_DOMAIN: {{GITHUB_DOMAIN}}
  # - REPO_OWNER: {{REPO_OWNER}}
  # - CONFIG_REPO: {{CONFIG_REPO}}
  # - DEPLOYMENT_REPO: {{DEPLOYMENT_REPO}}
  # - TIMESTAMP: {{TIMESTAMP}}
  # - DESTINATION_CLUSTER_URL: {{DESTINATION_CLUSTER_URL}}
  # - ARGOCD_NAMESPACE: {{ARGOCD_NAMESPACE}}

