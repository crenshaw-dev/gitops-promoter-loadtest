# Promoter Load Test

This repository contains scripts and documentation for running load tests on Kubernetes controllers, specifically the GitOps Promoter and Argo CD controllers.

## Overview

The load testing framework allows you to:
- Create a configurable number of "fake assets" with corresponding GitHub repositories
- Generate Kubernetes manifests for Promoter, Argo CD, and destination clusters
- Track and version all test runs with timestamped directories
- Collect metrics and results in a standardized format
- Clean up test resources after completion

## Architecture

The load test creates the following infrastructure per asset:

### GitHub Resources
- **Config Repository** (`promoter-test-NNNN`): Contains configuration files (optional)
- **Deployment Repository** (`promoter-test-NNNN-deployment`): Contains Kubernetes manifests
- **Environment Branches**: 6 branches per deployment repo (dev/stg/prd × use2/usw2)
  - Promotion branches: `environment/{env}-{region}`
  - Hydration branches: `environment/{env}-{region}-next`

### Kubernetes Resources

#### Promoter Cluster
- GitHub App Secret (for SCM authentication)
- ClusterScmProvider (references the GitHub App)
- Namespace per asset (`promoter-test-NNNN`)
- GitRepository per asset (references the deployment repo)
- PromotionStrategy per asset (6 environments: dev/stg/prd × use2/usw2)
- ArgoCDCommitStatus per asset (monitors Argo CD Application health)

#### Argo CD Cluster
- AppProject per asset
- Repo credential Secret per asset (for source hydrator write access)
- 6 Applications per asset (one per environment/region combination)

#### Destination Cluster
- Namespace per environment/region combination (`promoter-test-NNNN-{env}-{region}`)

## Directory Structure

```
promoter-load-test/
├── README.md                    # This file
├── config.sh                    # Configuration file
├── config.local.sh              # Config overrides (gitignored)
├── setup.sh                     # Setup script to create test resources
├── teardown.sh                  # Teardown script to clean up resources
├── test-results-template.md     # Template for recording test results
├── install/                     # Kustomize installation for local testing
│   ├── README.md                # Installation instructions
│   ├── kustomization.yaml       # Main kustomization (installs Argo CD + Promoter)
│   ├── argocd/                  # Argo CD customizations
│   │   ├── argocd-cm-patch.yaml         # ConfigMap patch (deep links, 30s timeout)
│   │   └── argocd-server-patch.yaml     # Server patch (UI extension)
│   └── promoter/                # Promoter customizations
│       └── controller-config-patch.yaml # Controller config (30s requeue)
├── lib/
│   └── common.sh                # Shared logging and utility functions
├── repo-templates/              # Default repository templates (git repos)
│   ├── asset-config/            # Config repository templates (optional)
│   │   └── README.md.tpl
│   └── asset-deployment/        # Deployment repository templates
│       └── configmap.yaml.tpl
├── repo-templates.local/        # Local repository template overrides (gitignored)
│   ├── asset-config/            # Custom config repo templates (optional)
│   │   └── (your custom templates)
│   └── asset-deployment/        # Custom deployment repo templates
│       └── (your custom templates)
├── resource-templates/          # Kubernetes resource templates (not overridable)
│   ├── promoter/                # Promoter cluster resources
│   │   ├── github-app-secret.yaml.tpl
│   │   ├── cluster-scm-provider.yaml.tpl
│   │   ├── promoter-namespace.yaml.tpl
│   │   ├── git-repository.yaml.tpl
│   │   ├── promotion-strategy.yaml.tpl
│   │   └── argocd-commit-status.yaml.tpl
│   ├── argo/                    # Argo CD cluster resources
│   │   ├── appproject.yaml.tpl
│   │   ├── repo-write-creds-secret.yaml.tpl
│   │   └── argocd-app.yaml.tpl
│   └── destination/             # Destination cluster resources
│       └── destination-namespace.yaml.tpl
└── runs/                        # Directory containing all test run data
    └── YYYY-MM-DD_HH-MM-SS/     # Timestamped run directories
        ├── manifests/
        │   ├── promoter/
        │   │   └── all-resources.yaml      # Single file with all promoter resources
        │   ├── argocd/
        │   │   └── all-resources.yaml      # Single file with all Argo CD resources
        │   └── destination/
        │       └── all-resources.yaml      # Single file with all destination resources
        ├── logs/
        │   ├── setup.log            # Setup script output
        │   ├── teardown.log         # Teardown script output (after running teardown)
        │   ├── SETUP_SUMMARY.md     # Setup summary
        │   └── TEARDOWN_SUMMARY.md  # Teardown summary (after running teardown)
        └── README.md                # Test results and documentation
```

## Prerequisites

- **kubectl CLI**: For applying Kubernetes manifests
- **GitHub CLI (gh)**: For creating repositories and GitHub Apps
- **jq**: For JSON parsing
- **git**: For repository operations
- **Kubernetes cluster**: Local (kind, k3d, minikube, Docker Desktop) or remote
- **GitHub Organization**: With appropriate permissions to create repositories and apps

## Quick Start

### For Local Testing (Easiest)

1. **Install Argo CD and GitOps Promoter**:
   ```bash
   kubectl apply -k install/
   ```
   This installs both controllers with optimized settings for local testing (30s reconciliation, no webhooks needed).
   See [`install/README.md`](install/README.md) for details.

2. **Configure**: Create `config.local.sh` from `config.local.sh.example` and set your GitHub org

3. **Setup**: Run `./setup.sh 10` (start with 10 assets)

4. **Create GitHub App**: Follow prompts to create app with required permissions (or configure in `config.local.sh`)

5. **Test**: The script applies manifests automatically. Monitor controllers and document results in `runs/<timestamp>/README.md`

6. **Teardown**: Run `./teardown.sh runs/<timestamp>`

### For Existing Clusters

If you already have Argo CD and GitOps Promoter installed:

1. **Configure**: Create `config.local.sh` with your cluster URLs and GitHub org
2. **Setup**: Run `./setup.sh 10`
3. **Create GitHub App**: Follow prompts
4. **Test**: Monitor and document results
5. **Teardown**: Run `./teardown.sh runs/<timestamp>`

## Configuration

Before running the setup script, configure your environment:

### Option 1: Personal Config (Recommended)

Create a `config.local.sh` file (gitignored) for your personal settings:

```bash
# Copy the example file
cp config.local.sh.example config.local.sh

# Edit with your settings
vim config.local.sh
```

Example `config.local.sh`:

```bash
#!/usr/bin/env bash

# GitHub Configuration (for test asset repositories)
# Only override if you want to use a different org/domain
# export GITHUB_ORG="my-org"
# export GITHUB_DOMAIN="github.enterprise.com"

# Load Test Tool Repository (THIS repository)
# Only override if you forked the repo or are testing changes
# export LOADTEST_REPO_ORG="my-fork-org"
# export LOADTEST_REPO_NAME="my-fork-name"

# GitHub App Configuration (optional - avoids prompts)
export GITHUB_APP_NAME="promoter-test-2025-10-04-10-23-23"
export GITHUB_APP_ID="12345"
export GITHUB_APP_KEY_PATH="/path/to/private-key.pem"

# Cluster URLs (optional)
export PROMOTER_CLUSTER_URL="https://my-promoter-cluster"
export ARGO_CLUSTER_URL="https://my-argo-cluster"
export DESTINATION_CLUSTER_URL="https://my-destination-cluster"

# Repository Configuration (optional)
export CREATE_CONFIG_REPO=false  # Set to false to skip config repos (deployment only)
```

### Option 2: Edit config.sh Directly

Edit `config.sh` to configure the default environment:

```bash
# GitHub Configuration (for test asset repositories)
# Defaults to canonical public repository settings (crenshaw-dev/github.com)
export GITHUB_ORG="${GITHUB_ORG:-crenshaw-dev}"
export GITHUB_DOMAIN="${GITHUB_DOMAIN:-github.com}"
# GITHUB_URL is automatically inferred as https://${GITHUB_DOMAIN}

# Load Test Tool Repository Configuration (THIS repository)
# Defaults point to the public GitHub repository
export LOADTEST_REPO_DOMAIN="${LOADTEST_REPO_DOMAIN:-github.com}"
export LOADTEST_REPO_ORG="${LOADTEST_REPO_ORG:-crenshaw-dev}"
export LOADTEST_REPO_NAME="${LOADTEST_REPO_NAME:-gitops-promoter-loadtest}"
# LOADTEST_REPO_URL is automatically inferred as https://${LOADTEST_REPO_DOMAIN}

# Cluster Configuration
export PROMOTER_CLUSTER_URL="https://kubernetes.default.svc"
export ARGO_CLUSTER_URL="https://kubernetes.default.svc"
export DESTINATION_CLUSTER_URL="https://kubernetes.default.svc"

# Namespace Configuration
export ARGOCD_NAMESPACE="argocd"

# Test Regions and Environments
export REGIONS=("use2" "usw2")
export ENVIRONMENTS=("dev" "stg" "prd")

# Repository Templates
export CREATE_CONFIG_REPO="${CREATE_CONFIG_REPO:-true}"
```

**Note**: `config.local.sh` takes precedence over `config.sh` and is gitignored, making it perfect for personal settings and sensitive data like GitHub App credentials.

## Usage

### Running a Load Test

#### 1. Setup

Run the setup script with the desired number of fake assets:

```bash
./setup.sh <number_of_assets>
```

Example:
```bash
./setup.sh 100
```

The setup script will:

1. **Validate prerequisites** (check for required tools)
2. **Create GitHub App** (you'll need to create this manually when prompted)
3. **Create GitHub repositories** (config and deployment repos for each asset by default)
4. **Initialize repositories** from templates (custom or default)
5. **Generate Kubernetes manifests** for all three clusters
6. **Apply manifests** to your clusters automatically
7. **Create summary files** with detailed information about what was created
8. **Prompt you to commit** the generated files to git

**Important**: During setup, you'll be prompted to:
- Create a GitHub App with specific permissions
- Download the GitHub App private key
- Install the GitHub App to the deployment repositories

#### 2. Manifests Applied Automatically

The setup script automatically applies manifests to your clusters using `kubectl create`:
- Promoter cluster resources
- Argo CD cluster resources  
- Destination cluster resources

**Important Notes:**
- The script uses `kubectl create` (not `apply`) - this will fail if resources already exist
- This ensures clean state for each test run
- If resources exist, you'll be prompted to run teardown first: `./teardown.sh runs/<timestamp>`

#### Manifest Structure

All resources for each cluster are consolidated into a single file:

- `promoter/all-resources.yaml` - GitHub App Secret, ClusterScmProvider, Namespaces, GitRepository, PromotionStrategy, ArgoCDCommitStatus
- `argocd/all-resources.yaml` - AppProjects, repository write credentials, Applications  
- `destination/all-resources.yaml` - All destination Namespaces

This design:
- Simplifies application (3 commands instead of 11+)
- Uses `kubectl create` to prevent accidental updates
- Fails fast if resources already exist
- Ensures clean baseline for load testing

#### 3. Run Your Test

Execute your load test procedures and monitor the controllers. Document everything in the `runs/<timestamp>/README.md` file, including:
- Test parameters
- Observations
- Metrics collected
- Issues encountered
- Performance characteristics

#### 4. Commit Results

After completing the test and filling out the results file:

```bash
git add runs/<timestamp>/README.md
git commit -m "Add results for load test run <timestamp>"
```

#### 5. Teardown

Clean up the test resources:

```bash
./teardown.sh <timestamp>
```

Or if run from within the run directory:

```bash
cd runs/<timestamp>
../../teardown.sh
```

The teardown script will:
- Delete Kubernetes resources from all three clusters
- Optionally delete GitHub repositories
- Create a teardown summary
- Prompt you to manually delete the GitHub App
- Prompt you to commit the teardown log

## Customizing Repository Templates

The setup script uses a flexible templating system to initialize asset repositories with custom content.

### Default Templates

By default, the script uses simple, open-source-friendly templates:
- **Config repo**: Simple README with available variables documented
- **Deployment repo**: Basic Kubernetes ConfigMap

### Custom Templates

To customize templates for your organization:

1. Create the local repository templates directory:
   ```bash
   mkdir -p repo-templates.local/asset-config repo-templates.local/asset-deployment
   ```

2. Add your template files (with `.tpl` extension):
   ```
   repo-templates.local/
   ├── asset-config/
   │   └── my-config.yaml.tpl
   └── asset-deployment/
       ├── kustomization.yaml.tpl
       └── base/
           └── deployment.yaml.tpl
   ```

3. Use template variables in your files:
   ```yaml
   # my-config.yaml.tpl
   name: {{ASSET_NAME}}
   id: {{ASSET_ID}}
   repository: {{GITHUB_URL}}/{{REPO_OWNER}}/{{DEPLOYMENT_REPO}}
   ```

### Available Template Variables

See [`repo-templates.local/README.md`](repo-templates.local/README.md) for the complete list of available variables.

Key variables include:
- `{{ASSET_ID}}`, `{{ASSET_NAME}}`
- `{{GITHUB_ORG}}`, `{{GITHUB_URL}}`, `{{REPO_OWNER}}`
- `{{CONFIG_REPO}}`, `{{DEPLOYMENT_REPO}}`
- `{{DESTINATION_CLUSTER_URL}}`, `{{ARGOCD_NAMESPACE}}`
- `{{TIMESTAMP}}`

### Disabling Config Repositories

For open-source scenarios where only deployment repos are needed:

```bash
# In config.local.sh
export CREATE_CONFIG_REPO=false
```

This will skip creating config repositories entirely, creating only deployment repos.

## GitHub App Configuration

The setup script simplifies GitHub App creation by automatically opening your browser to the correct page with clear, step-by-step instructions. When you choose to create a new app, the script will:

1. Generate a unique app name (e.g., `promoter-test-2025-10-04-14-30-00`)
2. Open your browser to the GitHub App creation page
3. Display clear instructions for:
   - What name to use
   - Which permissions to set
   - How to disable webhooks

### Semi-Automated Creation

The script automates the tedious parts:
- Opens the correct URL for your account type (user vs org)
- Generates a unique, timestamped app name
- Provides copy-paste-ready values
- Shows exactly which permissions to configure

### Permissions

The app is created with these permissions (as documented in the [GitOps Promoter Getting Started guide](https://gitops-promoter.readthedocs.io/en/latest/getting-started/#github-app-configuration)):

| Permission      | Access         |
|----------------|----------------|
| Contents       | Read and write |
| Pull requests  | Read and write |
| Commit statuses| Read and write |

### Usage

The GitHub App is used for:
1. **Promoter**: SCM authentication via ClusterScmProvider
2. **Argo CD Source Hydrator**: Write access to deployment repositories

### Saving Configuration

After entering your GitHub App details, the script will offer to save them to `config.local.sh`:

```
Would you like to save these settings to config.local.sh for future runs? (Y/n)
```

If you choose **Yes** (default):
- Creates `config.local.sh` if it doesn't exist
- Saves the app name, ID, and private key path
- Future runs will use these settings automatically
- No need to re-enter details for subsequent tests

### Reusing Existing Apps

You can also reuse an existing GitHub App by:
- **Automatic**: Say "Yes" when prompted to save settings (recommended)
- **Manual**: Set variables in `config.local.sh` before running setup
- **Interactive**: Choose "use existing app" when prompted during setup

## Understanding the Resources

### GitOps Promoter Resources

Each asset gets three GitOps Promoter resources based on the [official tutorial](https://gitops-promoter.readthedocs.io/en/latest/tutorial-argocd-apps/):

#### GitRepository
References the deployment repository for the asset, connecting it to the ClusterScmProvider.

#### PromotionStrategy
Defines:
- 6 environments (dev/stg/prd × use2/usw2)
- Branch mappings for each environment (`environment/{env}-{region}`)
- Auto-merge settings (enabled for dev/stg, disabled for prd)
- Active commit statuses (`argocd-health`)

#### ArgoCDCommitStatus
Monitors Argo CD Application health and maintains the `argocd-health` commit status on pull requests, enabling automatic promotion based on application sync status.

### Argo CD Applications

Each asset gets 6 Applications (one per environment/region) configured with the source hydrator plugin per the [GitOps Promoter Argo CD tutorial](https://gitops-promoter.readthedocs.io/en/latest/tutorial-argocd-apps/):

```yaml
sourceHydrator:
  drySource:
    repoURL: <config-repo>
    path: .
    targetRevision: HEAD
  hydrateTo:
    targetBranch: environment/{env}-{region}-next
  syncSource:
    targetBranch: environment/{env}-{region}
    path: .
```

Key configuration:
- **drySource**: Points to config repo (promoter-test-NNNN)
- **hydrateTo**: Hydration happens on `-next` branch
- **syncSource**: Argo CD syncs from promotion branch (without `-next`)
- **Destination**: Namespace in destination cluster
- **Sync Policy**: Automated with self-heal enabled

## Monitoring the Test

### Promoter Metrics

Monitor the Promoter controllers for:
- Reconciliation rate and latency
- PR creation and merge activity
- Commit status checks
- Error rates

### Argo CD Metrics

Monitor Argo CD for:
- Application sync status
- Sync duration
- Hydrator plugin performance
- API server load

### Cluster Resources

Monitor cluster resource utilization:
- Controller CPU and memory usage
- API server request rate and latency
- Namespace creation and deletion

## Best Practices

1. **Start small** - Test with a small number of assets first (e.g., 10) to validate the setup
2. **Always commit after setup** - This ensures you have a record of what was created
3. **Document as you go** - Fill out the results file during the test
4. **Monitor continuously** - Keep an eye on metrics throughout the test
5. **Run teardown** - Always clean up resources to avoid cluster pollution
6. **Version control everything** - Commit all run data for historical tracking

## Troubleshooting

### Setup fails

- **GitHub CLI not authenticated**: Run `gh auth login`
- **kubectl not configured**: Ensure your kubeconfig is set up correctly
- **Permission denied creating repos**: Verify you have admin access to the GitHub organization
- **GitHub App creation fails**: Create the app manually following the prompts

### Resources not created

- **Review setup.log**: Check `runs/<timestamp>/logs/setup.log` for errors
- **Verify GitHub App**: Ensure the app is installed to all deployment repositories
- **Check credentials**: Verify the private key is correct

### Resources already exist

**Problem:** `kubectl create` fails with "AlreadyExists" error

**Solution:** Run teardown first to clean up:
```bash
./teardown.sh <timestamp>
kubectl get all -A -l load-test=true  # Verify cleanup
```

### Teardown incomplete

- **Manually verify resources**: Check the commands in `logs/TEARDOWN_SUMMARY.md`
- **Review teardown.log**: Check for specific error messages in `logs/teardown.log`
- **Stuck resources**: May need to manually delete with `kubectl delete --force --grace-period=0`

### Applications not syncing

- **Check Argo CD logs**: Look for hydrator plugin errors
- **Verify repo credentials**: Ensure the GitHub App has write access
- **Check branch existence**: Verify all environment branches exist in deployment repos

## Test Scenarios

Example test scenarios to run:

1. **Baseline**: Small number of assets (10-20) to establish baseline metrics
2. **Scale Up**: Gradually increase assets to find performance limits
3. **Promotion Storm**: Trigger promotions across all assets simultaneously
4. **Long Running**: Leave resources running to test steady-state behavior
5. **Failure Recovery**: Introduce failures and measure recovery time

## References

- [GitOps Promoter Documentation](https://gitops-promoter.readthedocs.io/)
- [GitOps Promoter Getting Started](https://gitops-promoter.readthedocs.io/en/latest/getting-started/)
- [Argo CD Source Hydrator](https://argo-cd.readthedocs.io/en/latest/user-guide/config-management-plugins/)

## Contributing

When adding new test scenarios or modifying scripts:
1. Update this README
2. Test on a non-production cluster
3. Document any new parameters or options
4. Update templates if adding new resource types
