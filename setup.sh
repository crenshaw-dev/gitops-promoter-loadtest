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

# Check if number of assets parameter is provided
if [ $# -eq 0 ]; then
    log_error "Missing required parameter: number of fake assets"
    echo "Usage: $0 <number_of_assets>"
    echo "Example: $0 100"
    exit 1
fi

NUM_ASSETS=$1

# Validate that the parameter is a positive integer
if ! [[ "$NUM_ASSETS" =~ ^[0-9]+$ ]] || [ "$NUM_ASSETS" -le 0 ]; then
    log_error "Number of assets must be a positive integer"
    exit 1
fi

# Load configuration
if [ -f "config.sh" ]; then
    source config.sh
else
    echo "ERROR: config.sh not found. Please create it from the template."
    exit 1
fi

# Validate required configuration
if [ "$GITHUB_ORG" = "your-github-org" ]; then
    echo "ERROR: Please configure GITHUB_ORG in config.sh to your actual GitHub organization"
    echo "Current value: $GITHUB_ORG"
    exit 1
fi

# Check for required tools (must happen before we create log file)
for tool in gh kubectl jq; do
    if ! command -v $tool &> /dev/null; then
        echo "ERROR: $tool is not installed. Please install it first."
        exit 1
    fi
done

# Check GitHub CLI authentication
if ! gh auth status --hostname "$GITHUB_DOMAIN" &> /dev/null; then
    echo "GitHub CLI not authenticated for $GITHUB_DOMAIN. Authenticating..."
    
    # Authenticate with the configured GitHub instance
    if ! gh auth login --hostname "$GITHUB_DOMAIN" --web; then
        echo "ERROR: GitHub CLI authentication failed"
        exit 1
    fi
    
    echo "✓ GitHub CLI authenticated successfully"
fi

# Create timestamp for this run (using hyphens throughout)
TIMESTAMP=$(date +%Y-%m-%d-%H-%M-%S)
RUN_DIR="runs/$TIMESTAMP"
MANIFESTS_DIR="$RUN_DIR/manifests"
LOGS_DIR="$RUN_DIR/logs"

# Create directory structure
mkdir -p "$MANIFESTS_DIR"/{promoter,argocd,destination}
mkdir -p "$LOGS_DIR"

# Create log file and setup logging to both console and file
# This must happen BEFORE any output we want to capture
# Strip ANSI color codes from log file using sed
LOG_FILE="$LOGS_DIR/setup.log"
exec > >(tee >(sed 's/\x1b\[[0-9;]*m//g' >> "$LOG_FILE")) 2>&1

# ============================================================================
# EVERYTHING BELOW THIS LINE IS LOGGED TO BOTH CONSOLE AND LOG FILE
# ============================================================================

print_header "Promoter Load Test Setup"
log_info "Number of assets: $NUM_ASSETS"
log_info "Asset GitHub Organization: $GITHUB_ORG"
log_info "Asset GitHub URL: $GITHUB_URL"
log_info "Load Test Repository: $LOADTEST_REPO_URL/$LOADTEST_REPO_ORG/$LOADTEST_REPO_NAME"
log_info "Promoter Cluster: $PROMOTER_CLUSTER_URL"
log_info "Argo CD Cluster: $ARGO_CLUSTER_URL"
log_info "Destination Cluster: $DESTINATION_CLUSTER_URL"
log_info "Run directory: $RUN_DIR"
log_info "Manifests directory: $MANIFESTS_DIR"
log_info "Log file: $LOG_FILE"

# Confirm tools and configuration
print_header "Validated Prerequisites"
log_info "✓ Configuration loaded from config.sh"
log_info "✓ gh (GitHub CLI) found and authenticated"
log_info "✓ kubectl found"
log_info "✓ jq found"

# Copy test results template
log_info "Copying test results template"
if [ -f "test-results-template.md" ]; then
    cp test-results-template.md "$RUN_DIR/README.md"
    
    # Add metadata to the results file (using temp file for cross-platform compatibility)
    cat > "$RUN_DIR/README.md.tmp" << EOF
# Load Test Results - $TIMESTAMP

**Number of Assets:** $NUM_ASSETS
**Start Time:** $(date)
**GitHub Organization:** $GITHUB_ORG

---

EOF
    cat test-results-template.md >> "$RUN_DIR/README.md.tmp"
    mv "$RUN_DIR/README.md.tmp" "$RUN_DIR/README.md"
else
    log_warn "test-results-template.md not found, creating basic results file"
    cat > "$RUN_DIR/README.md" << EOF
# Load Test Results - $TIMESTAMP

**Number of Assets:** $NUM_ASSETS
**Start Time:** $(date)
**GitHub Organization:** $GITHUB_ORG

## Test Parameters

<!-- Fill in test parameters -->

## Results

<!-- Document your findings here -->
EOF
fi

log_info "Results file created: $RUN_DIR/README.md"

# Auto-detect GitHub account type early so we can use it for URL generation
print_header "Detecting GitHub Account Type"
log_info "Auto-detecting account type for $GITHUB_ORG..."

# Try to check if it's an org first
if GH_HOST="$GITHUB_DOMAIN" gh api "orgs/$GITHUB_ORG" &>/dev/null; then
    GITHUB_ACCOUNT_TYPE="org"
    log_info "Detected as organization"
elif GH_HOST="$GITHUB_DOMAIN" gh api "users/$GITHUB_ORG" &>/dev/null; then
    GITHUB_ACCOUNT_TYPE="user"
    log_info "Detected as user account"
else
    log_warn "Could not auto-detect account type, defaulting to 'user'"
    GITHUB_ACCOUNT_TYPE="user"
fi

# Create or use existing GitHub App
print_header "GitHub App Configuration"

# Check if GitHub App details are already configured
if [ -n "$GITHUB_APP_NAME" ] && [ -n "$GITHUB_APP_ID" ] && [ -n "$GITHUB_APP_KEY_PATH" ]; then
    log_info "Using GitHub App configuration from config.sh:"
    log_detail "App Name: $GITHUB_APP_NAME"
    log_detail "App ID: $GITHUB_APP_ID"
    log_detail "Key Path: $GITHUB_APP_KEY_PATH"
else
    echo ""
    read -p "Do you want to use an existing GitHub App? (y/n) " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Using existing GitHub App"
        echo ""
        while true; do
            read -p "GitHub App Name: " GITHUB_APP_NAME
            if [ -z "$GITHUB_APP_NAME" ]; then
                log_error "GitHub App name cannot be empty. Please try again."
            else
                break
            fi
        done
    else
        GITHUB_APP_NAME="promoter-test-$TIMESTAMP"
        log_step "Creating new GitHub App: $GITHUB_APP_NAME"
        
        # Simplified manual creation with better instructions
        log_info "Opening GitHub to create app with pre-configured settings..."
        
        if [ "$GITHUB_ACCOUNT_TYPE" = "org" ]; then
            MANIFEST_URL="$GITHUB_URL/organizations/$GITHUB_ORG/settings/apps/new"
        else
            MANIFEST_URL="$GITHUB_URL/settings/apps/new"
        fi
        
        echo ""
        echo -e "${YELLOW}Creating GitHub App in your browser:${NC}"
        echo -e "  1. A browser window will open to GitHub App creation"
        echo -e "  2. Fill in the following:"
        echo -e "     - Name: ${CYAN}$GITHUB_APP_NAME${NC}"
        echo -e "     - Homepage URL: ${CYAN}$GITHUB_URL/$GITHUB_ORG/$LOADTEST_REPO_NAME${NC}"
        echo -e "     - ${YELLOW}Uncheck 'Webhook' → Active${NC} (disable webhooks)"
        echo -e "  3. Set Repository permissions:"
        echo -e "     - ${GREEN}Commit statuses: Read and write${NC}"
        echo -e "     - ${GREEN}Contents: Read and write${NC}"
        echo -e "     - ${GREEN}Pull requests: Read and write${NC}"
        echo -e "  4. Click ${GREEN}'Create GitHub App'${NC}"
        echo -e "  5. After creation, click ${GREEN}'Generate a private key'${NC}"
        echo -e "  6. Save the downloaded .pem file"
        echo ""
        
        # Open browser
        if command -v open &> /dev/null; then
            open "$MANIFEST_URL"
            log_info "Opened browser to: $MANIFEST_URL"
        elif command -v xdg-open &> /dev/null; then
            xdg-open "$MANIFEST_URL"
            log_info "Opened browser to: $MANIFEST_URL"
        else
            echo -e "${YELLOW}Please open this URL in your browser:${NC}"
            echo "$MANIFEST_URL"
        fi
        
        echo ""
        read -p "Press Enter after you've created the GitHub App and downloaded the private key..."
    fi

    # Prompt for GitHub App details
    echo ""
    log_step "Please provide the GitHub App details:"
    read -p "GitHub App ID: " GITHUB_APP_ID
    read -p "Path to GitHub App private key file: " GITHUB_APP_KEY_PATH
    
    # Offer to save configuration
    echo ""
    read -p "Would you like to save these settings to config.local.sh for future runs? (Y/n) " -r
    echo
    if [[ -z "$REPLY" || $REPLY =~ ^[Yy]$ ]]; then
        log_info "Saving GitHub App configuration to config.local.sh..."
        
        # Create or update config.local.sh
        if [ ! -f "config.local.sh" ]; then
            # Create new file from example
            cp config.local.sh.example config.local.sh
            log_detail "Created config.local.sh from example"
        fi
        
        # Update or add the GitHub App settings
        # Remove existing GitHub App settings if they exist
        sed -i.bak '/^export GITHUB_APP_NAME=/d' config.local.sh 2>/dev/null || true
        sed -i.bak '/^export GITHUB_APP_ID=/d' config.local.sh 2>/dev/null || true
        sed -i.bak '/^export GITHUB_APP_KEY_PATH=/d' config.local.sh 2>/dev/null || true
        sed -i.bak '/^# export GITHUB_APP_NAME=/d' config.local.sh 2>/dev/null || true
        sed -i.bak '/^# export GITHUB_APP_ID=/d' config.local.sh 2>/dev/null || true
        sed -i.bak '/^# export GITHUB_APP_KEY_PATH=/d' config.local.sh 2>/dev/null || true
        rm -f config.local.sh.bak
        
        # Append the new settings
        cat >> config.local.sh << EOF

# GitHub App Configuration (saved from setup on $(date))
export GITHUB_APP_NAME="$GITHUB_APP_NAME"
export GITHUB_APP_ID="$GITHUB_APP_ID"
export GITHUB_APP_KEY_PATH="$GITHUB_APP_KEY_PATH"
EOF
        
        log_info "✓ Configuration saved to config.local.sh"
        log_detail "Future runs will use these settings automatically"
    else
        log_info "Skipped saving configuration"
    fi
fi

if [ ! -f "$GITHUB_APP_KEY_PATH" ]; then
    log_error "Private key file not found: $GITHUB_APP_KEY_PATH"
    exit 1
fi

# Read the private key
GITHUB_APP_PRIVATE_KEY=$(cat "$GITHUB_APP_KEY_PATH")

# Set installation ID to empty if not set (will be prompted for later if needed)
GITHUB_APP_INSTALLATION_ID="${GITHUB_APP_INSTALLATION_ID:-}"

# Generate GitHub repos and commit initial files
print_header "Creating GitHub Repositories"
if [ "$CREATE_CONFIG_REPO" = "true" ]; then
    log_info "This will create $((NUM_ASSETS * 2)) repositories (config + deployment)"
else
    log_info "This will create $NUM_ASSETS repositories (deployment only, config repos disabled)"
fi
log_info "Account type: $GITHUB_ACCOUNT_TYPE"

# Track created repos for summary
CREATED_REPOS=()

for i in $(seq -f "%04g" 0 $((NUM_ASSETS - 1))); do
    ASSET_ID="$i"
    CONFIG_REPO="promoter-test-$ASSET_ID"
    DEPLOYMENT_REPO="promoter-test-$ASSET_ID-deployment"
    
    log_step "Creating repositories for asset $ASSET_ID"
    
    # Determine the repo owner (org or authenticated user)
    if [ "$GITHUB_ACCOUNT_TYPE" = "org" ]; then
        REPO_OWNER="$GITHUB_ORG"
    else
        # For personal accounts, get the authenticated user
        REPO_OWNER=$(GH_HOST="$GITHUB_DOMAIN" gh api user -q .login)
    fi
    
    # Create config repo (handles both user accounts and orgs) - if enabled
    if [ "$CREATE_CONFIG_REPO" = "true" ]; then
        log_detail "Creating $CONFIG_REPO"
        REPO_FULL_NAME="$REPO_OWNER/$CONFIG_REPO"
        
        # Check if repo already exists
        if GH_HOST="$GITHUB_DOMAIN" gh repo view "$REPO_FULL_NAME" &>/dev/null; then
            log_warn "  Repository $REPO_FULL_NAME already exists, reusing it"
        else
            if [ "$GITHUB_ACCOUNT_TYPE" = "org" ]; then
                if ! OUTPUT=$(GH_HOST="$GITHUB_DOMAIN" gh repo create "$GITHUB_ORG/$CONFIG_REPO" --public 2>&1); then
                    log_error "Failed to create $CONFIG_REPO"
                    echo "$OUTPUT"
                    exit 1
                fi
            else
                if ! OUTPUT=$(GH_HOST="$GITHUB_DOMAIN" gh repo create "$CONFIG_REPO" --public 2>&1); then
                    log_error "Failed to create $CONFIG_REPO"
                    echo "$OUTPUT"
                    exit 1
                fi
            fi
            log_info "  ✓ Created $CONFIG_REPO"
        fi
    fi
    
    # Create deployment repo
    log_detail "Creating $DEPLOYMENT_REPO"
    REPO_FULL_NAME="$REPO_OWNER/$DEPLOYMENT_REPO"
    
    # Check if repo already exists
    if GH_HOST="$GITHUB_DOMAIN" gh repo view "$REPO_FULL_NAME" &>/dev/null; then
        log_warn "  Repository $REPO_FULL_NAME already exists, reusing it"
    else
        if [ "$GITHUB_ACCOUNT_TYPE" = "org" ]; then
            if ! OUTPUT=$(GH_HOST="$GITHUB_DOMAIN" gh repo create "$GITHUB_ORG/$DEPLOYMENT_REPO" --public 2>&1); then
                log_error "Failed to create $DEPLOYMENT_REPO"
                echo "$OUTPUT"
                exit 1
            fi
        else
            if ! OUTPUT=$(GH_HOST="$GITHUB_DOMAIN" gh repo create "$DEPLOYMENT_REPO" --public 2>&1); then
                log_error "Failed to create $DEPLOYMENT_REPO"
                echo "$OUTPUT"
                exit 1
            fi
        fi
        log_info "  ✓ Created $DEPLOYMENT_REPO"
    fi
    
    # Track repos for summary
    if [ "$CREATE_CONFIG_REPO" = "true" ]; then
        CREATED_REPOS+=("$REPO_OWNER/$CONFIG_REPO")
    fi
    CREATED_REPOS+=("$REPO_OWNER/$DEPLOYMENT_REPO")
    
    # Clone repos and add initial files
    TEMP_DIR=$(mktemp -d)
    
    # Define all template variables for this asset
    ASSET_NAME="promoter-test-$ASSET_ID"
    
    # Helper function to process templates recursively
    process_templates() {
        local template_dir=$1
        local target_dir=$2
        
        if [ ! -d "$template_dir" ]; then
            return
        fi
        
        # Copy and process all files recursively
        cd "$template_dir"
        find . -type f | while read -r file; do
            # Remove leading ./
            file="${file#./}"
            
            # Create target directory structure
            target_file="$target_dir/$file"
            mkdir -p "$(dirname "$target_file")"
            
            # Check if it's a template file
            if [[ "$file" == *.tpl ]]; then
                # Remove .tpl extension
                target_file="${target_file%.tpl}"
                
                # Process template with all variables
                sed -e "s|{{ASSET_ID}}|$ASSET_ID|g" \
                    -e "s|{{ASSET_NAME}}|$ASSET_NAME|g" \
                    -e "s|{{CONFIG_REPO}}|$CONFIG_REPO|g" \
                    -e "s|{{DEPLOYMENT_REPO}}|$DEPLOYMENT_REPO|g" \
                    -e "s|{{GITHUB_ORG}}|$GITHUB_ORG|g" \
                    -e "s|{{GITHUB_URL}}|$GITHUB_URL|g" \
                    -e "s|{{GITHUB_DOMAIN}}|$GITHUB_DOMAIN|g" \
                    -e "s|{{REPO_OWNER}}|$REPO_OWNER|g" \
                    -e "s|{{TIMESTAMP}}|$TIMESTAMP|g" \
                    -e "s|{{DESTINATION_CLUSTER_URL}}|$DESTINATION_CLUSTER_URL|g" \
                    -e "s|{{ARGOCD_NAMESPACE}}|$ARGOCD_NAMESPACE|g" \
                    -e "s|{{PROMOTER_CLUSTER_URL}}|$PROMOTER_CLUSTER_URL|g" \
                    -e "s|{{ARGO_CLUSTER_URL}}|$ARGO_CLUSTER_URL|g" \
                    "$file" > "$target_file"
            else
                # Copy non-template files as-is
                cp "$file" "$target_file"
            fi
        done
        cd "$SCRIPT_DIR"
    }
    
    # Setup config repo (if enabled)
    if [ "$CREATE_CONFIG_REPO" = "true" ]; then
        log_detail "Setting up $CONFIG_REPO"
        git clone "$GITHUB_URL/$REPO_OWNER/$CONFIG_REPO.git" "$TEMP_DIR/$CONFIG_REPO" 2>/dev/null || true
        cd "$TEMP_DIR/$CONFIG_REPO"
        
        # Configure git email if set (for GitHub email privacy)
        if [ -n "$GIT_AUTHOR_EMAIL" ]; then
            git config user.email "$GIT_AUTHOR_EMAIL"
        fi
        
        # Pull latest if repo already has content
        if [ "$(ls -A .)" ]; then
            log_warn "  Repository already has content, pulling latest"
            git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || true
        fi
        
        # Process templates - try local first, then default
        if [ -d "$SCRIPT_DIR/repo-templates.local/asset-config" ]; then
            log_detail "  Using local templates from repo-templates.local/asset-config"
            process_templates "$SCRIPT_DIR/repo-templates.local/asset-config" "$TEMP_DIR/$CONFIG_REPO"
        elif [ -d "$SCRIPT_DIR/repo-templates/asset-config" ]; then
            log_detail "  Using default templates from repo-templates/asset-config"
            process_templates "$SCRIPT_DIR/repo-templates/asset-config" "$TEMP_DIR/$CONFIG_REPO"
        else
            log_warn "  No config templates found, repository will be empty"
        fi
        
        # Ensure we're in the config repo directory before committing
        cd "$TEMP_DIR/$CONFIG_REPO"
        
        # Commit and push if there are changes
        git add -A
        if git diff --cached --quiet; then
            log_detail "  No changes to commit"
        else
            git commit -m "Update configuration for asset $ASSET_ID"
            
            # Detect and push to the default branch
            DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")
            log_detail "  Pushing to $DEFAULT_BRANCH"
            git push origin HEAD:$DEFAULT_BRANCH
        fi
    fi
    
    # Setup deployment repo
    log_detail "Setting up $DEPLOYMENT_REPO"
    cd "$TEMP_DIR"
    git clone "$GITHUB_URL/$REPO_OWNER/$DEPLOYMENT_REPO.git" "$TEMP_DIR/$DEPLOYMENT_REPO" 2>/dev/null || true
    cd "$TEMP_DIR/$DEPLOYMENT_REPO"
    
    # Configure git email if set (for GitHub email privacy)
    if [ -n "$GIT_AUTHOR_EMAIL" ]; then
        git config user.email "$GIT_AUTHOR_EMAIL"
    fi
    
    # Pull latest if repo already has content
    if [ "$(ls -A .)" ]; then
        log_warn "  Repository already has content, pulling latest"
        git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || true
    fi
    
    # Process templates - try local first, then default
    if [ -d "$SCRIPT_DIR/repo-templates.local/asset-deployment" ]; then
        log_detail "  Using local templates from repo-templates.local/asset-deployment"
        process_templates "$SCRIPT_DIR/repo-templates.local/asset-deployment" "$TEMP_DIR/$DEPLOYMENT_REPO"
    elif [ -d "$SCRIPT_DIR/repo-templates/asset-deployment" ]; then
        log_detail "  Using default templates from repo-templates/asset-deployment"
        process_templates "$SCRIPT_DIR/repo-templates/asset-deployment" "$TEMP_DIR/$DEPLOYMENT_REPO"
    else
        log_warn "  No deployment templates found, repository will be empty"
    fi
    
    # Ensure we're in the deployment repo directory before committing
    cd "$TEMP_DIR/$DEPLOYMENT_REPO"
    
    # Commit and push if there are changes
    git add -A
    if git diff --cached --quiet; then
        log_detail "  No changes to commit"
    else
        git commit -m "Update deployment configuration for asset $ASSET_ID"
        
        # Detect and push to the default branch
        DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")
        log_detail "  Pushing to $DEFAULT_BRANCH"
        git push origin HEAD:$DEFAULT_BRANCH
    fi
    
    cd "$SCRIPT_DIR"
    rm -rf "$TEMP_DIR"
    
    log_info "  ✓ Initialized repositories for asset $ASSET_ID"
done

log_info "All repositories created and initialized"

# Prompt to install GitHub App (only if installation ID not configured)
if [ -z "$GITHUB_APP_INSTALLATION_ID" ]; then
    echo ""
    log_step "Installing GitHub App to deployment repositories"
    
    # Construct the installation URL
    if [ "$GITHUB_ACCOUNT_TYPE" = "org" ]; then
        INSTALL_URL="$GITHUB_URL/organizations/$GITHUB_ORG/settings/apps/$GITHUB_APP_NAME/installations"
    else
        INSTALL_URL="$GITHUB_URL/settings/apps/$GITHUB_APP_NAME/installations"
    fi
    
    log_info "Opening browser to install GitHub App..."
    echo ""
    echo -e "${YELLOW}Complete the installation in your browser:${NC}"
    echo -e "  1. Click ${GREEN}'Install'${NC} or ${GREEN}'Configure'${NC}"
    echo -e "  2. Select ${CYAN}'Only select repositories'${NC}"
    echo -e "  3. Select all ${CYAN}promoter-test-*-deployment${NC} repositories"
    echo -e "  4. Click ${GREEN}'Install'${NC} or ${GREEN}'Save'${NC}"
    echo ""
    
    # Open browser
    if command -v open &> /dev/null; then
        open "$INSTALL_URL"
        log_detail "Opened browser to: $INSTALL_URL"
    elif command -v xdg-open &> /dev/null; then
        xdg-open "$INSTALL_URL"
        log_detail "Opened browser to: $INSTALL_URL"
    else
        echo -e "${YELLOW}Please open this URL in your browser:${NC}"
        echo "$INSTALL_URL"
    fi
    
    echo ""
    read -p "Press Enter after installing the GitHub App..."
    
    # Prompt for installation ID
    read -p "GitHub App Installation ID: " GITHUB_APP_INSTALLATION_ID
    
    # Offer to save installation ID if not already saved
    if [ ! -f "config.local.sh" ] || ! grep -q "^export GITHUB_APP_INSTALLATION_ID=" config.local.sh 2>/dev/null; then
        echo ""
        read -p "Would you like to save the Installation ID to config.local.sh for future runs? (Y/n) " -r
        echo
        if [[ -z "$REPLY" || $REPLY =~ ^[Yy]$ ]]; then
            log_info "Saving Installation ID to config.local.sh..."
            
            # Create or update config.local.sh
            if [ ! -f "config.local.sh" ]; then
                cp config.local.sh.example config.local.sh
                log_detail "Created config.local.sh from example"
            fi
            
            # Remove existing installation ID if it exists
            sed -i.bak '/^export GITHUB_APP_INSTALLATION_ID=/d' config.local.sh 2>/dev/null || true
            sed -i.bak '/^# export GITHUB_APP_INSTALLATION_ID=/d' config.local.sh 2>/dev/null || true
            rm -f config.local.sh.bak
            
            # Append the installation ID
            echo "export GITHUB_APP_INSTALLATION_ID=\"$GITHUB_APP_INSTALLATION_ID\"" >> config.local.sh
            
            log_info "✓ Installation ID saved to config.local.sh"
        else
            log_info "Skipped saving Installation ID"
        fi
    fi
else
    log_info "Using configured GitHub App Installation ID: $GITHUB_APP_INSTALLATION_ID"
fi

# Generate Kubernetes manifests
print_header "Generating Kubernetes Manifests"

# Note: We leave the private key blank in manifests for security
# Users will patch the secrets after applying them

# Generate promoter cluster manifests
log_step "Generating promoter cluster manifests"

# Create single manifests file for promoter cluster
PROMOTER_MANIFESTS="$MANIFESTS_DIR/promoter/all-resources.yaml"

# GitHub App Secret (with empty data, static name for reuse)
cat resource-templates/promoter/github-app-secret.yaml.tpl > "$PROMOTER_MANIFESTS"

echo "---" >> "$PROMOTER_MANIFESTS"

# ClusterScmProvider (static name for reuse)
sed -e "s/{{GITHUB_APP_ID}}/$GITHUB_APP_ID/g" \
    -e "s/{{GITHUB_APP_INSTALLATION_ID}}/$GITHUB_APP_INSTALLATION_ID/g" \
    -e "s|{{GITHUB_DOMAIN}}|$GITHUB_DOMAIN|g" \
    resource-templates/promoter/cluster-scm-provider.yaml.tpl | \
    if [ "$GITHUB_DOMAIN" = "github.com" ]; then
        # Remove domain line for github.com (not allowed by ClusterScmProvider)
        grep -v "domain: github.com"
    else
        cat
    fi >> "$PROMOTER_MANIFESTS"

echo "---" >> "$PROMOTER_MANIFESTS"

# Determine the repo owner (org or authenticated user) - same logic as repo creation
if [ "$GITHUB_ACCOUNT_TYPE" = "org" ]; then
    REPO_OWNER="$GITHUB_ORG"
else
    # For personal accounts, get the authenticated user
    REPO_OWNER=$(GH_HOST="$GITHUB_DOMAIN" gh api user -q .login)
fi

# Generate per-asset manifests
for i in $(seq -f "%04g" 0 $((NUM_ASSETS - 1))); do
    ASSET_ID="$i"
    
    # Promoter namespace
    sed -e "s/{{ASSET_ID}}/$ASSET_ID/g" \
        -e "s/{{TIMESTAMP}}/$TIMESTAMP/g" \
        resource-templates/promoter/promoter-namespace.yaml.tpl \
        >> "$PROMOTER_MANIFESTS"
    
    echo "---" >> "$PROMOTER_MANIFESTS"
    
    # GitRepository
    sed -e "s/{{ASSET_ID}}/$ASSET_ID/g" \
        -e "s|{{REPO_OWNER}}|$REPO_OWNER|g" \
        resource-templates/promoter/git-repository.yaml.tpl \
        >> "$PROMOTER_MANIFESTS"
    
    echo "---" >> "$PROMOTER_MANIFESTS"
    
    # PromotionStrategy
    sed -e "s/{{ASSET_ID}}/$ASSET_ID/g" \
        resource-templates/promoter/promotion-strategy.yaml.tpl \
        >> "$PROMOTER_MANIFESTS"
    
    echo "---" >> "$PROMOTER_MANIFESTS"
    
    # ArgoCDCommitStatus
    sed -e "s/{{ASSET_ID}}/$ASSET_ID/g" \
        resource-templates/promoter/argocd-commit-status.yaml.tpl \
        >> "$PROMOTER_MANIFESTS"
    
    echo "---" >> "$PROMOTER_MANIFESTS"
done

log_info "Generated promoter cluster manifests: $PROMOTER_MANIFESTS"

# Generate Argo CD cluster manifests
log_step "Generating Argo CD cluster manifests"

# Create single manifests file for Argo CD cluster
ARGOCD_MANIFESTS="$MANIFESTS_DIR/argocd/all-resources.yaml"

# Load Test AppProject (for deploying promoter manifests via Argo CD)
# Note: Uses static name "promoter-loadtest" for easy cleanup across runs
sed -e "s|{{LOADTEST_REPO_URL}}|$LOADTEST_REPO_URL|g" \
    -e "s|{{LOADTEST_REPO_ORG}}|$LOADTEST_REPO_ORG|g" \
    -e "s|{{LOADTEST_REPO_NAME}}|$LOADTEST_REPO_NAME|g" \
    -e "s|{{PROMOTER_CLUSTER_URL}}|$PROMOTER_CLUSTER_URL|g" \
    -e "s|{{ARGOCD_NAMESPACE}}|$ARGOCD_NAMESPACE|g" \
    resource-templates/argo/loadtest-appproject.yaml.tpl \
    > "$ARGOCD_MANIFESTS"

echo "---" >> "$ARGOCD_MANIFESTS"

# Load Test Application (deploys promoter manifests from this repo)
# The path contains the timestamp to point to the current run's manifests
sed -e "s/{{TIMESTAMP}}/$TIMESTAMP/g" \
    -e "s|{{LOADTEST_REPO_URL}}|$LOADTEST_REPO_URL|g" \
    -e "s|{{LOADTEST_REPO_ORG}}|$LOADTEST_REPO_ORG|g" \
    -e "s|{{LOADTEST_REPO_NAME}}|$LOADTEST_REPO_NAME|g" \
    -e "s|{{PROMOTER_CLUSTER_URL}}|$PROMOTER_CLUSTER_URL|g" \
    -e "s|{{ARGOCD_NAMESPACE}}|$ARGOCD_NAMESPACE|g" \
    resource-templates/argo/loadtest-app.yaml.tpl \
    >> "$ARGOCD_MANIFESTS"

echo "---" >> "$ARGOCD_MANIFESTS"

for i in $(seq -f "%04g" 0 $((NUM_ASSETS - 1))); do
    ASSET_ID="$i"
    
    # AppProject
    sed -e "s/{{ASSET_ID}}/$ASSET_ID/g" \
        -e "s|{{GITHUB_URL}}|$GITHUB_URL|g" \
        -e "s|{{GITHUB_ORG}}|$GITHUB_ORG|g" \
        -e "s|{{DESTINATION_CLUSTER_URL}}|$DESTINATION_CLUSTER_URL|g" \
        -e "s|{{ARGOCD_NAMESPACE}}|$ARGOCD_NAMESPACE|g" \
        resource-templates/argo/appproject.yaml.tpl \
        >> "$ARGOCD_MANIFESTS"
    
    echo "---" >> "$ARGOCD_MANIFESTS"
    
    # Repo write creds secret
    sed -e "s/{{ASSET_ID}}/$ASSET_ID/g" \
        -e "s|{{GITHUB_URL}}|$GITHUB_URL|g" \
        -e "s|{{GITHUB_ORG}}|$GITHUB_ORG|g" \
        -e "s/{{GITHUB_APP_ID}}/$GITHUB_APP_ID/g" \
        -e "s/{{GITHUB_APP_INSTALLATION_ID}}/$GITHUB_APP_INSTALLATION_ID/g" \
        -e "s|{{ARGOCD_NAMESPACE}}|$ARGOCD_NAMESPACE|g" \
        resource-templates/argo/repo-write-creds-secret.yaml.tpl \
        >> "$ARGOCD_MANIFESTS"
    
    echo "---" >> "$ARGOCD_MANIFESTS"
    
    # Applications (6 per asset: dev/stage/prod x east/west)
    for env in "${ENVIRONMENTS[@]}"; do
        for region in "${REGIONS[@]}"; do
            sed -e "s/{{ASSET_ID}}/$ASSET_ID/g" \
                -e "s/{{ENV}}/$env/g" \
                -e "s/{{REGION}}/$region/g" \
                -e "s|{{GITHUB_URL}}|$GITHUB_URL|g" \
                -e "s|{{GITHUB_ORG}}|$GITHUB_ORG|g" \
                -e "s|{{DESTINATION_CLUSTER_URL}}|$DESTINATION_CLUSTER_URL|g" \
                -e "s|{{ARGOCD_NAMESPACE}}|$ARGOCD_NAMESPACE|g" \
                resource-templates/argo/argocd-app.yaml.tpl \
                >> "$ARGOCD_MANIFESTS"
            
            echo "---" >> "$ARGOCD_MANIFESTS"
        done
    done
done

log_info "Generated Argo CD cluster manifests: $ARGOCD_MANIFESTS"

# Generate destination cluster manifests
log_step "Generating destination cluster manifests"

# Create single manifests file for destination cluster
DESTINATION_MANIFESTS="$MANIFESTS_DIR/destination/all-resources.yaml"

for i in $(seq -f "%04g" 0 $((NUM_ASSETS - 1))); do
    ASSET_ID="$i"
    
    for env in "${ENVIRONMENTS[@]}"; do
        for region in "${REGIONS[@]}"; do
            sed -e "s/{{ASSET_ID}}/$ASSET_ID/g" \
                -e "s/{{ENV}}/$env/g" \
                -e "s/{{REGION}}/$region/g" \
                -e "s/{{TIMESTAMP}}/$TIMESTAMP/g" \
                resource-templates/argo/destination-namespace.yaml.tpl \
                >> "$DESTINATION_MANIFESTS"
            
            echo "---" >> "$DESTINATION_MANIFESTS"
        done
    done
done

log_info "Generated destination cluster manifests: $DESTINATION_MANIFESTS"

# Create summary of what was generated
print_header "Setup Summary"

cat > "$LOGS_DIR/SETUP_SUMMARY.md" << EOF
# Setup Summary - $TIMESTAMP

## Configuration

### Test Parameters
- **Number of Assets:** $NUM_ASSETS
- **Timestamp:** $TIMESTAMP

### GitHub Configuration (Asset Repositories)
- **GitHub Organization/User:** $GITHUB_ORG
- **GitHub URL:** $GITHUB_URL
- **Account Type:** $GITHUB_ACCOUNT_TYPE

### Load Test Repository Configuration
- **Repository:** $LOADTEST_REPO_URL/$LOADTEST_REPO_ORG/$LOADTEST_REPO_NAME
- **Argo CD will deploy promoter manifests from:** runs/$TIMESTAMP/manifests/promoter

### GitHub App Details
- **App Name:** $GITHUB_APP_NAME
- **App ID:** $GITHUB_APP_ID
- **Installation ID:** $GITHUB_APP_INSTALLATION_ID
- **Private Key Path:** $GITHUB_APP_KEY_PATH

## Resources Created

### GitHub Repositories ($((NUM_ASSETS * 2)) total)

EOF

# Add the list of created repos
for repo in "${CREATED_REPOS[@]}"; do
    echo "- $GITHUB_URL/$repo" >> "$LOGS_DIR/SETUP_SUMMARY.md"
done

cat >> "$LOGS_DIR/SETUP_SUMMARY.md" << EOF

### Kubernetes Resources

#### Promoter Cluster
- 1 GitHub App Secret
- 1 ClusterScmProvider
- $NUM_ASSETS Namespaces
- $NUM_ASSETS GitRepository resources
- $NUM_ASSETS PromotionStrategy resources
- $NUM_ASSETS ArgoCDCommitStatus resources

#### Argo CD Cluster
- 1 Load Test AppProject (for deploying promoter manifests)
- 1 Load Test Application (deploys from this repo's runs/$TIMESTAMP/manifests/promoter)
- $NUM_ASSETS Asset AppProjects
- $NUM_ASSETS Asset Repo Credentials Secrets
- $((NUM_ASSETS * 6)) Asset Applications (dev/stg/prd x use2/usw2 per asset)

#### Destination Cluster
- $((NUM_ASSETS * 6)) Namespaces (dev/stage/prod x east/west per asset)

## Manifest Files

Generated manifests are located in: \`$MANIFESTS_DIR/\`

All resources for each cluster are combined into a single file for easy application:

### Promoter Cluster
- \`$MANIFESTS_DIR/promoter/all-resources.yaml\` - Contains GitHub App Secret, ClusterScmProvider, Namespaces, GitRepository, PromotionStrategy, and ArgoCDCommitStatus resources

### Argo CD Cluster
- \`$MANIFESTS_DIR/argocd/all-resources.yaml\` - Contains Load Test AppProject/Application, Asset AppProjects, repository write credential Secrets, and Asset Applications

### Destination Cluster
- \`$MANIFESTS_DIR/destination/all-resources.yaml\` - Contains all destination Namespaces

## Next Steps

Apply the manifests to your clusters using the commands below.

**Important:** The kubectl create command will fail if resources already exist. If you see errors, run the teardown script first to clean up existing resources.
EOF

log_info "Setup summary saved to $LOGS_DIR/SETUP_SUMMARY.md"

# Print next steps
print_header "Setup Complete!"

echo ""
log_info "Generated manifests for:"
echo "  • $((NUM_ASSETS * 2)) GitHub repositories"
echo "  • $NUM_ASSETS GitRepository resources"
echo "  • $NUM_ASSETS PromotionStrategy resources"
echo "  • $NUM_ASSETS ArgoCDCommitStatus resources"
echo "  • $((NUM_ASSETS * 6)) Argo CD Applications"
echo "  • $((NUM_ASSETS * 7)) Kubernetes Namespaces"
echo ""

print_header "Applying Kubernetes Manifests"

echo ""
log_info "Now applying manifests to your clusters..."
echo ""

# Track if we've already attempted cleanup
CLEANUP_ATTEMPTED=false

log_step "Applying manifests to PROMOTER cluster..."
if ! kubectl create -f "$RUN_DIR/manifests/promoter/all-resources.yaml" 2>&1 | tee /tmp/promoter-apply-error.log; then
    log_error "✗ Failed to create promoter resources. They may already exist."
    echo ""
    
    if [ "$CLEANUP_ATTEMPTED" = false ]; then
        read -p "Would you like to run cleanup and try again? (Y/n) " -r
        echo
        if [[ -z "$REPLY" || $REPLY =~ ^[Yy]$ ]]; then
            CLEANUP_ATTEMPTED=true
            log_warn "Running cleanup..."
            
            # Run cleanup for all clusters
            kubectl delete -f "$RUN_DIR/manifests/promoter/all-resources.yaml" --ignore-not-found=true 2>/dev/null || true
            kubectl delete -f "$RUN_DIR/manifests/argocd/all-resources.yaml" --ignore-not-found=true 2>/dev/null || true
            kubectl delete -f "$RUN_DIR/manifests/destination/all-resources.yaml" --ignore-not-found=true 2>/dev/null || true
            
            log_info "Cleanup complete. Retrying..."
            echo ""
            
            # Retry
            log_step "Applying manifests to PROMOTER cluster (retry)..."
            if ! kubectl create -f "$RUN_DIR/manifests/promoter/all-resources.yaml"; then
                log_error "✗ Failed again after cleanup. The issue is not due to existing resources."
                echo ""
                echo "Please investigate the error above and try again manually."
                exit 1
            fi
            log_info "✓ Promoter cluster resources created successfully"
        else
            echo "Run teardown script to clean up manually:"
            echo "  ./teardown.sh runs/$TIMESTAMP"
            echo ""
            exit 1
        fi
    else
        log_error "✗ Failed again after cleanup. The issue is not due to existing resources."
        echo ""
        echo "Please investigate the error above and try again manually."
        exit 1
    fi
else
    log_info "✓ Promoter cluster resources created successfully"
fi

echo ""
log_step "Patching promoter GitHub App secret with private key..."
kubectl create secret generic promoter-github-app-$TIMESTAMP \
  -n promoter-system \
  --from-file=githubAppPrivateKey="$GITHUB_APP_KEY_PATH" \
  --dry-run=client -o yaml | kubectl apply -f -
log_info "✓ Promoter secret patched successfully"

echo ""
log_step "Applying manifests to ARGO CD cluster..."
if ! kubectl create -f "$RUN_DIR/manifests/argocd/all-resources.yaml"; then
    if [ "$CLEANUP_ATTEMPTED" = true ]; then
        log_error "✗ Failed to create Argo CD resources after cleanup."
        echo ""
        echo "Please investigate the error above and try again manually."
        exit 1
    else
        log_error "✗ Failed to create Argo CD resources. This shouldn't happen on first attempt."
        exit 1
    fi
else
    log_info "✓ Argo CD cluster resources created successfully"
fi

echo ""
log_step "Patching Argo CD repo-write-creds secrets with private key..."
for i in $(seq -f "%04g" 0 $((NUM_ASSETS - 1))); do
    kubectl create secret generic promoter-test-$i-repo-write-creds \
      -n $ARGOCD_NAMESPACE \
      --from-literal=type=git \
      --from-literal=url=$GITHUB_URL/$REPO_OWNER/promoter-test-$i-deployment \
      --from-literal=githubAppID="$GITHUB_APP_ID" \
      --from-literal=githubAppInstallationID="$GITHUB_APP_INSTALLATION_ID" \
      --from-file=githubAppPrivateKey="$GITHUB_APP_KEY_PATH" \
      --dry-run=client -o yaml | kubectl label -f - argocd.argoproj.io/secret-type=repository-write --local --dry-run=client -o yaml | kubectl apply -f -
done
log_info "✓ All Argo CD secrets patched successfully"

echo ""
log_step "Applying manifests to DESTINATION cluster..."
if ! kubectl create -f "$RUN_DIR/manifests/destination/all-resources.yaml"; then
    if [ "$CLEANUP_ATTEMPTED" = true ]; then
        log_error "✗ Failed to create destination resources after cleanup."
        echo ""
        echo "Please investigate the error above and try again manually."
        exit 1
    else
        log_error "✗ Failed to create destination resources. This shouldn't happen on first attempt."
        exit 1
    fi
else
    log_info "✓ Destination cluster resources created successfully"
fi

echo ""
log_info "All manifests created successfully!"

print_header "Next Steps"

echo ""
echo -e "${YELLOW}1. Document your test results in:${NC}"
echo -e "   ${CYAN}$RUN_DIR/README.md${NC}"
echo ""

echo -e "${YELLOW}2. After testing, run teardown:${NC}"
echo -e "   ${CYAN}./teardown.sh runs/$TIMESTAMP${NC}"
echo ""

# Prompt user to commit
echo ""
read -p "Would you like to commit the generated test run files now? (Y/n) " -r
echo
if [[ -z "$REPLY" || $REPLY =~ ^[Yy]$ ]]; then
    git add "$RUN_DIR"
    git commit -m "Add setup for load test run $TIMESTAMP with $NUM_ASSETS assets"
    log_info "Changes committed successfully"
else
    log_warn "Remember to commit the generated test run files!"
fi

echo ""
log_info "Setup complete! Review $LOGS_DIR/SETUP_SUMMARY.md for details."
