// Main Bicep template for Microsoft Sentinel deployment
// This template orchestrates the deployment of Sentinel workspace and all content types

@description('The name of the Log Analytics workspace')
param workspaceName string

@description('The location for all resources')
param location string = resourceGroup().location

@description('The pricing tier of the Log Analytics workspace')
@allowed([
  'PerGB2018'
  'Free'
  'Standalone'
  'PerNode'
  'Standard'
  'Premium'
])
param workspaceSku string = 'PerGB2018'

@description('The workspace data retention in days')
@minValue(30)
@maxValue(730)
param dataRetention int = 90

@description('Enable daily quota (GB). Set to -1 for unlimited')
param dailyQuotaGb int = -1

@description('Deploy analytical rules')
param deployAnalyticalRules bool = true

@description('Deploy parsers')
param deployParsers bool = true

@description('Deploy workbooks')
param deployWorkbooks bool = true

@description('Deploy hunting queries')
param deployHuntingQueries bool = true

@description('Deploy watchlists')
param deployWatchlists bool = true

@description('Tags to apply to all resources')
param tags object = {}

// Deploy Log Analytics Workspace
resource workspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: workspaceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: workspaceSku
    }
    retentionInDays: dataRetention
    workspaceCapping: dailyQuotaGb > 0 ? {
      dailyQuotaGb: dailyQuotaGb
    } : null
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// Deploy Microsoft Sentinel (SecurityInsights solution)
resource sentinelSolution 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  name: 'SecurityInsights(${workspaceName})'
  location: location
  tags: tags
  plan: {
    name: 'SecurityInsights(${workspaceName})'
    publisher: 'Microsoft'
    product: 'OMSGallery/SecurityInsights'
    promotionCode: ''
  }
  properties: {
    workspaceResourceId: workspace.id
  }
}

// Deploy Analytical Rules
module analyticalRules 'modules/analyticalRules.bicep' = if (deployAnalyticalRules) {
  name: 'deploy-analytical-rules'
  params: {
    workspaceName: workspace.name
  }
  dependsOn: [
    sentinelSolution
  ]
}

// Deploy Parsers
module parsers 'modules/parsers.bicep' = if (deployParsers) {
  name: 'deploy-parsers'
  params: {
    workspaceName: workspace.name
  }
  dependsOn: [
    sentinelSolution
  ]
}

// Deploy Workbooks
module workbooks 'modules/workbooks.bicep' = if (deployWorkbooks) {
  name: 'deploy-workbooks'
  params: {
    workspaceName: workspace.name
    workspaceId: workspace.id
    location: location
  }
  dependsOn: [
    sentinelSolution
  ]
}

// Deploy Hunting Queries
module huntingQueries 'modules/huntingQueries.bicep' = if (deployHuntingQueries) {
  name: 'deploy-hunting-queries'
  params: {
    workspaceName: workspace.name
  }
  dependsOn: [
    sentinelSolution
  ]
}

// Deploy Watchlists
module watchlists 'modules/watchlists.bicep' = if (deployWatchlists) {
  name: 'deploy-watchlists'
  params: {
    workspaceName: workspace.name
  }
  dependsOn: [
    sentinelSolution
  ]
}

// Outputs
output workspaceId string = workspace.id
output workspaceName string = workspace.name
output sentinelSolutionId string = sentinelSolution.id
