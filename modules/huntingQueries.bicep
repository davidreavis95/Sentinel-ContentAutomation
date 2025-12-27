// Bicep module for deploying Sentinel Hunting Queries (Advanced Hunting)
@description('The name of the Log Analytics workspace')
param workspaceName string

// Reference to existing workspace
resource workspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: workspaceName
}

// Example Hunting Query 1: Rare process execution
resource huntingQuery1 'Microsoft.OperationalInsights/workspaces/savedSearches@2020-08-01' = {
  parent: workspace
  name: 'HuntingQuery-RareProcessExecution'
  properties: {
    category: 'Hunting Queries'
    displayName: 'Rare Process Execution'
    query: '''
      let timeframe = 7d;
      let threshold = 3;
      SecurityEvent
      | where TimeGenerated > ago(timeframe)
      | where EventID == 4688
      | summarize ExecutionCount = count(), FirstSeen = min(TimeGenerated), LastSeen = max(TimeGenerated) by Process, Computer
      | where ExecutionCount <= threshold
      | project FirstSeen, LastSeen, Computer, Process, ExecutionCount
      | order by ExecutionCount asc
    '''
    version: 2
    tags: [
      {
        name: 'description'
        value: 'Identifies rarely executed processes that could indicate suspicious activity'
      }
      {
        name: 'tactics'
        value: 'Execution,Persistence'
      }
      {
        name: 'techniques'
        value: 'T1059'
      }
    ]
  }
}

// Example Hunting Query 2: Anomalous login times
resource huntingQuery2 'Microsoft.OperationalInsights/workspaces/savedSearches@2020-08-01' = {
  parent: workspace
  name: 'HuntingQuery-AnomalousLoginTimes'
  properties: {
    category: 'Hunting Queries'
    displayName: 'Anomalous Login Times'
    query: '''
      let NormalWorkingHours = SigninLogs
      | where TimeGenerated > ago(30d)
      | extend Hour = datetime_part("hour", TimeGenerated)
      | where Hour >= 8 and Hour <= 18
      | summarize NormalLogins = count() by UserPrincipalName;
      SigninLogs
      | where TimeGenerated > ago(7d)
      | extend Hour = datetime_part("hour", TimeGenerated)
      | where Hour < 8 or Hour > 18
      | where ResultType == "0"
      | summarize OffHoursLogins = count(), OffHoursTimes = make_set(TimeGenerated) by UserPrincipalName, IPAddress
      | join kind=inner (NormalWorkingHours) on UserPrincipalName
      | where OffHoursLogins > 0
      | project UserPrincipalName, IPAddress, OffHoursLogins, NormalLogins, OffHoursTimes
      | order by OffHoursLogins desc
    '''
    version: 2
    tags: [
      {
        name: 'description'
        value: 'Detects successful logins during non-business hours from users who typically login during business hours'
      }
      {
        name: 'tactics'
        value: 'InitialAccess,Persistence'
      }
      {
        name: 'techniques'
        value: 'T1078'
      }
    ]
  }
}

// Example Hunting Query 3: Privilege escalation indicators
resource huntingQuery3 'Microsoft.OperationalInsights/workspaces/savedSearches@2020-08-01' = {
  parent: workspace
  name: 'HuntingQuery-PrivilegeEscalation'
  properties: {
    category: 'Hunting Queries'
    displayName: 'Privilege Escalation Indicators'
    query: '''
      AuditLogs
      | where TimeGenerated > ago(24h)
      | where OperationName has_any ("Add member to role", "Add user to group")
      | where Result == "success"
      | extend TargetUser = tostring(TargetResources[0].userPrincipalName)
      | extend TargetRole = tostring(TargetResources[0].displayName)
      | extend InitiatedBy = tostring(InitiatedBy.user.userPrincipalName)
      | where TargetRole has_any ("Administrator", "Global", "Privileged")
      | project TimeGenerated, OperationName, InitiatedBy, TargetUser, TargetRole, Result
      | order by TimeGenerated desc
    '''
    version: 2
    tags: [
      {
        name: 'description'
        value: 'Identifies potential privilege escalation activities by monitoring role and group membership changes'
      }
      {
        name: 'tactics'
        value: 'PrivilegeEscalation,Persistence'
      }
      {
        name: 'techniques'
        value: 'T1078,T1098'
      }
    ]
  }
}

// Example Hunting Query 4: Lateral movement detection
resource huntingQuery4 'Microsoft.OperationalInsights/workspaces/savedSearches@2020-08-01' = {
  parent: workspace
  name: 'HuntingQuery-LateralMovement'
  properties: {
    category: 'Hunting Queries'
    displayName: 'Lateral Movement Detection'
    query: '''
      SecurityEvent
      | where TimeGenerated > ago(24h)
      | where EventID == 4624
      | where LogonType in (3, 10)
      | extend Account = tolower(Account)
      | summarize DistinctMachines = dcount(Computer), Machines = make_set(Computer) by Account, bin(TimeGenerated, 1h)
      | where DistinctMachines >= 3
      | project TimeGenerated, Account, DistinctMachines, Machines
      | order by DistinctMachines desc
    '''
    version: 2
    tags: [
      {
        name: 'description'
        value: 'Detects accounts logging into multiple machines within a short time period, indicating potential lateral movement'
      }
      {
        name: 'tactics'
        value: 'LateralMovement'
      }
      {
        name: 'techniques'
        value: 'T1021'
      }
    ]
  }
}

// Example Hunting Query 5: Data exfiltration indicators
resource huntingQuery5 'Microsoft.OperationalInsights/workspaces/savedSearches@2020-08-01' = {
  parent: workspace
  name: 'HuntingQuery-DataExfiltration'
  properties: {
    category: 'Hunting Queries'
    displayName: 'Data Exfiltration Indicators'
    query: '''
      OfficeActivity
      | where TimeGenerated > ago(7d)
      | where Operation in ("FileDownloaded", "FileSyncDownloadedFull")
      | summarize TotalDownloads = count(), TotalSize = sum(Size), Files = make_set(SourceFileName) by UserId, ClientIP
      | where TotalDownloads > 50
      | project UserId, ClientIP, TotalDownloads, TotalSize, Files
      | order by TotalDownloads desc
    '''
    version: 2
    tags: [
      {
        name: 'description'
        value: 'Identifies users downloading an unusually high number of files, which could indicate data exfiltration'
      }
      {
        name: 'tactics'
        value: 'Exfiltration'
      }
      {
        name: 'techniques'
        value: 'T1048,T1567'
      }
    ]
  }
}

output huntingQuery1Id string = huntingQuery1.id
output huntingQuery2Id string = huntingQuery2.id
output huntingQuery3Id string = huntingQuery3.id
output huntingQuery4Id string = huntingQuery4.id
output huntingQuery5Id string = huntingQuery5.id
