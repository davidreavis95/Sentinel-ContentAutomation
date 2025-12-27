#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Deploy Microsoft Sentinel and all content types using Bicep
.DESCRIPTION
    This script deploys Microsoft Sentinel workspace and associated content including:
    - Analytical Rules
    - Parsers
    - Workbooks
    - Hunting Queries (Advanced Hunting)
    - Watchlists
.PARAMETER ResourceGroupName
    The name of the Azure resource group where Sentinel will be deployed
.PARAMETER Location
    The Azure region for the deployment (default: eastus)
.PARAMETER ParameterFile
    Path to the parameter file (default: parameters.json)
.PARAMETER WhatIf
    Run the deployment in what-if mode to preview changes
.EXAMPLE
    .\deploy.ps1 -ResourceGroupName "rg-sentinel-prod" -Location "eastus"
.EXAMPLE
    .\deploy.ps1 -ResourceGroupName "rg-sentinel-dev" -ParameterFile "parameters.dev.json" -WhatIf
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $false)]
    [string]$Location = "eastus",
    
    [Parameter(Mandatory = $false)]
    [string]$ParameterFile = "parameters.json",
    
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "Sentinel Deployment Script" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# Check if Azure CLI is installed
Write-Host "Checking Azure CLI installation..." -ForegroundColor Yellow
try {
    $azVersion = az version --output json | ConvertFrom-Json
    Write-Host "✓ Azure CLI version: $($azVersion.'azure-cli')" -ForegroundColor Green
}
catch {
    Write-Error "Azure CLI is not installed. Please install it from https://docs.microsoft.com/cli/azure/install-azure-cli"
    exit 1
}

# Check if logged in to Azure
Write-Host "Checking Azure login status..." -ForegroundColor Yellow
try {
    $account = az account show --output json | ConvertFrom-Json
    Write-Host "✓ Logged in as: $($account.user.name)" -ForegroundColor Green
    Write-Host "✓ Subscription: $($account.name) ($($account.id))" -ForegroundColor Green
}
catch {
    Write-Error "Not logged in to Azure. Please run 'az login' first."
    exit 1
}

# Verify parameter file exists
if (-not (Test-Path $ParameterFile)) {
    Write-Error "Parameter file not found: $ParameterFile"
    exit 1
}
Write-Host "✓ Using parameter file: $ParameterFile" -ForegroundColor Green

# Check if resource group exists
Write-Host ""
Write-Host "Checking resource group..." -ForegroundColor Yellow
$rgExists = az group exists --name $ResourceGroupName
if ($rgExists -eq "false") {
    Write-Host "Creating resource group: $ResourceGroupName in $Location" -ForegroundColor Yellow
    az group create --name $ResourceGroupName --location $Location --output none
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to create resource group"
        exit 1
    }
    Write-Host "✓ Resource group created" -ForegroundColor Green
}
else {
    Write-Host "✓ Resource group exists: $ResourceGroupName" -ForegroundColor Green
}

# Build Bicep file
Write-Host ""
Write-Host "Building Bicep template..." -ForegroundColor Yellow
az bicep build --file main.bicep
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to build Bicep template"
    exit 1
}
Write-Host "✓ Bicep template built successfully" -ForegroundColor Green

# Deploy or validate
Write-Host ""
if ($WhatIf) {
    Write-Host "Running deployment validation (What-If)..." -ForegroundColor Yellow
    az deployment group what-if `
        --resource-group $ResourceGroupName `
        --template-file main.bicep `
        --parameters "@$ParameterFile"
}
else {
    Write-Host "Starting deployment..." -ForegroundColor Yellow
    Write-Host "This may take several minutes..." -ForegroundColor Yellow
    
    $deploymentName = "sentinel-deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    
    az deployment group create `
        --name $deploymentName `
        --resource-group $ResourceGroupName `
        --template-file main.bicep `
        --parameters "@$ParameterFile" `
        --verbose
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Deployment failed"
        exit 1
    }
    
    Write-Host ""
    Write-Host "=====================================" -ForegroundColor Green
    Write-Host "Deployment completed successfully!" -ForegroundColor Green
    Write-Host "=====================================" -ForegroundColor Green
    Write-Host ""
    
    # Get deployment outputs
    Write-Host "Deployment outputs:" -ForegroundColor Cyan
    az deployment group show `
        --name $deploymentName `
        --resource-group $ResourceGroupName `
        --query properties.outputs `
        --output table
}

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Configure data connectors in the Azure Portal" -ForegroundColor White
Write-Host "2. Review and customize analytical rules" -ForegroundColor White
Write-Host "3. Configure automation rules and playbooks" -ForegroundColor White
Write-Host "4. Set up RBAC permissions for your team" -ForegroundColor White
Write-Host ""
