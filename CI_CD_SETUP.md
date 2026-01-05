# CI/CD Setup Guide for Azure Sentinel

This guide explains how to set up and use the GitHub Actions workflows for automated validation and deployment of Microsoft Sentinel.

## Table of Contents

- [Overview](#overview)
- [GitHub Secrets Configuration](#github-secrets-configuration)
- [Available Workflows](#available-workflows)
- [Environment Configuration](#environment-configuration)
- [Workflow Usage](#workflow-usage)
- [Troubleshooting](#troubleshooting)

## Overview

This repository includes three GitHub Actions workflows:

1. **Validate** (`validate.yml`) - Validates Bicep templates and Python scripts on every PR and push
2. **Deploy** (`deploy.yml`) - Automates deployment to Azure environments
3. **CodeQL** (`codeql.yml`) - Security scanning for Python code

## GitHub Secrets Configuration

### Required Secrets

Configure the following secrets in your GitHub repository (Settings → Secrets and variables → Actions):

#### 1. AZURE_CREDENTIALS

Service Principal credentials for Azure authentication. Create using:

```bash
# Create a service principal
az ad sp create-for-rbac \
  --name "github-sentinel-deployer" \
  --role "Contributor" \
  --scopes /subscriptions/{subscription-id}/resourceGroups/{resource-group} \
  --sdk-auth
```

The output should be added as the `AZURE_CREDENTIALS` secret:

```json
{
  "clientId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "clientSecret": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "subscriptionId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "tenantId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "activeDirectoryEndpointUrl": "https://login.microsoftonline.com",
  "resourceManagerEndpointUrl": "https://management.azure.com/",
  "activeDirectoryGraphResourceId": "https://graph.windows.net/",
  "sqlManagementEndpointUrl": "https://management.core.windows.net:8443/",
  "galleryEndpointUrl": "https://gallery.azure.com/",
  "managementEndpointUrl": "https://management.core.windows.net/"
}
```

#### 2. DEV_RESOURCE_GROUP (Optional)

Resource group name for development deployments. If not set, defaults to `rg-sentinel-dev`.

```
rg-sentinel-dev
```

#### 3. DEV_LOCATION (Optional)

Azure region for development deployments. If not set, defaults to `eastus`.

```
eastus
```

#### 4. AZURE_RG_NAME (Optional)

Resource group name for what-if validation in PRs.

```
rg-sentinel-ci
```

### Assigning Required Permissions

The Service Principal needs the following permissions:

```bash
# Assign Sentinel Contributor role
az role assignment create \
  --assignee {service-principal-client-id} \
  --role "Microsoft Sentinel Contributor" \
  --scope /subscriptions/{subscription-id}/resourceGroups/{resource-group}

# Assign Log Analytics Contributor role
az role assignment create \
  --assignee {service-principal-client-id} \
  --role "Log Analytics Contributor" \
  --scope /subscriptions/{subscription-id}/resourceGroups/{resource-group}
```

## Available Workflows

### 1. Validate Workflow

**File:** `.github/workflows/validate.yml`

**Triggers:**
- Pull requests to `main` or `develop` branches
- Pushes to `main` or `develop` branches
- Manual trigger via workflow_dispatch

**What it does:**
- Lints and builds all Bicep templates
- Validates JSON parameter files
- Checks Python syntax
- Lints Python code with pylint
- Runs what-if deployment (on PRs, if credentials are configured)

**Jobs:**
1. `validate-bicep` - Validates all Bicep templates
2. `validate-python` - Validates Python deployment script
3. `validate-deployment` - Runs Azure what-if (PRs only)

### 2. Deploy Workflow

**File:** `.github/workflows/deploy.yml`

**Triggers:**
- Push to `main` branch (deploys to development)
- Manual trigger via workflow_dispatch (choose environment)

**What it does:**
- Deploys Sentinel to Azure using the Python REST API script
- Supports development and production environments
- Creates resource groups automatically
- Validates templates before deployment
- Outputs deployment information

**Jobs:**
1. `deploy-development` - Deploys to development environment
2. `deploy-production` - Deploys to production environment (manual only)

**Environments:**
- `development` - Automated deployment on push to main
- `production` - Manual deployment with approval (configure in GitHub)

### 3. CodeQL Workflow

**File:** `.github/workflows/codeql.yml`

**Triggers:**
- Push to `main` or `develop` branches
- Pull requests to `main` or `develop` branches
- Weekly schedule (Mondays at 9:00 AM UTC)
- Manual trigger via workflow_dispatch

**What it does:**
- Scans Python code for security vulnerabilities
- Analyzes code quality
- Creates security alerts if issues are found

## Environment Configuration

### GitHub Environments

Configure protected environments in GitHub (Settings → Environments):

#### Development Environment

- **Name:** `development`
- **Deployment branches:** `main`, `develop`
- **Required reviewers:** None (optional)
- **Environment secrets:** None required (uses repository secrets)

#### Production Environment

- **Name:** `production`
- **Deployment branches:** `main` only
- **Required reviewers:** Add team members who must approve production deployments
- **Wait timer:** Optional (e.g., 5 minutes)
- **Environment secrets:** 
  - `PROD_RESOURCE_GROUP` (optional, if different from workflow input)
  - `PROD_LOCATION` (optional)

### Parameter Files

The workflows use different parameter files for each environment:

- **CI/Testing:** `.github/parameters.ci.json` - Minimal configuration for testing
- **Development:** `parameters.dev.json` - 30-day retention, 1GB quota
- **Production:** `parameters.json` - 90-day retention, unlimited quota

## Workflow Usage

### Automated Validation

Validation runs automatically on every pull request:

```bash
# Create a feature branch
git checkout -b feature/new-rule

# Make changes to Bicep files
vi modules/analyticalRules.bicep

# Commit and push
git add .
git commit -m "Add new analytical rule"
git push origin feature/new-rule

# Create PR - validation workflow runs automatically
```

### Automated Development Deployment

Deployments to development happen automatically when you push to `main`:

```bash
# Merge your PR to main
git checkout main
git pull

# The deploy workflow runs automatically
# Check the Actions tab in GitHub to monitor progress
```

### Manual Production Deployment

Deploy to production using workflow_dispatch:

1. Go to **Actions** tab in GitHub
2. Select **Deploy to Azure Sentinel** workflow
3. Click **Run workflow**
4. Fill in the form:
   - **Environment:** production
   - **Resource Group:** rg-sentinel-prod
   - **Location:** eastus (or your preferred region)
5. Click **Run workflow**
6. If configured, approve the deployment in the Environments section

### Manual Validation

You can manually trigger validation:

1. Go to **Actions** tab in GitHub
2. Select **Validate Bicep Templates** workflow
3. Click **Run workflow**
4. Select branch
5. Click **Run workflow**

## Workflow Details

### Validate Workflow Steps

```yaml
validate-bicep:
  - Checkout code
  - Setup Azure CLI
  - Install Bicep CLI
  - Lint main.bicep
  - Build main.bicep
  - Lint all module files
  - Build all module files
  - Validate parameter JSON files
  - Upload build artifacts

validate-python:
  - Checkout code
  - Setup Python 3.11
  - Install dependencies
  - Check Python syntax
  - Lint with pylint

validate-deployment:
  - Checkout code
  - Azure Login
  - Run what-if deployment
```

### Deploy Workflow Steps

```yaml
deploy-development:
  - Checkout code
  - Setup Python 3.11
  - Install dependencies
  - Azure Login
  - Install Bicep CLI
  - Set deployment variables
  - Create Resource Group
  - Validate Bicep template
  - Deploy using Python script
  - Get deployment outputs
  - Create step summary

deploy-production:
  - [Same as development, plus:]
  - Run what-if preview
  - Create deployment tag
```

## Advanced Configuration

### Custom Deployment Script

You can customize the deployment by modifying environment variables:

```yaml
- name: Deploy with custom settings
  run: |
    python deploy_rest.py \
      --resource-group ${{ env.RESOURCE_GROUP }} \
      --location ${{ env.LOCATION }} \
      --parameter-file ${{ env.PARAM_FILE }} \
      --verbose
```

### Matrix Builds for Multiple Regions

Deploy to multiple regions in parallel:

```yaml
strategy:
  matrix:
    location: [eastus, westus, northeurope]
    
steps:
  - name: Deploy to ${{ matrix.location }}
    run: |
      python deploy_rest.py \
        --resource-group rg-sentinel-${{ matrix.location }} \
        --location ${{ matrix.location }}
```

### Slack/Teams Notifications

Add notification steps:

```yaml
- name: Notify on success
  if: success()
  run: |
    curl -X POST ${{ secrets.SLACK_WEBHOOK_URL }} \
      -H 'Content-Type: application/json' \
      -d '{"text":"Sentinel deployment succeeded!"}'
```

## Troubleshooting

### Common Issues

#### 1. Authentication Failed

**Error:** `Azure Login failed`

**Solution:**
- Verify `AZURE_CREDENTIALS` secret is correctly configured
- Ensure Service Principal has not expired
- Check Service Principal has correct permissions

```bash
# Test service principal
az login --service-principal \
  --username {clientId} \
  --password {clientSecret} \
  --tenant {tenantId}
```

#### 2. Bicep Build Failed

**Error:** `az bicep build failed`

**Solution:**
- Check Bicep syntax in the file
- Ensure all referenced modules exist
- Validate parameter types match template

```bash
# Test locally
az bicep build --file main.bicep
```

#### 3. Deployment Failed

**Error:** `Deployment to Azure failed`

**Solution:**
- Check resource group exists or can be created
- Verify subscription has sufficient quota
- Review deployment logs in Azure Portal
- Check parameter values are valid

```bash
# Check deployment status
az deployment group show \
  --resource-group rg-sentinel-dev \
  --name {deployment-name}
```

#### 4. What-If Fails in PR

**Error:** `What-if deployment failed`

**Solution:**
- This is set to `continue-on-error: true`, so it won't block PRs
- Ensure `AZURE_RG_NAME` secret is set
- Resource group must exist for what-if to work
- If not critical, you can ignore this error

### Debug Mode

Enable debug logging in workflows:

```yaml
- name: Deploy with debug
  run: |
    python deploy_rest.py \
      --resource-group $RESOURCE_GROUP \
      --location $LOCATION \
      --parameter-file $PARAM_FILE \
      --verbose
  env:
    ACTIONS_STEP_DEBUG: true
```

### Viewing Logs

1. Go to **Actions** tab in GitHub
2. Click on the workflow run
3. Click on the job
4. Expand each step to see detailed logs
5. Download logs using "Download log archive" button

## Security Best Practices

1. **Use GitHub Environments** for production deployments with required reviewers
2. **Rotate Service Principal secrets** regularly
3. **Use branch protection rules** to require PR reviews
4. **Enable CodeQL scanning** to catch security issues
5. **Use least privilege** - grant only necessary permissions to Service Principal
6. **Store secrets securely** - never commit credentials to code
7. **Review workflow logs** for sensitive information before sharing

## Monitoring Deployments

### GitHub Actions Dashboard

Monitor all workflow runs in the Actions tab:
- Success/failure status
- Duration
- Logs
- Artifacts

### Azure Portal

After deployment, verify in Azure:
1. Go to Resource Groups → [Your RG]
2. Click on Deployments
3. Review deployment details
4. Check Microsoft Sentinel workspace

### Deployment Outputs

Workflows create job summaries with:
- Workspace Name
- Workspace ID
- Resource Group
- Location

View in the workflow run summary.

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Azure Sentinel CI/CD](https://learn.microsoft.com/en-us/azure/sentinel/ci-cd)
- [Azure Login Action](https://github.com/Azure/login)
- [Bicep Documentation](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/)

## Support

For issues with workflows:
1. Check this troubleshooting guide
2. Review workflow logs
3. Check Azure deployment logs
4. Open an issue in this repository

---

**Last Updated:** 2026-01-05
