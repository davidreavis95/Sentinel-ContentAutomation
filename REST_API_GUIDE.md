# REST API Deployment Guide

This guide explains how the REST API deployment approach works and how to use it.

## Overview

The `deploy_rest.py` script replaces the traditional PowerShell/Bash deployment scripts with a Python-based solution that uses Azure REST API directly. This provides:

- **Direct API Integration**: Makes REST API calls to Azure Resource Manager
- **Multiple Authentication Methods**: Supports Azure CLI, Managed Identity, Service Principal, and more
- **Cross-Platform**: Works on Windows, Linux, and macOS with Python 3.8+
- **No CLI Dependency for Deployment**: Only uses Azure CLI for BICEP compilation
- **Production Ready**: Includes error handling, retry logic, and detailed logging

## Architecture

### How It Works

1. **Authentication**: Uses Azure Identity SDK to authenticate with Azure
2. **BICEP Compilation**: Compiles BICEP files to ARM templates using Azure CLI
3. **Resource Group Management**: Creates or verifies resource group via REST API
4. **Deployment**: Deploys ARM template using Azure Resource Manager REST API
5. **Polling**: Monitors deployment progress until completion
6. **Output**: Returns deployment results and outputs

### REST API Endpoints Used

The script uses the following Azure REST API endpoints:

- **Subscription Info**: `GET /subscriptions/{subscriptionId}`
- **Resource Group**: 
  - Check: `GET /subscriptions/{subscriptionId}/resourcegroups/{resourceGroupName}`
  - Create: `PUT /subscriptions/{subscriptionId}/resourcegroups/{resourceGroupName}`
- **Deployment**:
  - Create: `PUT /subscriptions/{subscriptionId}/resourcegroups/{resourceGroupName}/providers/Microsoft.Resources/deployments/{deploymentName}`
  - Status: `GET /subscriptions/{subscriptionId}/resourcegroups/{resourceGroupName}/providers/Microsoft.Resources/deployments/{deploymentName}`
  - What-If: `POST /subscriptions/{subscriptionId}/resourcegroups/{resourceGroupName}/providers/Microsoft.Resources/deployments/{deploymentName}/whatIf`

## Prerequisites

### Required Software

1. **Python 3.8+**: Check with `python3 --version`
2. **Azure CLI**: For BICEP compilation - `az --version`
3. **pip**: Python package manager

### Required Permissions

The authenticated user or service principal needs:
- `Microsoft.Resources/subscriptions/read`
- `Microsoft.Resources/resourceGroups/write`
- `Microsoft.Resources/deployments/*`
- `Microsoft.OperationalInsights/workspaces/*`
- `Microsoft.OperationsManagement/solutions/*`
- `Microsoft.SecurityInsights/*`
- `Microsoft.Insights/workbooks/*`

Typically the **Contributor** role at the subscription or resource group level.

## Installation

### Step 1: Install Python Dependencies

```bash
# Install dependencies
pip install -r requirements.txt

# Or install manually
pip install azure-identity>=1.15.0 requests>=2.31.0
```

### Step 2: Authenticate with Azure

```bash
# Login using Azure CLI (easiest for local development)
az login

# Or set environment variables for service principal
export AZURE_CLIENT_ID="your-client-id"
export AZURE_TENANT_ID="your-tenant-id"
export AZURE_CLIENT_SECRET="your-client-secret"
```

## Usage

### Basic Deployment

```bash
# Deploy to default subscription
python deploy_rest.py -g rg-sentinel-prod -l eastus

# Deploy to specific subscription
python deploy_rest.py -g rg-sentinel-prod -l eastus -s 12345678-1234-1234-1234-123456789012
```

### Advanced Options

```bash
# Use different parameter file
python deploy_rest.py -g rg-sentinel-dev -p parameters.dev.json

# Preview changes (What-If mode)
python deploy_rest.py -g rg-sentinel-prod -w

# Enable verbose logging
python deploy_rest.py -g rg-sentinel-prod -v

# Combine options
python deploy_rest.py -g rg-sentinel-prod -l westus -p parameters.dev.json -v
```

### Command-Line Options

| Option | Short | Description | Default |
|--------|-------|-------------|---------|
| `--resource-group` | `-g` | Azure resource group name | Required |
| `--location` | `-l` | Azure region | `eastus` |
| `--parameter-file` | `-p` | Path to parameter file | `parameters.json` |
| `--subscription-id` | `-s` | Azure subscription ID | Auto-detected |
| `--what-if` | `-w` | Preview changes only | `false` |
| `--verbose` | `-v` | Enable verbose output | `false` |

## Authentication Methods

The script supports multiple authentication methods through Azure Identity SDK:

### 1. Azure CLI (Recommended for Local Development)

```bash
az login
python deploy_rest.py -g rg-sentinel-prod
```

### 2. Managed Identity (Recommended for Azure VMs/Containers)

```bash
# No additional authentication needed when running in Azure
python deploy_rest.py -g rg-sentinel-prod
```

### 3. Service Principal (Recommended for CI/CD)

```bash
export AZURE_CLIENT_ID="app-id"
export AZURE_TENANT_ID="tenant-id"
export AZURE_CLIENT_SECRET="secret"
python deploy_rest.py -g rg-sentinel-prod
```

### 4. Environment Variables

```bash
export AZURE_SUBSCRIPTION_ID="subscription-id"
export AZURE_TENANT_ID="tenant-id"
export AZURE_CLIENT_ID="client-id"
export AZURE_CLIENT_SECRET="client-secret"
python deploy_rest.py -g rg-sentinel-prod
```

## Examples

### Example 1: First-Time Deployment

```bash
# Login to Azure
az login

# Install dependencies
pip install -r requirements.txt

# Deploy Sentinel
python deploy_rest.py -g rg-sentinel-prod -l eastus

# Expected output:
# =====================================
# Sentinel REST API Deployment
# =====================================
# 
# ✓ Using subscription: 12345678-1234-1234-1234-123456789012
# ✓ Authenticated using Azure CLI credentials
# ✓ Subscription: My Subscription (12345678-1234-1234-1234-123456789012)
# ✓ Using parameter file: parameters.json
# 
# Creating resource group: rg-sentinel-prod in eastus
# ✓ Resource group created
# Building BICEP template...
# ✓ BICEP template built successfully
# Starting deployment...
# This may take several minutes...
# Deployment status: Running
# Deployment status: Succeeded
# 
# =====================================
# Deployment completed successfully!
# =====================================
```

### Example 2: Development Environment

```bash
# Deploy to dev environment with different parameters
python deploy_rest.py \
  -g rg-sentinel-dev \
  -l westus2 \
  -p parameters.dev.json
```

### Example 3: Preview Changes

```bash
# See what will be deployed without making changes
python deploy_rest.py -g rg-sentinel-prod -w

# Output shows:
# - Resources that will be created
# - Resources that will be modified
# - Resources that will be deleted
# - Property changes
```

### Example 4: CI/CD Pipeline

```bash
#!/bin/bash
# Azure DevOps or GitHub Actions pipeline script

# Set service principal credentials
export AZURE_CLIENT_ID="${SERVICE_PRINCIPAL_ID}"
export AZURE_TENANT_ID="${TENANT_ID}"
export AZURE_CLIENT_SECRET="${SERVICE_PRINCIPAL_SECRET}"
export AZURE_SUBSCRIPTION_ID="${SUBSCRIPTION_ID}"

# Install dependencies
pip install -r requirements.txt

# Deploy
python deploy_rest.py \
  -g "${RESOURCE_GROUP}" \
  -l "${LOCATION}" \
  -p "${PARAMETER_FILE}" \
  -v
```

## Troubleshooting

### Common Issues

#### Issue: Authentication Failed

```
Error: Authentication failed: Please run 'az login' first
```

**Solution**: Login to Azure CLI or set up service principal credentials

```bash
az login
# OR
export AZURE_CLIENT_ID="..."
export AZURE_TENANT_ID="..."
export AZURE_CLIENT_SECRET="..."
```

#### Issue: BICEP Compilation Failed

```
Error: Failed to build BICEP template
```

**Solution**: Update Azure CLI and Bicep

```bash
az upgrade
az bicep upgrade
```

#### Issue: Deployment Timeout

```
Error: Deployment timed out after 1800 seconds
```

**Solution**: This is rare but can happen with large deployments. Check Azure Portal for deployment status:
1. Navigate to Resource Group
2. Click "Deployments" in the left menu
3. Check the status of your deployment

#### Issue: Permission Denied

```
Error: The client '...' does not have authorization
```

**Solution**: Ensure you have the required permissions. Add Contributor role:

```bash
az role assignment create \
  --assignee user@domain.com \
  --role Contributor \
  --scope /subscriptions/{subscription-id}/resourceGroups/{resource-group}
```

#### Issue: Parameter File Not Found

```
Error: Parameter file not found: parameters.json
```

**Solution**: Ensure you're in the correct directory or specify the full path:

```bash
python deploy_rest.py -g rg-sentinel-prod -p /path/to/parameters.json
```

### Verbose Mode

Enable verbose mode to see detailed information about API calls:

```bash
python deploy_rest.py -g rg-sentinel-prod -v
```

This will show:
- Authentication details
- API request/response information
- Deployment progress
- Error details

## Advanced Usage

### Custom Scripts

You can import and use the `AzureRestDeployer` class in your own scripts:

```python
from deploy_rest import AzureRestDeployer, load_parameters
from pathlib import Path

# Initialize deployer
deployer = AzureRestDeployer(subscription_id="your-sub-id", verbose=True)

# Authenticate
if deployer.authenticate():
    # Load parameters
    params = load_parameters(Path("parameters.json"))
    
    # Compile BICEP
    template = deployer.compile_bicep(Path("main.bicep"))
    
    # Deploy
    result = deployer.deploy_template(
        "rg-sentinel-prod",
        "my-deployment",
        template,
        {k: {"value": v} for k, v in params.items()}
    )
```

### Integration with Other Tools

#### GitHub Actions

```yaml
name: Deploy Sentinel
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      
      - name: Install dependencies
        run: pip install -r requirements.txt
      
      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Deploy Sentinel
        run: |
          python deploy_rest.py \
            -g ${{ vars.RESOURCE_GROUP }} \
            -l ${{ vars.LOCATION }} \
            -v
```

#### Azure DevOps

```yaml
trigger:
  branches:
    include:
      - main

pool:
  vmImage: 'ubuntu-latest'

steps:
  - task: UsePythonVersion@0
    inputs:
      versionSpec: '3.11'
  
  - script: pip install -r requirements.txt
    displayName: 'Install dependencies'
  
  - task: AzureCLI@2
    inputs:
      azureSubscription: 'Your-Service-Connection'
      scriptType: 'bash'
      scriptLocation: 'inlineScript'
      inlineScript: |
        python deploy_rest.py \
          -g $(resourceGroup) \
          -l $(location) \
          -v
    displayName: 'Deploy Sentinel'
```

## REST API vs Azure CLI

### Why REST API?

| Feature | REST API | Azure CLI |
|---------|----------|-----------|
| **Flexibility** | Full control over requests | Limited to CLI commands |
| **Authentication** | Multiple methods | Mainly interactive login |
| **Error Handling** | Custom error handling | Generic CLI errors |
| **Performance** | Direct API calls | CLI overhead |
| **Customization** | Highly customizable | Limited |
| **Dependencies** | Minimal (Python + requests) | Full Azure CLI |
| **CI/CD** | Better for automation | Requires CLI in container |
| **Debugging** | Detailed API responses | CLI output parsing |

### When to Use Each

**Use REST API when:**
- Running in CI/CD pipelines
- Need fine-grained control
- Want minimal dependencies
- Building custom automation
- Need specific API features

**Use Azure CLI when:**
- Interactive deployments
- Quick testing
- Learning Azure
- CLI is already installed
- Simple one-off deployments

## Security Best Practices

1. **Use Managed Identity in Azure**: Avoid storing credentials
2. **Rotate Service Principal Secrets**: Update regularly
3. **Use Key Vault**: Store secrets securely
4. **Principle of Least Privilege**: Grant minimum required permissions
5. **Audit Deployments**: Enable logging and monitoring
6. **Secure Parameter Files**: Don't commit secrets to git
7. **Use Azure Private Link**: For network security

## Performance Optimization

1. **Parallel Deployments**: Deploy to multiple resource groups simultaneously
2. **Resource Quotas**: Check limits before deployment
3. **Template Size**: Keep templates under 4MB
4. **Timeout Settings**: Adjust based on deployment size
5. **Incremental Mode**: Use for faster updates

## Support

For issues or questions:
- Review this documentation
- Check the troubleshooting section
- Review Azure REST API documentation
- Open an issue in the repository

## References

- [Azure REST API Documentation](https://docs.microsoft.com/rest/api/azure/)
- [Azure Identity SDK](https://docs.microsoft.com/python/api/azure-identity/)
- [Azure Resource Manager](https://docs.microsoft.com/azure/azure-resource-manager/)
- [Bicep Documentation](https://docs.microsoft.com/azure/azure-resource-manager/bicep/)
