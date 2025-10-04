#!/usr/bin/env bash

# Strict error handling:
# -e: Exit immediately if any command fails
# -u: Treat unset variables as errors
# -o pipefail: Fail if any command in a pipeline fails (not just the last one)
set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities
source "$SCRIPT_DIR/lib/common.sh"

# Function to detect run directory
detect_run_dir() {
    local current_dir=$(pwd)
    local base_dir=$(basename "$current_dir")
    
    # Check if we're in a run directory (matches timestamp pattern with all hyphens)
    if [[ "$base_dir" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}$ ]]; then
        echo "$current_dir"
        return 0
    fi
    
    return 1
}

# Determine run directory
if [ $# -eq 0 ]; then
    # Try to auto-detect if we're in a run directory
    if RUN_DIR=$(detect_run_dir); then
        TIMESTAMP=$(basename "$RUN_DIR")
    else
        echo "ERROR: Missing required parameter: run path"
        echo "Usage: $0 <run-path>"
        echo "Example: $0 runs/2025-10-04-14-30-00"
        echo ""
        echo "Or run this script from within a run directory"
        exit 1
    fi
else
    ARG=$1
    # Only accept runs/ prefix format
    if [[ "$ARG" == runs/* ]]; then
        RUN_DIR="$ARG"
        TIMESTAMP=$(basename "$RUN_DIR")
    else
        echo "ERROR: Invalid argument format"
        echo "Usage: $0 <run-path>"
        echo "Example: $0 runs/2025-10-04-14-30-00"
        echo ""
        echo "The argument must start with 'runs/'"
        exit 1
    fi
fi

# Validate that the run directory exists
if [ ! -d "$RUN_DIR" ]; then
    echo "ERROR: Run directory not found: $RUN_DIR"
    echo "Available runs:"
    if [ -d "runs" ]; then
        ls -1 runs/
    else
        echo "  (none)"
    fi
    exit 1
fi

# Load configuration
if [ -f "config.sh" ]; then
    source config.sh
else
    echo "ERROR: config.sh not found"
    exit 1
fi

# Check for required tools (must happen before we create log file)
if ! command -v kubectl &> /dev/null; then
    echo "ERROR: kubectl is not installed. Please install it first."
    exit 1
fi

# Create logs directory if it doesn't exist
LOGS_DIR="$RUN_DIR/logs"
mkdir -p "$LOGS_DIR"

# Create log file and setup logging to both console and file
# This must happen BEFORE any output we want to capture
# Strip ANSI color codes from log file using sed
LOG_FILE="$LOGS_DIR/teardown.log"
exec > >(tee >(sed 's/\x1b\[[0-9;]*m//g' >> "$LOG_FILE")) 2>&1

# ============================================================================
# EVERYTHING BELOW THIS LINE IS LOGGED TO BOTH CONSOLE AND LOG FILE
# ============================================================================

print_header "Promoter Load Test Teardown"
log_info "Run timestamp: $TIMESTAMP"
log_info "Run directory: $RUN_DIR"
log_info "Log file: $LOG_FILE"
log_info "Teardown started at: $(date)"
log_info "✓ Configuration loaded from config.sh"
log_info "✓ kubectl found"

# Check if manifests directory exists
MANIFESTS_DIR="$RUN_DIR/manifests"
if [ ! -d "$MANIFESTS_DIR" ]; then
    log_warn "Manifests directory not found: $MANIFESTS_DIR"
    log_warn "Nothing to clean up"
    exit 0
fi

log_info "This script will delete Kubernetes resources only."
log_warn "GitHub repositories and apps will NOT be deleted (reuse them for future tests)."

# Delete Kubernetes resources
print_header "Deleting Kubernetes Resources"

echo ""
echo -e "${YELLOW}The following commands will delete the Kubernetes resources:${NC}"
echo ""
echo -e "${CYAN}# Promoter Cluster:${NC}"
echo -e "kubectl delete secret promoter-github-app -n promoter-system --ignore-not-found=true"
echo -e "kubectl delete -f $MANIFESTS_DIR/promoter/all-resources.yaml"
echo ""
echo -e "${CYAN}# Argo CD Cluster:${NC}"
echo -e "kubectl delete -f $MANIFESTS_DIR/argocd/all-resources.yaml"
echo ""
echo -e "${CYAN}# Destination Cluster:${NC}"
echo -e "kubectl delete -f $MANIFESTS_DIR/destination/all-resources.yaml"
echo ""

read -p "Would you like to execute these deletion commands now? (Y/n) " -r
echo
if [[ -z "$REPLY" || $REPLY =~ ^[Yy]$ ]]; then
    log_step "Deleting resources from Promoter cluster..."
    log_detail "Deleting imperatively-created GitHub App Secret..."
    kubectl delete secret promoter-github-app -n promoter-system --ignore-not-found=true || log_warn "Secret may not exist"
    
    if [ -f "$MANIFESTS_DIR/promoter/all-resources.yaml" ]; then
        kubectl delete -f "$MANIFESTS_DIR/promoter/all-resources.yaml" --ignore-not-found=true || log_warn "Some promoter resources may not exist"
    else
        log_warn "Promoter manifests file not found"
    fi
    
    log_step "Deleting resources from Argo CD cluster..."
    if [ -f "$MANIFESTS_DIR/argocd/all-resources.yaml" ]; then
        kubectl delete -f "$MANIFESTS_DIR/argocd/all-resources.yaml" --ignore-not-found=true || log_warn "Some Argo CD resources may not exist"
    else
        log_warn "Argo CD manifests file not found"
    fi
    
    log_step "Deleting resources from Destination cluster..."
    if [ -f "$MANIFESTS_DIR/destination/all-resources.yaml" ]; then
        kubectl delete -f "$MANIFESTS_DIR/destination/all-resources.yaml" --ignore-not-found=true || log_warn "Some destination resources may not exist"
    else
        log_warn "Destination manifests file not found"
    fi
    
    log_info "Kubernetes resources deleted"
else
    log_warn "Skipped Kubernetes resource deletion"
    echo "You can manually delete resources later using the commands above"
fi


# Create teardown summary
cat > "$LOGS_DIR/TEARDOWN_SUMMARY.md" << EOF
# Teardown Summary - $TIMESTAMP

## Teardown Completed
- **Date:** $(date)
- **Run Directory:** $RUN_DIR

## Kubernetes Resources Deleted

- **Promoter cluster:** GitRepository, PromotionStrategy, ArgoCDCommitStatus resources, namespaces, ClusterScmProvider, Secret
- **Argo CD cluster:** Applications, AppProjects, repo credential Secrets
- **Destination cluster:** Namespaces

## GitHub Resources Preserved

GitHub repositories and apps were **NOT** deleted. They can be reused for future tests.

To manually delete if needed:
- Repositories are listed in: $RUN_DIR/logs/SETUP_SUMMARY.md
- GitHub App details in: $RUN_DIR/logs/SETUP_SUMMARY.md

## Verification

Verify all Kubernetes resources are deleted:
\`\`\`bash
# Check promoter cluster
kubectl get namespaces -l load-test-run=$TIMESTAMP
kubectl get gitrepositories,promotionstrategies,argocdcommitstatuses -A

# Check Argo CD cluster
kubectl get applications -n $ARGOCD_NAMESPACE
kubectl get appprojects -n $ARGOCD_NAMESPACE

# Check destination cluster
kubectl get namespaces -l load-test-run=$TIMESTAMP
\`\`\`

## Logs

- Setup log: $LOGS_DIR/setup.log
- Teardown log: $LOGS_DIR/teardown.log
EOF

log_info "Teardown summary saved to $LOGS_DIR/TEARDOWN_SUMMARY.md"

print_header "Teardown Complete"
log_info "Teardown finished at: $(date)"
echo ""
log_info "Next steps:"
echo "  1. Review teardown log: $LOG_FILE"
echo "  2. Review teardown summary: $LOGS_DIR/TEARDOWN_SUMMARY.md"
echo "  3. Verify resources are deleted (see summary for verification commands)"
echo "  4. Commit the teardown log:"
echo "     git add $LOGS_DIR/teardown.log $LOGS_DIR/TEARDOWN_SUMMARY.md"
echo "     git commit -m 'Add teardown log for load test run $TIMESTAMP'"
echo ""

# Prompt user to commit
read -p "Would you like to commit the teardown log now? (Y/n) " -r
echo
if [[ -z "$REPLY" || $REPLY =~ ^[Yy]$ ]]; then
    git add "$LOG_FILE" "$LOGS_DIR/TEARDOWN_SUMMARY.md"
    git commit -m "Add teardown log for load test run $TIMESTAMP"
    log_info "Teardown log committed successfully"
else
    log_warn "Remember to commit the teardown log!"
fi
