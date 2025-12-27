// Bicep module for deploying Sentinel Workbooks
@description('The name of the Log Analytics workspace')
param workspaceName string

@description('The Log Analytics workspace resource ID')
param workspaceId string

@description('The location for all resources')
param location string = resourceGroup().location

// Example Workbook 1: Security Overview Dashboard
resource workbook1 'Microsoft.Insights/workbooks@2022-04-01' = {
  name: guid('workbook-security-overview-${workspaceName}')
  location: location
  kind: 'shared'
  properties: {
    displayName: 'Security Overview Dashboard'
    serializedData: string({
      version: 'Notebook/1.0'
      items: [
        {
          type: 1
          content: {
            json: '## Security Overview Dashboard\n\nThis workbook provides an overview of security events and alerts in your environment.'
          }
        }
        {
          type: 3
          content: {
            version: 'KqlItem/1.0'
            query: 'SecurityAlert\n| where TimeGenerated > ago(24h)\n| summarize Count = count() by AlertSeverity\n| render piechart'
            size: 1
            title: 'Alerts by Severity (Last 24 Hours)'
            timeContext: {
              durationMs: 86400000
            }
            queryType: 0
            resourceType: 'microsoft.operationalinsights/workspaces'
          }
        }
        {
          type: 3
          content: {
            version: 'KqlItem/1.0'
            query: 'SecurityEvent\n| where TimeGenerated > ago(24h)\n| summarize Count = count() by bin(TimeGenerated, 1h)\n| render timechart'
            size: 1
            title: 'Security Events Over Time'
            timeContext: {
              durationMs: 86400000
            }
            queryType: 0
            resourceType: 'microsoft.operationalinsights/workspaces'
          }
        }
        {
          type: 3
          content: {
            version: 'KqlItem/1.0'
            query: 'SigninLogs\n| where TimeGenerated > ago(24h)\n| where ResultType != "0"\n| summarize FailedAttempts = count() by UserPrincipalName, IPAddress\n| top 10 by FailedAttempts\n| project UserPrincipalName, IPAddress, FailedAttempts'
            size: 1
            title: 'Top 10 Failed Sign-in Attempts'
            timeContext: {
              durationMs: 86400000
            }
            queryType: 0
            resourceType: 'microsoft.operationalinsights/workspaces'
          }
        }
      ]
      styleSettings: {}
      fromTemplateId: 'sentinel-UserWorkbook'
    })
    category: 'sentinel'
    sourceId: workspaceId
  }
}

// Example Workbook 2: Threat Intelligence Dashboard
resource workbook2 'Microsoft.Insights/workbooks@2022-04-01' = {
  name: guid('workbook-threat-intel-${workspaceName}')
  location: location
  kind: 'shared'
  properties: {
    displayName: 'Threat Intelligence Dashboard'
    serializedData: string({
      version: 'Notebook/1.0'
      items: [
        {
          type: 1
          content: {
            json: '## Threat Intelligence Dashboard\n\nMonitor threat indicators and suspicious activities.'
          }
        }
        {
          type: 3
          content: {
            version: 'KqlItem/1.0'
            query: 'ThreatIntelligenceIndicator\n| where TimeGenerated > ago(7d)\n| summarize Count = count() by ThreatType\n| render barchart'
            size: 1
            title: 'Threat Types (Last 7 Days)'
            timeContext: {
              durationMs: 604800000
            }
            queryType: 0
            resourceType: 'microsoft.operationalinsights/workspaces'
          }
        }
        {
          type: 3
          content: {
            version: 'KqlItem/1.0'
            query: 'CommonSecurityLog\n| where TimeGenerated > ago(24h)\n| where DeviceAction != "allow"\n| summarize Count = count() by DeviceVendor, DeviceProduct\n| top 10 by Count'
            size: 1
            title: 'Top Security Devices with Blocked Actions'
            timeContext: {
              durationMs: 86400000
            }
            queryType: 0
            resourceType: 'microsoft.operationalinsights/workspaces'
          }
        }
      ]
      styleSettings: {}
      fromTemplateId: 'sentinel-UserWorkbook'
    })
    category: 'sentinel'
    sourceId: workspaceId
  }
}

// Example Workbook 3: User Activity Monitoring
resource workbook3 'Microsoft.Insights/workbooks@2022-04-01' = {
  name: guid('workbook-user-activity-${workspaceName}')
  location: location
  kind: 'shared'
  properties: {
    displayName: 'User Activity Monitoring'
    serializedData: string({
      version: 'Notebook/1.0'
      items: [
        {
          type: 1
          content: {
            json: '## User Activity Monitoring\n\nTrack and analyze user activities across your environment.'
          }
        }
        {
          type: 3
          content: {
            version: 'KqlItem/1.0'
            query: 'AuditLogs\n| where TimeGenerated > ago(24h)\n| summarize Count = count() by OperationName\n| top 10 by Count\n| render barchart'
            size: 1
            title: 'Top 10 Audit Operations'
            timeContext: {
              durationMs: 86400000
            }
            queryType: 0
            resourceType: 'microsoft.operationalinsights/workspaces'
          }
        }
        {
          type: 3
          content: {
            version: 'KqlItem/1.0'
            query: 'SigninLogs\n| where TimeGenerated > ago(24h)\n| summarize SuccessfulLogins = countif(ResultType == "0"), FailedLogins = countif(ResultType != "0") by UserPrincipalName\n| where FailedLogins > 0 or SuccessfulLogins > 0\n| top 20 by FailedLogins'
            size: 1
            title: 'User Login Statistics'
            timeContext: {
              durationMs: 86400000
            }
            queryType: 0
            resourceType: 'microsoft.operationalinsights/workspaces'
          }
        }
      ]
      styleSettings: {}
      fromTemplateId: 'sentinel-UserWorkbook'
    })
    category: 'sentinel'
    sourceId: workspaceId
  }
}

output workbook1Id string = workbook1.id
output workbook2Id string = workbook2.id
output workbook3Id string = workbook3.id
