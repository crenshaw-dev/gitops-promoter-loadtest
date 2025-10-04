# {{ASSET_NAME}}

**Asset ID:** {{ASSET_ID}}  
**GitHub Organization:** {{GITHUB_ORG}}  
**Deployment Repository:** {{GITHUB_URL}}/{{REPO_OWNER}}/{{DEPLOYMENT_REPO}}

## Configuration

This repository contains the configuration for the {{ASSET_NAME}} asset.

### Available Template Variables

The following variables are available when templating files in this repository:

- `{{ASSET_ID}}` - Zero-padded asset ID (e.g., "0000")
- `{{ASSET_NAME}}` - Human-readable asset name (e.g., "promoter-test-0000")
- `{{GITHUB_ORG}}` - GitHub organization or username
- `{{GITHUB_URL}}` - Full GitHub URL (e.g., "https://github.com")
- `{{GITHUB_DOMAIN}}` - GitHub domain (e.g., "github.com")
- `{{REPO_OWNER}}` - Repository owner (org or user)
- `{{CONFIG_REPO}}` - Name of this config repository
- `{{DEPLOYMENT_REPO}}` - Name of the deployment repository
- `{{TIMESTAMP}}` - Test run timestamp
- `{{DESTINATION_CLUSTER_URL}}` - Kubernetes destination cluster URL
- `{{ARGOCD_NAMESPACE}}` - Argo CD namespace

### Environments

- dev-use2, dev-usw2
- stg-use2, stg-usw2
- prd-use2, prd-usw2

## Deployment

Changes to this repository trigger the GitOps Promoter workflow to promote changes through environments.

