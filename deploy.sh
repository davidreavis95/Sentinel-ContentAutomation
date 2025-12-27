#!/bin/bash
#
# Deploy Microsoft Sentinel and all content types using Bicep
#
# This script deploys Microsoft Sentinel workspace and associated content including:
# - Analytical Rules
# - Parsers
# - Workbooks
# - Hunting Queries (Advanced Hunting)
# - Watchlists
#
# Usage:
#   ./deploy.sh -g <resource-group> -l <location> [-p <parameter-file>] [-w]
#
# Options:
#   -g    Resource group name (required)
#   -l    Azure location (default: eastus)
#   -p    Parameter file path (default: parameters.json)
#   -w    Run in what-if mode (preview changes)
#   -h    Show this help message

set -e

# Default values
LOCATION="eastus"
PARAMETER_FILE="parameters.json"
WHAT_IF=false

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to display usage
usage() {
    grep '^#' "$0" | tail -n +2 | head -n -1 | cut -c 3-
    exit 0
}

# Function to print colored output
print_info() {
    echo -e "${CYAN}$1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}$1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Parse command line arguments
while getopts "g:l:p:wh" opt; do
    case $opt in
        g) RESOURCE_GROUP="$OPTARG" ;;
        l) LOCATION="$OPTARG" ;;
        p) PARAMETER_FILE="$OPTARG" ;;
        w) WHAT_IF=true ;;
        h) usage ;;
        \?) print_error "Invalid option: -$OPTARG"; usage ;;
    esac
done

# Validate required parameters
if [ -z "$RESOURCE_GROUP" ]; then
    print_error "Resource group name is required"
    usage
fi

echo ""
print_info "====================================="
print_info "Sentinel Deployment Script"
print_info "====================================="
echo ""

# Check if Azure CLI is installed
print_warning "Checking Azure CLI installation..."
if ! command -v az &> /dev/null; then
    print_error "Azure CLI is not installed. Please install it from https://docs.microsoft.com/cli/azure/install-azure-cli"
    exit 1
fi
AZ_VERSION=$(az version --query '\"azure-cli\"' -o tsv)
print_success "Azure CLI version: $AZ_VERSION"

# Check if logged in to Azure
print_warning "Checking Azure login status..."
ACCOUNT_INFO=$(az account show 2>&1) || {
    print_error "Not logged in to Azure. Please run 'az login' first."
    exit 1
}
ACCOUNT_NAME=$(echo "$ACCOUNT_INFO" | jq -r '.user.name')
SUBSCRIPTION_NAME=$(echo "$ACCOUNT_INFO" | jq -r '.name')
SUBSCRIPTION_ID=$(echo "$ACCOUNT_INFO" | jq -r '.id')
print_success "Logged in as: $ACCOUNT_NAME"
print_success "Subscription: $SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)"

# Verify parameter file exists
if [ ! -f "$PARAMETER_FILE" ]; then
    print_error "Parameter file not found: $PARAMETER_FILE"
    exit 1
fi
print_success "Using parameter file: $PARAMETER_FILE"

# Check if resource group exists
echo ""
print_warning "Checking resource group..."
if ! az group exists --name "$RESOURCE_GROUP" --output none 2>&1 | grep -q "true"; then
    print_warning "Creating resource group: $RESOURCE_GROUP in $LOCATION"
    az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output none
    print_success "Resource group created"
else
    print_success "Resource group exists: $RESOURCE_GROUP"
fi

# Build Bicep file
echo ""
print_warning "Building Bicep template..."
az bicep build --file main.bicep
print_success "Bicep template built successfully"

# Deploy or validate
echo ""
if [ "$WHAT_IF" = true ]; then
    print_warning "Running deployment validation (What-If)..."
    az deployment group what-if \
        --resource-group "$RESOURCE_GROUP" \
        --template-file main.bicep \
        --parameters "@$PARAMETER_FILE"
else
    print_warning "Starting deployment..."
    print_warning "This may take several minutes..."
    
    DEPLOYMENT_NAME="sentinel-deployment-$(date +%Y%m%d-%H%M%S)"
    
    az deployment group create \
        --name "$DEPLOYMENT_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --template-file main.bicep \
        --parameters "@$PARAMETER_FILE" \
        --verbose
    
    echo ""
    print_info "====================================="
    print_success "Deployment completed successfully!"
    print_info "====================================="
    echo ""
    
    # Get deployment outputs
    print_info "Deployment outputs:"
    az deployment group show \
        --name "$DEPLOYMENT_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query properties.outputs \
        --output table
fi

echo ""
print_info "Next steps:"
echo "1. Configure data connectors in the Azure Portal"
echo "2. Review and customize analytical rules"
echo "3. Configure automation rules and playbooks"
echo "4. Set up RBAC permissions for your team"
echo ""
