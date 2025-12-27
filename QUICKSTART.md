# Quick Start Deployment Guide

This guide provides quick commands to deploy Microsoft Sentinel using the automation in this repository.

## Prerequisites Checklist

- [ ] Azure subscription with active access
- [ ] Azure CLI installed and updated
- [ ] Python 3.8+ installed
- [ ] Appropriate Azure permissions (Sentinel Contributor or higher)
- [ ] Logged in to Azure (`az login`)

## Deployment Options

### Option 1: Quick Deploy (PowerShell)

```powershell
# Login to Azure
az login

# Set your subscription (if you have multiple)
az account set --subscription "Your-Subscription-Name-Or-ID"

# Deploy Sentinel
.\deploy.ps1 -ResourceGroupName "rg-sentinel-prod" -Location "eastus"
```

### Option 2: Quick Deploy (Bash)

```bash
# Login to Azure
az login

# Set your subscription (if you have multiple)
az account set --subscription "Your-Subscription-Name-Or-ID"

# Deploy Sentinel
./deploy.sh -g rg-sentinel-prod -l eastus
```

### Option 3: Manual Azure CLI

```bash
# Login to Azure
az login

# Create resource group
az group create --name rg-sentinel-prod --location eastus

# Deploy using Bicep
az deployment group create \
  --name sentinel-deployment \
  --resource-group rg-sentinel-prod \
  --template-file main.bicep \
  --parameters @parameters.json
```

## Customization Before Deployment

### 1. Edit Parameters File

Open `parameters.json` and modify:

```json
{
  "workspaceName": { "value": "YOUR-WORKSPACE-NAME" },
  "location": { "value": "YOUR-REGION" },
  "dataRetention": { "value": 90 }
}
```

### 2. Choose What to Deploy

Set `false` to skip any content type:

```json
{
  "deployAnalyticalRules": { "value": true },
  "deployParsers": { "value": true },
  "deployWorkbooks": { "value": true },
  "deployHuntingQueries": { "value": true },
  "deployWatchlists": { "value": true }
}
```

## Deployment Validation

### Preview Changes (What-If)

```bash
# REST API deployment
python deploy_rest.py -g rg-sentinel-prod -w
```

```bash
# Azure CLI
az deployment group what-if \
  --resource-group rg-sentinel-prod \
  --template-file main.bicep \
  --parameters @parameters.json
```

### Verify Deployment

```bash
# Check workspace exists
az monitor log-analytics workspace show \
  --resource-group rg-sentinel-prod \
  --workspace-name sentinel-workspace-prod

# List Sentinel alert rules
az sentinel alert-rule list \
  --resource-group rg-sentinel-prod \
  --workspace-name sentinel-workspace-prod
```

## Post-Deployment Steps

### 1. Configure Data Connectors

```bash
# Navigate to Azure Portal
# Sentinel → Configuration → Data connectors
# Enable connectors for your data sources
```

### 2. Verify Content Deployment

- **Analytical Rules**: Sentinel → Analytics → Rule templates
- **Workbooks**: Sentinel → Workbooks
- **Hunting Queries**: Sentinel → Hunting
- **Watchlists**: Sentinel → Watchlists

### 3. Set Up Automation (Optional)

```bash
# Create an automation rule example
az sentinel automation-rule create \
  --resource-group rg-sentinel-prod \
  --workspace-name sentinel-workspace-prod \
  --automation-rule-name "auto-assign-incidents" \
  --order 1 \
  --triggering-logic @automation-rule.json
```

## Troubleshooting

### Common Issues and Solutions

**Error: Unauthorized**
```bash
# Ensure you have the right permissions
az role assignment create \
  --assignee YOUR-USER@DOMAIN.COM \
  --role "Azure Sentinel Contributor" \
  --scope /subscriptions/SUBSCRIPTION-ID/resourceGroups/rg-sentinel-prod
```

**Error: Workspace name already exists**
- Change the `workspaceName` parameter to a unique value

**Error: Bicep build failed**
```bash
# Update Azure CLI
az upgrade
```

**Deployment takes too long**
- This is normal. Sentinel deployment can take 5-15 minutes
- Check progress in Azure Portal → Resource Group → Deployments

## Resource URLs

After deployment, access your resources:

- **Azure Portal**: https://portal.azure.com
- **Sentinel Workspace**: Portal → Search for workspace name → Microsoft Sentinel
- **Log Analytics**: Portal → Log Analytics workspaces → Your workspace

## Cost Estimation

Approximate costs (varies by region and usage):

- **Log Analytics**: ~$2.30 per GB ingested
- **Sentinel**: ~$2.00 per GB ingested (on top of Log Analytics)
- **Storage**: ~$0.10 per GB per month for retained data

**Cost Control Tips:**
- Set `dailyQuotaGb` in parameters to limit ingestion
- Use `dataRetention: 30` for development environments
- Monitor usage regularly in Cost Management

## Next Steps

1. Configure data connectors for your environment
2. Review and customize analytical rules
3. Set up incident response playbooks
4. Configure notifications and teams integration
5. Create custom workbooks for your use cases
6. Set up RBAC for your team members

## Support Resources

- [Microsoft Sentinel Documentation](https://docs.microsoft.com/azure/sentinel/)
- [Azure Bicep Documentation](https://docs.microsoft.com/azure/azure-resource-manager/bicep/)
- [KQL Query Language Reference](https://docs.microsoft.com/azure/data-explorer/kusto/query/)

## Clean Up Resources

To remove all deployed resources:

```bash
# Delete the entire resource group (BE CAREFUL!)
az group delete --name rg-sentinel-prod --yes --no-wait
```

---

**Tip**: Always test in a development environment before deploying to production!
