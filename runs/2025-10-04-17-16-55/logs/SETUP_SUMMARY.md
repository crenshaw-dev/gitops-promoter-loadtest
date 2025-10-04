# Setup Summary - 2025-10-04-17-16-55

## Configuration

### Test Parameters
- **Number of Assets:** 5
- **Timestamp:** 2025-10-04-17-16-55

### GitHub Configuration (Asset Repositories)
- **GitHub Organization/User:** crenshaw-dev
- **GitHub URL:** https://github.com
- **Account Type:** user

### Load Test Repository Configuration
- **Repository:** https://github.com/crenshaw-dev/gitops-promoter-loadtest
- **Argo CD will deploy promoter manifests from:** runs/2025-10-04-17-16-55/manifests/promoter

### GitHub App Details
- **App Name:** promoter-test-2025-10-04-14-52-33
- **App ID:** 2063184
- **Installation ID:** 88727956
- **Private Key Path:** /Users/mcrenshaw/Downloads/promoter-test-2025-10-04-14-52-33.2025-10-04.private-key.pem

## Resources Created

### GitHub Repositories (10 total)

- https://github.com/crenshaw-dev/promoter-test-0000-deployment
- https://github.com/crenshaw-dev/promoter-test-0001-deployment
- https://github.com/crenshaw-dev/promoter-test-0002-deployment
- https://github.com/crenshaw-dev/promoter-test-0003-deployment
- https://github.com/crenshaw-dev/promoter-test-0004-deployment

### Kubernetes Resources

#### Promoter Cluster
- 1 ClusterScmProvider (references imperatively-created Secret)
- 5 Namespaces
- 5 GitRepository resources
- 5 PromotionStrategy resources
- 5 ArgoCDCommitStatus resources

**Note:** The GitHub App Secret (`promoter-github-app`) is created imperatively, not managed by GitOps.

#### Argo CD Cluster
- 1 Load Test AppProject (for deploying promoter manifests)
- 1 Load Test Application (deploys from this repo's runs/2025-10-04-17-16-55/manifests/promoter)
- 5 Asset AppProjects
- 5 Asset Repo Credentials Secrets
- 30 Asset Applications (dev/stg/prd x use2/usw2 per asset)

#### Destination Cluster
- 30 Namespaces (dev/stage/prod x east/west per asset)

## Manifest Files

Generated manifests are located in: `runs/2025-10-04-17-16-55/manifests/`

All resources for each cluster are combined into a single file for easy application:

### Promoter Cluster
- `runs/2025-10-04-17-16-55/manifests/promoter/all-resources.yaml` - Contains ClusterScmProvider, Namespaces, GitRepository, PromotionStrategy, and ArgoCDCommitStatus resources
- **Note:** GitHub App Secret (`promoter-github-app`) is created imperatively, not in manifests

### Argo CD Cluster
- `runs/2025-10-04-17-16-55/manifests/argocd/all-resources.yaml` - Contains Load Test AppProject/Application, Asset AppProjects, repository write credential Secrets, and Asset Applications

### Destination Cluster
- `runs/2025-10-04-17-16-55/manifests/destination/all-resources.yaml` - Contains all destination Namespaces

## Next Steps

Apply the manifests to your clusters using the commands below.

**Important:** The kubectl create command will fail if resources already exist. If you see errors, run the teardown script first to clean up existing resources.
