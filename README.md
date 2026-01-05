# Microsoft Sentinel Content Automation

[![Validate Bicep Templates](https://github.com/davidreavis95/Sentinel-ContentAutomation/workflows/Validate%20Bicep%20Templates/badge.svg)](https://github.com/davidreavis95/Sentinel-ContentAutomation/actions/workflows/validate.yml)
[![Deploy to Azure Sentinel](https://github.com/davidreavis95/Sentinel-ContentAutomation/workflows/Deploy%20to%20Azure%20Sentinel/badge.svg)](https://github.com/davidreavis95/Sentinel-ContentAutomation/actions/workflows/deploy.yml)
[![CodeQL Security Scanning](https://github.com/davidreavis95/Sentinel-ContentAutomation/workflows/CodeQL%20Security%20Scanning/badge.svg)](https://github.com/davidreavis95/Sentinel-ContentAutomation/actions/workflows/codeql.yml)

This repository provides Infrastructure-as-Code (IaC) using Azure Bicep to automatically deploy Microsoft Sentinel and all associated content types including Analytical Rules, Parsers, Workbooks, Advanced Hunting Queries, and Watchlists.

## 🚀 Features

- **Automated Deployment**: Deploy Microsoft Sentinel workspace with a single command
- **CI/CD Integration**: GitHub Actions workflows for automated validation and deployment
- **Comprehensive Content Types**:
  - ✅ Analytical Rules (Scheduled query-based alerts)
  - ✅ Parsers (KQL functions for data normalization)
  - ✅ Workbooks (Interactive security dashboards)
  - ✅ Hunting Queries (Advanced threat hunting queries)
  - ✅ Watchlists (Reference data for enrichment)
- **Bicep-Based**: Modern, type-safe Infrastructure as Code
- **Modular Architecture**: Easily customize or extend content
- **Multiple Environments**: Separate parameter files for dev/prod
- **REST API Deployment**: Direct Azure REST API integration for deployment automation
- **Security Scanning**: Automated CodeQL security analysis

## 📋 Prerequisites

Before deploying, ensure you have:

1. **Azure Subscription** with appropriate permissions
2. **Azure CLI** installed ([Install Guide](https://docs.microsoft.com/cli/azure/install-azure-cli))
3. **Bicep CLI** (automatically installed with Azure CLI 2.20.0+)
4. **Python 3.8+** for REST API deployment script

### Required Azure Permissions

The deploying user/service principal needs:
- `Microsoft.OperationalInsights/workspaces/*` (Log Analytics)
- `Microsoft.OperationsManagement/solutions/*` (Solutions)
- `Microsoft.SecurityInsights/*` (Sentinel)
- `Microsoft.Insights/workbooks/*` (Workbooks)
- Typically the **Sentinel Contributor** role or higher

## 🏗️ Repository Structure

```
.
├── .github/
│   ├── workflows/               # GitHub Actions workflows
│   │   ├── validate.yml         # Template validation workflow
│   │   ├── deploy.yml           # Deployment workflow
│   │   └── codeql.yml           # Security scanning workflow
│   └── parameters.ci.json       # CI/CD parameters
├── main.bicep                   # Main Bicep template
├── modules/                     # Bicep modules for each content type
│   ├── analyticalRules.bicep    # Alert rules configuration
│   ├── parsers.bicep            # KQL parser functions
│   ├── workbooks.bicep          # Security dashboards
│   ├── huntingQueries.bicep     # Threat hunting queries
│   └── watchlists.bicep         # Reference data lists
├── parameters.json              # Production parameters
├── parameters.dev.json          # Development parameters
├── deploy_rest.py               # REST API deployment script
├── requirements.txt             # Python dependencies
├── CI_CD_SETUP.md               # CI/CD configuration guide
└── README.md                    # This file
```

## 🎯 Quick Start

### Option 1: GitHub Actions CI/CD (Recommended for Teams)

For automated deployments with validation and security scanning:

1. **Fork or clone this repository**
2. **Configure GitHub Secrets** (see [CI/CD Setup Guide](CI_CD_SETUP.md))
3. **Push to main branch** - automatic deployment to development
4. **Manual production deployment** - use workflow_dispatch

See [CI_CD_SETUP.md](CI_CD_SETUP.md) for detailed setup instructions.

### Option 2: REST API Deployment (Recommended for Manual Deployment)

```bash
# Login to Azure
az login

# Install Python dependencies
pip install -r requirements.txt

# Deploy to production
python deploy_rest.py -g rg-sentinel-prod -l eastus

# Deploy to development
python deploy_rest.py -g rg-sentinel-dev -p parameters.dev.json

# Preview changes (What-If mode)
python deploy_rest.py -g rg-sentinel-prod -w

# Specify subscription explicitly
python deploy_rest.py -g rg-sentinel-prod -s 12345678-1234-1234-1234-123456789012
```

### Option 3: Azure CLI Direct

```bash
# Login to Azure
az login

# Create resource group
az group create --name rg-sentinel-prod --location eastus

# Build Bicep template
az bicep build --file main.bicep

# Deploy
az deployment group create \
  --name sentinel-deployment \
  --resource-group rg-sentinel-prod \
  --template-file main.bicep \
  --parameters @parameters.json
```

## 🔄 CI/CD Integration

This repository includes GitHub Actions workflows for automated validation and deployment:

### Workflows

1. **Validate** - Runs on every PR and push
   - Validates Bicep templates
   - Checks Python syntax
   - Runs what-if deployment preview
   
2. **Deploy** - Automated deployment
   - Development: Automatic on push to main
   - Production: Manual with approval
   
3. **CodeQL** - Security scanning
   - Weekly scans
   - Pull request analysis

### Quick Setup

```bash
# 1. Create Service Principal
az ad sp create-for-rbac --name "github-sentinel" --role "Contributor" --sdk-auth

# 2. Add as AZURE_CREDENTIALS secret in GitHub

# 3. Push to main - automatic validation and deployment!
```

**Full CI/CD setup guide:** [CI_CD_SETUP.md](CI_CD_SETUP.md)

## 🔧 REST API Deployment

The `deploy_rest.py` script uses Azure REST API directly instead of Azure CLI for deployment operations. This provides:

- **Direct API Integration**: Makes REST API calls to Azure Resource Manager
- **Flexible Authentication**: Supports Azure CLI, Managed Identity, Service Principal, Environment Variables
- **Production Ready**: Includes error handling, polling, and detailed logging
- **CI/CD Friendly**: Minimal dependencies and better suited for automation

For detailed information about the REST API deployment approach, see [REST_API_GUIDE.md](REST_API_GUIDE.md).

### Authentication Methods

The script automatically detects and uses available credentials in this order:
1. Azure CLI credentials (from `az login`)
2. Managed Identity (when running in Azure)
3. Service Principal (from environment variables)
4. Other Azure Identity methods

## ⚙️ Configuration

### Parameters

Customize your deployment by editing the parameter files:

| Parameter | Description | Default | Options |
|-----------|-------------|---------|---------|
| `workspaceName` | Log Analytics workspace name | - | Unique name |
| `location` | Azure region | `eastus` | Any Azure region |
| `workspaceSku` | Pricing tier | `PerGB2018` | `PerGB2018`, `Free`, etc. |
| `dataRetention` | Data retention in days | `90` | 30-730 |
| `dailyQuotaGb` | Daily ingestion limit (GB) | `-1` (unlimited) | -1 or positive number |
| `deployAnalyticalRules` | Deploy alert rules | `true` | `true`/`false` |
| `deployParsers` | Deploy KQL parsers | `true` | `true`/`false` |
| `deployWorkbooks` | Deploy workbooks | `true` | `true`/`false` |
| `deployHuntingQueries` | Deploy hunting queries | `true` | `true`/`false` |
| `deployWatchlists` | Deploy watchlists | `true` | `true`/`false` |
| `tags` | Resource tags | `{}` | Key-value pairs |

### Example: Production Configuration

```json
{
  "workspaceName": { "value": "sentinel-workspace-prod" },
  "location": { "value": "eastus" },
  "workspaceSku": { "value": "PerGB2018" },
  "dataRetention": { "value": 90 },
  "dailyQuotaGb": { "value": -1 },
  "deployAnalyticalRules": { "value": true },
  "deployParsers": { "value": true },
  "deployWorkbooks": { "value": true },
  "deployHuntingQueries": { "value": true },
  "deployWatchlists": { "value": true },
  "tags": {
    "value": {
      "Environment": "Production",
      "Project": "Sentinel-Automation"
    }
  }
}
```

## 📦 Included Content

### Analytical Rules (2 Examples)

1. **Multiple Failed Login Attempts** - Detects brute force attacks
2. **Suspicious Process Execution** - Identifies malicious process execution

### Parsers (3 Examples)

1. **Custom Syslog Parser** - Normalizes Syslog data
2. **Web Access Log Parser** - Parses web server logs
3. **Enriched Azure Activity Parser** - Enhances Azure Activity logs

### Workbooks (3 Examples)

1. **Security Overview Dashboard** - High-level security metrics
2. **Threat Intelligence Dashboard** - Threat indicator tracking
3. **User Activity Monitoring** - User behavior analysis

### Hunting Queries (5 Examples)

1. **Rare Process Execution** - Identifies unusual processes
2. **Anomalous Login Times** - Detects off-hours access
3. **Privilege Escalation Indicators** - Monitors role changes
4. **Lateral Movement Detection** - Identifies network movement
5. **Data Exfiltration Indicators** - Detects data theft

### Watchlists (5 Examples)

1. **High-Value Assets** - Critical infrastructure list
2. **Known Malicious IPs** - Threat intelligence feed
3. **VIP Users** - Users requiring enhanced monitoring
4. **Allowed External Domains** - Approved external services
5. **Service Accounts** - Expected service account behavior

## 🔧 Customization

### Adding New Analytical Rules

Edit `modules/analyticalRules.bicep` and add a new resource:

```bicep
resource newRule 'Microsoft.SecurityInsights/alertRules@2023-02-01' = {
  scope: resourceId('Microsoft.OperationalInsights/workspaces', workspaceName)
  name: guid('your-rule-name-${workspaceName}')
  kind: 'Scheduled'
  properties: {
    displayName: 'Your Rule Name'
    description: 'Rule description'
    severity: 'High'
    enabled: true
    query: '''
      // Your KQL query here
    '''
    queryFrequency: 'PT1H'
    queryPeriod: 'PT1H'
    triggerOperator: 'GreaterThan'
    triggerThreshold: 0
    // ... additional properties
  }
}
```

### Adding New Watchlists

Edit `modules/watchlists.bicep` and add CSV data:

```bicep
resource newWatchlist 'Microsoft.SecurityInsights/watchlists@2023-02-01' = {
  scope: resourceId('Microsoft.OperationalInsights/workspaces', workspaceName)
  name: 'YourWatchlistName'
  properties: {
    displayName: 'Your Watchlist'
    description: 'Description'
    itemsSearchKey: 'KeyColumn'
    contentType: 'text/csv'
    numberOfLinesToSkip: 0
    rawContent: 'Column1,Column2,Column3\nValue1,Value2,Value3'
  }
}
```

## 🔍 Validation

### Validate Bicep Templates

```bash
# Validate main template
az bicep build --file main.bicep

# Validate specific module
az bicep build --file modules/analyticalRules.bicep
```

### Preview Changes

```bash
# See what will be deployed
az deployment group what-if \
  --resource-group rg-sentinel-prod \
  --template-file main.bicep \
  --parameters @parameters.json
```

## 📊 Post-Deployment

After deployment, complete these steps in the Azure Portal:

1. **Configure Data Connectors**
   - Navigate to Sentinel → Configuration → Data connectors
   - Connect your data sources (Azure AD, Office 365, etc.)

2. **Review Analytical Rules**
   - Go to Sentinel → Analytics
   - Review and enable/disable rules as needed
   - Adjust query frequencies and thresholds

3. **Configure Automation**
   - Set up automation rules
   - Create or import playbooks (Logic Apps)

4. **Set Up RBAC**
   - Assign appropriate roles to team members
   - Use built-in roles like Sentinel Reader, Responder, Contributor

5. **Test Workbooks**
   - Navigate to Sentinel → Workbooks
   - Open each workbook and verify data visualization

## 🛠️ Troubleshooting

### Common Issues

**Issue**: Deployment fails with permission errors
- **Solution**: Ensure you have Sentinel Contributor role or higher

**Issue**: Analytical rules don't trigger
- **Solution**: Verify data connectors are configured and sending data

**Issue**: Workbooks show no data
- **Solution**: Ensure sufficient data retention and data source connectivity

**Issue**: Bicep build fails
- **Solution**: Update Azure CLI: `az upgrade`

### Logs and Diagnostics

View deployment logs:
```bash
az deployment group show \
  --name sentinel-deployment \
  --resource-group rg-sentinel-prod \
  --query properties.error
```

## 🔐 Security Best Practices

1. **Use Managed Identities** for automation where possible
2. **Enable MFA** for all Sentinel users
3. **Implement RBAC** with least privilege principle
4. **Regular Review** of analytical rules and alerts
5. **Monitor Sentinel** usage and costs
6. **Backup Configuration** by maintaining this IaC repository
7. **Rotate Secrets** used in watchlists regularly

## 🤝 Contributing

To contribute to this repository:

1. Fork the repository
2. Create a feature branch
3. Add/modify Bicep templates
4. Test your changes
5. Submit a pull request

## 📝 License

This project is provided as-is for educational and deployment purposes.

## 🔗 Resources

### Azure Sentinel & Bicep
- [Microsoft Sentinel Documentation](https://docs.microsoft.com/azure/sentinel/)
- [Azure Bicep Documentation](https://docs.microsoft.com/azure/azure-resource-manager/bicep/)
- [KQL Reference](https://docs.microsoft.com/azure/data-explorer/kusto/query/)
- [Sentinel GitHub Repository](https://github.com/Azure/Azure-Sentinel)

### CI/CD & Automation
- [Azure Sentinel CI/CD Documentation](https://learn.microsoft.com/en-us/azure/sentinel/ci-cd?tabs=github)
- [Custom Deployments for CI/CD Pipelines](https://learn.microsoft.com/en-us/azure/sentinel/ci-cd-custom-deploy?tabs=github)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [CI/CD Setup Guide](CI_CD_SETUP.md) (This Repository)

## 📞 Support

For issues and questions:
- Review the troubleshooting section above
- Check Azure Sentinel documentation
- Open an issue in this repository

---

**Note**: The included content (rules, parsers, etc.) are examples. Customize them based on your specific security requirements and environment.
