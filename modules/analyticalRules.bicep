// Bicep module for deploying Sentinel Analytical Rules
@description('The name of the Log Analytics workspace')
param workspaceName string

// Reference to existing workspace
resource workspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: workspaceName
}

// Example Analytical Rule 1: Multiple failed logins
resource analyticalRule1 'Microsoft.SecurityInsights/alertRules@2023-02-01' = {
  scope: workspace
  name: guid('analytical-rule-failed-logins-${workspaceName}')
  kind: 'Scheduled'
  properties: {
    displayName: 'Multiple Failed Login Attempts'
    description: 'Detects multiple failed login attempts from a single IP address within a short time period'
    severity: 'Medium'
    enabled: true
    query: '''
      SigninLogs
      | where ResultType != "0"
      | where TimeGenerated > ago(1h)
      | summarize FailedAttempts = count() by IPAddress, UserPrincipalName, bin(TimeGenerated, 5m)
      | where FailedAttempts >= 5
      | project TimeGenerated, IPAddress, UserPrincipalName, FailedAttempts
    '''
    queryFrequency: 'PT1H'
    queryPeriod: 'PT1H'
    triggerOperator: 'GreaterThan'
    triggerThreshold: 0
    suppressionDuration: 'PT1H'
    suppressionEnabled: false
    tactics: [
      'CredentialAccess'
      'InitialAccess'
    ]
    techniques: [
      'T1110'
    ]
    alertRuleTemplateName: null
    incidentConfiguration: {
      createIncident: true
      groupingConfiguration: {
        enabled: true
        reopenClosedIncident: false
        lookbackDuration: 'PT5H'
        matchingMethod: 'AllEntities'
        groupByEntities: [
          'IP'
          'Account'
        ]
        groupByAlertDetails: []
        groupByCustomDetails: []
      }
    }
    eventGroupingSettings: {
      aggregationKind: 'SingleAlert'
    }
    alertDetailsOverride: null
    customDetails: null
    entityMappings: [
      {
        entityType: 'IP'
        fieldMappings: [
          {
            identifier: 'Address'
            columnName: 'IPAddress'
          }
        ]
      }
      {
        entityType: 'Account'
        fieldMappings: [
          {
            identifier: 'FullName'
            columnName: 'UserPrincipalName'
          }
        ]
      }
    ]
  }
}

// Example Analytical Rule 2: Suspicious process execution
resource analyticalRule2 'Microsoft.SecurityInsights/alertRules@2023-02-01' = {
  scope: workspace
  name: guid('analytical-rule-suspicious-process-${workspaceName}')
  kind: 'Scheduled'
  properties: {
    displayName: 'Suspicious Process Execution Detected'
    description: 'Detects execution of potentially malicious processes on endpoints'
    severity: 'High'
    enabled: true
    query: '''
      SecurityEvent
      | where EventID == 4688
      | where TimeGenerated > ago(1h)
      | where Process has_any ("powershell.exe", "cmd.exe", "wscript.exe", "cscript.exe")
      | where CommandLine has_any ("Invoke-Expression", "downloadstring", "encodedcommand", "bypass")
      | project TimeGenerated, Computer, Account, Process, CommandLine
    '''
    queryFrequency: 'PT1H'
    queryPeriod: 'PT1H'
    triggerOperator: 'GreaterThan'
    triggerThreshold: 0
    suppressionDuration: 'PT1H'
    suppressionEnabled: false
    tactics: [
      'Execution'
      'DefenseEvasion'
    ]
    techniques: [
      'T1059'
      'T1027'
    ]
    alertRuleTemplateName: null
    incidentConfiguration: {
      createIncident: true
      groupingConfiguration: {
        enabled: true
        reopenClosedIncident: false
        lookbackDuration: 'PT5H'
        matchingMethod: 'Selected'
        groupByEntities: [
          'Host'
        ]
        groupByAlertDetails: []
        groupByCustomDetails: []
      }
    }
    eventGroupingSettings: {
      aggregationKind: 'AlertPerResult'
    }
    alertDetailsOverride: null
    customDetails: null
    entityMappings: [
      {
        entityType: 'Host'
        fieldMappings: [
          {
            identifier: 'HostName'
            columnName: 'Computer'
          }
        ]
      }
      {
        entityType: 'Account'
        fieldMappings: [
          {
            identifier: 'FullName'
            columnName: 'Account'
          }
        ]
      }
      {
        entityType: 'Process'
        fieldMappings: [
          {
            identifier: 'CommandLine'
            columnName: 'CommandLine'
          }
        ]
      }
    ]
  }
}

output analyticalRule1Id string = analyticalRule1.id
output analyticalRule2Id string = analyticalRule2.id
