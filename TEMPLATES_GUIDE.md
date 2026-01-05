# Example Templates and Customization Guide

This guide provides examples and instructions for customizing the Sentinel deployment templates.

## Table of Contents

- [Adding Analytical Rules](#adding-analytical-rules)
- [Adding Parsers](#adding-parsers)
- [Adding Workbooks](#adding-workbooks)
- [Adding Hunting Queries](#adding-hunting-queries)
- [Adding Watchlists](#adding-watchlists)
- [Creating Custom Modules](#creating-custom-modules)

## Adding Analytical Rules

Analytical rules detect security threats using scheduled KQL queries.

### Example: Brute Force Attack Detection

Edit `modules/analyticalRules.bicep` and add:

```bicep
resource bruteForceSsh 'Microsoft.SecurityInsights/alertRules@2023-02-01' = {
  scope: workspace
  name: guid('brute-force-ssh-${workspaceName}')
  kind: 'Scheduled'
  properties: {
    displayName: 'Brute Force SSH Attempts'
    description: 'Detects multiple failed SSH login attempts from same IP'
    severity: 'High'
    enabled: true
    query: '''
      Syslog
      | where Facility == "auth" and SyslogMessage contains "Failed password"
      | extend IPAddress = extract(@"from (\d+\.\d+\.\d+\.\d+)", 1, SyslogMessage)
      | summarize FailedAttempts = count() by IPAddress, bin(TimeGenerated, 5m)
      | where FailedAttempts >= 10
    '''
    queryFrequency: 'PT5M'
    queryPeriod: 'PT5M'
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
      'T1078'
    ]
    incidentConfiguration: {
      createIncident: true
      groupingConfiguration: {
        enabled: true
        reopenClosedIncident: false
        lookbackDuration: 'PT1H'
        matchingMethod: 'Selected'
        groupByEntities: ['IP']
        groupByAlertDetails: []
        groupByCustomDetails: []
      }
    }
    eventGroupingSettings: {
      aggregationKind: 'AlertPerResult'
    }
    alertDetailsOverride: {
      alertDisplayNameFormat: 'Brute force SSH attack from {{IPAddress}}'
      alertDescriptionFormat: 'Multiple failed SSH attempts detected from IP: {{IPAddress}}'
      alertSeverityColumnName: null
      alertDynamicProperties: []
    }
  }
}
```

### Key Properties Explained

- **displayName**: Human-readable rule name
- **query**: KQL query to detect threats
- **queryFrequency**: How often to run (PT5M = every 5 minutes)
- **queryPeriod**: Time range to query (PT5M = last 5 minutes)
- **severity**: Low, Medium, High, Informational
- **tactics**: MITRE ATT&CK tactics
- **techniques**: MITRE ATT&CK technique IDs

## Adding Parsers

Parsers normalize data using KQL functions.

### Example: Custom Firewall Log Parser

Edit `modules/parsers.bicep` and add:

```bicep
resource firewallParser 'Microsoft.OperationalInsights/workspaces/savedSearches@2020-08-01' = {
  parent: workspace
  name: 'FirewallLogParser'
  properties: {
    category: 'Parsers'
    displayName: 'Firewall Log Parser'
    query: '''
      let FirewallParser = () {
        CommonSecurityLog
        | where DeviceVendor == "FortiGate"
        | extend 
            Action = case(
                DeviceAction == "accept", "Allow",
                DeviceAction == "deny", "Deny",
                DeviceAction == "block", "Block",
                "Unknown"
            ),
            Protocol = toupper(Protocol),
            SourceIP = SourceIP,
            DestinationIP = DestinationIP,
            SourcePort = SourcePort,
            DestinationPort = DestinationPort
        | project 
            TimeGenerated,
            Action,
            Protocol,
            SourceIP,
            DestinationIP,
            SourcePort,
            DestinationPort,
            SentBytes,
            ReceivedBytes
      };
      FirewallParser()
    '''
    functionAlias: 'FirewallParser'
    functionParameters: ''
    version: 2
  }
}
```

## Adding Workbooks

Workbooks create interactive dashboards.

### Example: Network Traffic Dashboard

Edit `modules/workbooks.bicep` and add:

```bicep
resource networkWorkbook 'Microsoft.Insights/workbooks@2022-04-01' = {
  name: guid('workbook-network-${workspaceName}')
  location: location
  kind: 'shared'
  properties: {
    displayName: 'Network Traffic Analysis'
    serializedData: string({
      version: 'Notebook/1.0'
      items: [
        {
          type: 1
          content: {
            json: '## Network Traffic Overview\n\nReal-time analysis of network traffic patterns'
          }
        }
        {
          type: 3
          content: {
            version: 'KqlItem/1.0'
            query: '''
              CommonSecurityLog
              | where TimeGenerated > ago(24h)
              | summarize Count = count() by Protocol
              | order by Count desc
              | render piechart
            '''
            size: 0
            title: 'Traffic by Protocol'
            queryType: 0
            resourceType: 'microsoft.operationalinsights/workspaces'
            visualization: 'piechart'
          }
        }
        {
          type: 3
          content: {
            version: 'KqlItem/1.0'
            query: '''
              CommonSecurityLog
              | where TimeGenerated > ago(24h)
              | summarize BytesTotal = sum(SentBytes + ReceivedBytes) by bin(TimeGenerated, 1h)
              | render timechart
            '''
            size: 0
            title: 'Bandwidth Usage Over Time'
            queryType: 0
            resourceType: 'microsoft.operationalinsights/workspaces'
            visualization: 'timechart'
          }
        }
      ]
    })
    version: '1.0'
    sourceId: workspaceId
    category: 'sentinel'
  }
}
```

## Adding Hunting Queries

Hunting queries help proactively search for threats.

### Example: Suspicious PowerShell Activity

Edit `modules/huntingQueries.bicep` and add:

```bicep
resource suspiciousPowershell 'Microsoft.OperationalInsights/workspaces/savedSearches@2020-08-01' = {
  parent: workspace
  name: 'SuspiciousPowerShellCommands'
  properties: {
    category: 'Hunting Queries'
    displayName: 'Suspicious PowerShell Commands'
    query: '''
      SecurityEvent
      | where EventID == 4688
      | where Process has_any ("powershell.exe", "pwsh.exe")
      | where CommandLine has_any (
          "-enc", "-encodedcommand", 
          "downloadstring", "iex",
          "bypass", "hidden",
          "noprofile", "noninteractive"
      )
      | project 
          TimeGenerated,
          Computer,
          Account,
          CommandLine,
          ParentProcessName
      | order by TimeGenerated desc
    '''
    functionAlias: 'SuspiciousPowerShellCommands'
    version: 2
    tags: [
      {
        name: 'tactics'
        value: 'Execution,DefenseEvasion'
      }
      {
        name: 'techniques'
        value: 'T1059.001,T1027'
      }
    ]
  }
}
```

## Adding Watchlists

Watchlists store reference data for enrichment.

### Example: Approved Processes List

Edit `modules/watchlists.bicep` and add:

```bicep
resource approvedProcesses 'Microsoft.SecurityInsights/watchlists@2023-02-01' = {
  scope: workspace
  name: 'ApprovedProcesses'
  properties: {
    displayName: 'Approved Processes'
    description: 'List of approved processes for the organization'
    provider: 'Microsoft'
    source: 'Local'
    itemsSearchKey: 'ProcessName'
    contentType: 'text/csv'
    numberOfLinesToSkip: 0
    rawContent: '''ProcessName,Description,Vendor,Approved
chrome.exe,Google Chrome Browser,Google,Yes
firefox.exe,Mozilla Firefox Browser,Mozilla,Yes
teams.exe,Microsoft Teams,Microsoft,Yes
outlook.exe,Microsoft Outlook,Microsoft,Yes
code.exe,Visual Studio Code,Microsoft,Yes
powershell.exe,Windows PowerShell,Microsoft,Yes
python.exe,Python Interpreter,Python Software Foundation,Yes
notepad.exe,Notepad Text Editor,Microsoft,Yes'''
  }
}
```

### Using Watchlists in Queries

```kql
// Enrich events with watchlist data
SecurityEvent
| where EventID == 4688
| join kind=leftouter (
    _GetWatchlist('ApprovedProcesses')
    | project ProcessName, Approved
) on $left.Process == $right.ProcessName
| where Approved != "Yes" or isempty(Approved)
| project TimeGenerated, Computer, Account, Process, CommandLine
```

## Creating Custom Modules

### Step 1: Create New Module File

Create `modules/myCustomModule.bicep`:

```bicep
@description('The name of the Log Analytics workspace')
param workspaceName string

@description('Additional parameters')
param customParameter string = 'default-value'

// Reference to existing workspace
resource workspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: workspaceName
}

// Add your resources here
resource customResource 'Microsoft.SecurityInsights/alertRules@2023-02-01' = {
  scope: workspace
  name: guid('custom-resource-${workspaceName}')
  kind: 'Scheduled'
  properties: {
    displayName: 'Custom Resource'
    // ... properties
  }
}

// Outputs
output resourceId string = customResource.id
```

### Step 2: Add to Main Template

Edit `main.bicep`:

```bicep
// Add parameter
@description('Deploy custom module')
param deployCustomModule bool = true

// Add module reference
module customModule 'modules/myCustomModule.bicep' = if (deployCustomModule) {
  name: 'deploy-custom-module'
  params: {
    workspaceName: workspace.name
    customParameter: 'my-value'
  }
  dependsOn: [
    sentinelSolution
  ]
}
```

### Step 3: Add to Parameters

Edit `parameters.json`:

```json
{
  "deployCustomModule": {
    "value": true
  }
}
```

## Best Practices

### 1. Use Unique Names

Always use `guid()` function with workspace name:
```bicep
name: guid('my-resource-${workspaceName}')
```

### 2. Scope Resources Correctly

Use workspace scope for Sentinel resources:
```bicep
resource myRule 'Microsoft.SecurityInsights/alertRules@2023-02-01' = {
  scope: workspace
  // ...
}
```

### 3. Add Dependencies

Ensure resources deploy after Sentinel solution:
```bicep
module myModule 'modules/myModule.bicep' = {
  // ...
  dependsOn: [
    sentinelSolution
  ]
}
```

### 4. Parameterize Everything

Make templates reusable:
```bicep
@description('Severity level')
@allowed(['Low', 'Medium', 'High', 'Informational'])
param severity string = 'Medium'
```

### 5. Use Comments

Document complex queries:
```bicep
query: '''
  // Filter to authentication events
  SigninLogs
  | where ResultType != "0"  // Non-successful logins
  // ... rest of query
'''
```

## Testing Templates

### 1. Validate Syntax

```bash
az bicep build --file main.bicep
az bicep build --file modules/myModule.bicep
```

### 2. Preview Changes

```bash
az deployment group what-if \
  --resource-group rg-test \
  --template-file main.bicep \
  --parameters @parameters.json
```

### 3. Deploy to Test Environment

```bash
python deploy_rest.py -g rg-test -p parameters.dev.json
```

## Common Patterns

### Dynamic Rule Creation

Create multiple rules from array:
```bicep
var rules = [
  { name: 'Rule1', severity: 'High' }
  { name: 'Rule2', severity: 'Medium' }
]

resource rules_deploy 'Microsoft.SecurityInsights/alertRules@2023-02-01' = [for rule in rules: {
  scope: workspace
  name: guid('${rule.name}-${workspaceName}')
  properties: {
    displayName: rule.name
    severity: rule.severity
    // ...
  }
}]
```

### Conditional Deployment

Deploy based on conditions:
```bicep
resource optionalRule 'Microsoft.SecurityInsights/alertRules@2023-02-01' = if (deployOptionalRules) {
  // ...
}
```

## Resources

- [Bicep Documentation](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
- [Sentinel API Reference](https://learn.microsoft.com/en-us/rest/api/securityinsights/)
- [KQL Reference](https://learn.microsoft.com/en-us/azure/data-explorer/kusto/query/)
- [MITRE ATT&CK Framework](https://attack.mitre.org/)

---

**Last Updated:** 2026-01-05
