# GitHub Actions Workflows

This directory contains GitHub Actions workflows for automated validation, deployment, and security scanning.

## Workflows Overview

### 1. validate.yml - Template Validation
**Triggers:** PR, Push to main/develop, Manual
**Purpose:** Validate Bicep templates and Python scripts

**Jobs:**
- `validate-bicep`: Lint and build Bicep templates
- `validate-python`: Check Python syntax and lint code
- `validate-deployment`: Run what-if deployment preview (PRs only)

**Duration:** ~2-3 minutes

### 2. deploy.yml - Automated Deployment
**Triggers:** Push to main (dev), Manual (prod)
**Purpose:** Deploy Sentinel to Azure environments

**Jobs:**
- `deploy-development`: Auto-deploy to dev on push to main
- `deploy-production`: Manual deploy to prod (requires approval)

**Duration:** ~10-15 minutes

### 3. codeql.yml - Security Scanning
**Triggers:** PR, Push, Weekly schedule, Manual
**Purpose:** Security analysis of Python code

**Jobs:**
- `codeql`: Scan Python code for vulnerabilities

**Duration:** ~3-5 minutes

## Quick Reference

### Trigger a Manual Deployment

1. Go to **Actions** tab
2. Select **Deploy to Azure Sentinel**
3. Click **Run workflow**
4. Choose environment and parameters
5. Click **Run workflow**

### View Workflow Logs

1. Go to **Actions** tab
2. Click on workflow run
3. Click on job name
4. Expand steps to see logs

### Download Artifacts

Some workflows produce artifacts (e.g., built ARM templates):
1. Go to workflow run
2. Scroll to **Artifacts** section
3. Click to download

## Workflow Status Badges

Add to README:
```markdown
[![Validate](https://github.com/davidreavis95/Sentinel-ContentAutomation/workflows/Validate%20Bicep%20Templates/badge.svg)](https://github.com/davidreavis95/Sentinel-ContentAutomation/actions/workflows/validate.yml)
```

## Environment Variables

Workflows use these GitHub secrets:
- `AZURE_CREDENTIALS` - Service Principal credentials (required)
- `DEV_RESOURCE_GROUP` - Dev resource group name (optional)
- `DEV_LOCATION` - Dev Azure region (optional)
- `AZURE_RG_NAME` - What-if resource group (optional)

See [CI_CD_SETUP.md](../../CI_CD_SETUP.md) for setup instructions.

## Customization

To modify workflows:
1. Edit YAML files in this directory
2. Test changes in a feature branch
3. Create PR to validate
4. Merge to main

## Troubleshooting

**Workflow fails with authentication error:**
- Check `AZURE_CREDENTIALS` secret is configured
- Verify Service Principal has correct permissions

**Deployment fails:**
- Check Azure subscription has quota
- Verify resource group can be created
- Review deployment logs in Azure Portal

**What-if step fails in PR:**
- This is set to continue-on-error
- Not required for PR approval
- May need AZURE_RG_NAME secret configured

## Best Practices

1. **Always test in dev first** - Use manual workflow for production
2. **Review what-if output** - Check changes before deploying
3. **Use protected branches** - Require reviews for main branch
4. **Monitor workflow runs** - Check Actions tab regularly
5. **Keep secrets updated** - Rotate Service Principal credentials

## Support

For workflow issues:
- Review logs in Actions tab
- Check [CI_CD_SETUP.md](../../CI_CD_SETUP.md)
- Open an issue in this repository

---

**Last Updated:** 2026-01-05
