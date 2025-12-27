# Example Analytical Rules

This document provides examples of additional analytical rules you can add to your Sentinel deployment.

## Example: Brute Force SSH Attempts

```bicep
resource sshBruteForce 'Microsoft.SecurityInsights/alertRules@2023-02-01' = {
  scope: resourceId('Microsoft.OperationalInsights/workspaces', workspaceName)
  name: guid('ssh-brute-force-${workspaceName}')
  kind: 'Scheduled'
  properties: {
    displayName: 'SSH Brute Force Attempt'
    description: 'Detects multiple failed SSH authentication attempts from a single source'
    severity: 'High'
    enabled: true
    query: '''
      Syslog
      | where Facility == "auth" or Facility == "authpriv"
      | where SyslogMessage has "Failed password"
      | where TimeGenerated > ago(1h)
      | extend SourceIP = extract(@"from ([\d\.]+)", 1, SyslogMessage)
      | summarize FailedAttempts = count(), Computers = make_set(Computer) by SourceIP, bin(TimeGenerated, 5m)
      | where FailedAttempts >= 10
      | project TimeGenerated, SourceIP, FailedAttempts, Computers
    '''
    queryFrequency: 'PT1H'
    queryPeriod: 'PT1H'
    triggerOperator: 'GreaterThan'
    triggerThreshold: 0
    suppressionDuration: 'PT1H'
    suppressionEnabled: false
    tactics: ['CredentialAccess']
    techniques: ['T1110']
    incidentConfiguration: {
      createIncident: true
      groupingConfiguration: {
        enabled: true
        reopenClosedIncident: false
        lookbackDuration: 'PT5H'
        matchingMethod: 'AllEntities'
        groupByEntities: ['IP']
      }
    }
    entityMappings: [
      {
        entityType: 'IP'
        fieldMappings: [
          {
            identifier: 'Address'
            columnName: 'SourceIP'
          }
        ]
      }
    ]
  }
}
```

## Example: Unusual Azure Resource Deletion

```bicep
resource unusualDeletion 'Microsoft.SecurityInsights/alertRules@2023-02-01' = {
  scope: resourceId('Microsoft.OperationalInsights/workspaces', workspaceName)
  name: guid('unusual-deletion-${workspaceName}')
  kind: 'Scheduled'
  properties: {
    displayName: 'Unusual Azure Resource Deletion Activity'
    description: 'Detects when a user deletes an unusual number of Azure resources'
    severity: 'Medium'
    enabled: true
    query: '''
      AzureActivity
      | where TimeGenerated > ago(1h)
      | where OperationNameValue has "delete"
      | where ActivityStatusValue == "Success"
      | summarize DeletedResources = count(), Resources = make_set(ResourceId) by Caller, bin(TimeGenerated, 5m)
      | where DeletedResources >= 5
      | project TimeGenerated, Caller, DeletedResources, Resources
    '''
    queryFrequency: 'PT1H'
    queryPeriod: 'PT1H'
    triggerOperator: 'GreaterThan'
    triggerThreshold: 0
    suppressionDuration: 'PT1H'
    suppressionEnabled: false
    tactics: ['Impact']
    techniques: ['T1485', 'T1489']
    incidentConfiguration: {
      createIncident: true
      groupingConfiguration: {
        enabled: true
        reopenClosedIncident: false
        lookbackDuration: 'PT5H'
        matchingMethod: 'Selected'
        groupByEntities: ['Account']
      }
    }
    entityMappings: [
      {
        entityType: 'Account'
        fieldMappings: [
          {
            identifier: 'FullName'
            columnName: 'Caller'
          }
        ]
      }
    ]
  }
}
```

## Example: Sensitive File Access

```bicep
resource sensitiveFileAccess 'Microsoft.SecurityInsights/alertRules@2023-02-01' = {
  scope: resourceId('Microsoft.OperationalInsights/workspaces', workspaceName)
  name: guid('sensitive-file-access-${workspaceName}')
  kind: 'Scheduled'
  properties: {
    displayName: 'Access to Sensitive Files'
    description: 'Detects access to files with sensitive patterns in their names'
    severity: 'Medium'
    enabled: true
    query: '''
      SecurityEvent
      | where TimeGenerated > ago(1h)
      | where EventID == 4663  // File access event
      | where ObjectName has_any ("password", "credential", "secret", "private", "confidential")
      | extend FileName = tostring(split(ObjectName, "\\")[-1])
      | project TimeGenerated, Computer, Account, ObjectName, FileName, AccessMask
    '''
    queryFrequency: 'PT1H'
    queryPeriod: 'PT1H'
    triggerOperator: 'GreaterThan'
    triggerThreshold: 0
    suppressionDuration: 'PT1H'
    suppressionEnabled: false
    tactics: ['Collection', 'CredentialAccess']
    techniques: ['T1005', 'T1552']
    incidentConfiguration: {
      createIncident: true
      groupingConfiguration: {
        enabled: true
        reopenClosedIncident: false
        lookbackDuration: 'PT5H'
        matchingMethod: 'Selected'
        groupByEntities: ['Account', 'Host']
      }
    }
    entityMappings: [
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
        entityType: 'Host'
        fieldMappings: [
          {
            identifier: 'HostName'
            columnName: 'Computer'
          }
        ]
      }
      {
        entityType: 'File'
        fieldMappings: [
          {
            identifier: 'Name'
            columnName: 'FileName'
          }
        ]
      }
    ]
  }
}
```

## Key Configuration Options

### Severity Levels
- `Critical` - Immediate action required
- `High` - Requires prompt attention
- `Medium` - Should be investigated
- `Low` - Informational
- `Informational` - For awareness

### Query Frequency Options
- `PT5M` - Every 5 minutes
- `PT15M` - Every 15 minutes
- `PT30M` - Every 30 minutes
- `PT1H` - Every hour
- `PT6H` - Every 6 hours
- `P1D` - Once per day

### Entity Types
- `Account` - User or service account
- `Host` - Computer or server
- `IP` - IP address
- `File` - File reference
- `Process` - Running process
- `URL` - Web address
- `AzureResource` - Azure resource
- `CloudApplication` - Cloud app

### MITRE ATT&CK Tactics
- `InitialAccess`
- `Execution`
- `Persistence`
- `PrivilegeEscalation`
- `DefenseEvasion`
- `CredentialAccess`
- `Discovery`
- `LateralMovement`
- `Collection`
- `Exfiltration`
- `CommandAndControl`
- `Impact`
