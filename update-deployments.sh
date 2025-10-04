#!/bin/bash
set -euo pipefail

# Load common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/config.sh"

# Parse command line arguments
DURATION="${1:-300}"  # Default 5 minutes (300 seconds)
JITTER="${2:-30}"     # Default 30 seconds
FILENAME="${3:-configmap.yaml}"  # Default filename
JQ_PATH="${4:-data.timestamp}"   # Default jq path

# Validate numeric inputs
if ! [[ "$DURATION" =~ ^[0-9]+$ ]]; then
    log_error "Duration must be a positive integer (seconds)"
    exit 1
fi

if ! [[ "$JITTER" =~ ^[0-9]+$ ]]; then
    log_error "Jitter must be a positive integer (seconds)"
    exit 1
fi

# Check required tools
for cmd in git jq yq; do
    if ! command -v $cmd &> /dev/null; then
        log_error "$cmd is not installed. Please install it first."
        exit 1
    fi
done

log_info "=== Deployment Updater ==="
log_info "Configuration:"
log_info "  Duration: ${DURATION}s"
log_info "  Jitter: ±${JITTER}s"
log_info "  File: $FILENAME"
log_info "  Path: $JQ_PATH"
echo ""

# Get list of deployment repos from most recent run
LATEST_RUN=$(ls -t runs/ | head -1)
if [ -z "$LATEST_RUN" ]; then
    log_error "No run directories found. Please run setup.sh first."
    exit 1
fi

MANIFESTS_DIR="$SCRIPT_DIR/runs/$LATEST_RUN/manifests/argo"
if [ ! -f "$MANIFESTS_DIR/all-resources.yaml" ]; then
    log_error "No manifests found in runs/$LATEST_RUN/manifests/argo/"
    exit 1
fi

# Extract asset IDs from the manifests
ASSET_IDS=$(grep "name: promoter-test-" "$MANIFESTS_DIR/all-resources.yaml" | \
    grep -o "promoter-test-[0-9]\+" | \
    sed 's/promoter-test-//' | \
    sort -u)

if [ -z "$ASSET_IDS" ]; then
    log_error "No assets found in manifests"
    exit 1
fi

ASSET_COUNT=$(echo "$ASSET_IDS" | wc -l | tr -d ' ')
log_info "Found $ASSET_COUNT deployment repos to update"
echo ""

# Create temp directory for clones
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

log_step "Cloning deployment repositories..."
for asset_id in $ASSET_IDS; do
    repo_name="promoter-test-${asset_id}-deployment"
    log_detail "Cloning $repo_name..."
    
    git clone --quiet "${GITHUB_URL}/${GITHUB_ORG}/${repo_name}" \
        "$TEMP_DIR/$repo_name" 2>&1 | grep -v "^Cloning" || true
    
    # Configure git email if set
    if [ -n "$GIT_AUTHOR_EMAIL" ]; then
        git -C "$TEMP_DIR/$repo_name" config user.email "$GIT_AUTHOR_EMAIL"
    fi
done
log_info "✓ All repositories cloned"
echo ""

# Function to calculate sleep duration with jitter
calculate_sleep() {
    local jitter_amount=$((RANDOM % (JITTER * 2 + 1) - JITTER))
    echo $((DURATION + jitter_amount))
}

# Function to update a single repo
update_repo() {
    local repo_name=$1
    local repo_path="$TEMP_DIR/$repo_name"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    log_detail "[$repo_name] Updating $FILENAME at path $JQ_PATH to $timestamp"
    
    cd "$repo_path"
    
    # Pull latest changes
    git pull --quiet origin HEAD 2>&1 | grep -v "^From" || true
    
    # Check if file exists
    if [ ! -f "$FILENAME" ]; then
        log_warn "[$repo_name] $FILENAME not found, skipping"
        return 1
    fi
    
    # Detect file type and update accordingly
    if [[ "$FILENAME" =~ \.(yaml|yml)$ ]]; then
        # YAML file - use yq
        yq eval ".$JQ_PATH = \"$timestamp\"" -i "$FILENAME"
    elif [[ "$FILENAME" =~ \.json$ ]]; then
        # JSON file - use jq
        jq ".$JQ_PATH = \"$timestamp\"" "$FILENAME" > "${FILENAME}.tmp"
        mv "${FILENAME}.tmp" "$FILENAME"
    else
        log_warn "[$repo_name] Unsupported file type, skipping"
        return 1
    fi
    
    # Check if there are changes
    if ! git diff --quiet "$FILENAME"; then
        git add "$FILENAME"
        git commit -m "Update $JQ_PATH to $timestamp" --quiet
        
        # Push and detect default branch
        DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')
        git push origin "HEAD:$DEFAULT_BRANCH" --quiet 2>&1 | grep -v "^To" || true
        
        log_info "[$repo_name] ✓ Updated and pushed"
    else
        log_detail "[$repo_name] No changes to commit"
    fi
}

# Main update loop
iteration=1
log_info "Starting update loop (Ctrl+C to stop)..."
echo ""

while true; do
    log_step "Iteration $iteration - $(date)"
    
    # Update each repo
    for asset_id in $ASSET_IDS; do
        repo_name="promoter-test-${asset_id}-deployment"
        update_repo "$repo_name" || true
    done
    
    # Calculate next sleep duration
    sleep_duration=$(calculate_sleep)
    log_info "Sleeping for ${sleep_duration}s (next update at $(date -v +${sleep_duration}S '+%H:%M:%S' 2>/dev/null || date -d "+${sleep_duration} seconds" '+%H:%M:%S' 2>/dev/null || echo "in ${sleep_duration}s"))"
    echo ""
    
    sleep "$sleep_duration"
    iteration=$((iteration + 1))
done

