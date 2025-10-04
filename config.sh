#!/usr/bin/env bash

# Configuration file for promoter load test
# Edit these values to match your environment

# GitHub Configuration (for test asset repositories)
# Defaults use the canonical public repository settings
export GITHUB_ORG="${GITHUB_ORG:-crenshaw-dev}"
export GITHUB_DOMAIN="${GITHUB_DOMAIN:-github.com}"

# Load Test Tool Repository Configuration
# This is the repository containing THIS load test tool itself
# Used to create an Argo CD Application that deploys the generated promoter manifests
# Defaults point to the public GitHub repository
export LOADTEST_REPO_DOMAIN="${LOADTEST_REPO_DOMAIN:-github.com}"
export LOADTEST_REPO_ORG="${LOADTEST_REPO_ORG:-crenshaw-dev}"
export LOADTEST_REPO_NAME="${LOADTEST_REPO_NAME:-gitops-promoter-loadtest}"

# GitHub App Configuration (optional - leave empty to be prompted during setup)
# If set, these values will be used automatically instead of prompting
export GITHUB_APP_NAME="${GITHUB_APP_NAME:-}"
export GITHUB_APP_ID="${GITHUB_APP_ID:-}"
export GITHUB_APP_KEY_PATH="${GITHUB_APP_KEY_PATH:-}"
export GITHUB_APP_INSTALLATION_ID="${GITHUB_APP_INSTALLATION_ID:-}"

# Git Configuration (optional - for commits to test repos)
# Set this to your GitHub noreply email if you have email privacy enabled
# Format: USERNAME@users.noreply.github.com or ID+USERNAME@users.noreply.github.com
export GIT_AUTHOR_EMAIL="${GIT_AUTHOR_EMAIL:-}"
export GIT_COMMITTER_EMAIL="${GIT_COMMITTER_EMAIL:-}"

# Cluster Configuration
export PROMOTER_CLUSTER_URL="${PROMOTER_CLUSTER_URL:-https://kubernetes.default.svc}"
export ARGO_CLUSTER_URL="${ARGO_CLUSTER_URL:-https://kubernetes.default.svc}"
export DESTINATION_CLUSTER_URL="${DESTINATION_CLUSTER_URL:-https://kubernetes.default.svc}"

# Namespace Configuration
export ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"

# Test Regions and Environments
export REGIONS=("use2" "usw2")
export ENVIRONMENTS=("dev" "stg" "prd")

# Repository Templates
# Set to false to skip creating config repositories (deployment repos only)
export CREATE_CONFIG_REPO="${CREATE_CONFIG_REPO:-false}"

# Load local overrides if they exist (this file is gitignored)
# Create config.local.sh to override any of the above settings
if [ -f "$(dirname "${BASH_SOURCE[0]}")/config.local.sh" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/config.local.sh"
fi

# GITHUB_URL is inferred from GITHUB_DOMAIN (must be set AFTER loading config.local.sh)
export GITHUB_URL="https://${GITHUB_DOMAIN}"
export LOADTEST_REPO_URL="https://${LOADTEST_REPO_DOMAIN}"
