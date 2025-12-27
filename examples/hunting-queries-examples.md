# Example KQL Queries for Hunting

This document provides example KQL queries for threat hunting in Microsoft Sentinel.

## Network Security

### Port Scanning Detection

```kql
// Detect port scanning activity
let threshold = 20;
CommonSecurityLog
| where TimeGenerated > ago(1h)
| where DeviceAction == "deny" or DeviceAction == "drop"
| summarize 
    DistinctPorts = dcount(DestinationPort),
    Ports = make_set(DestinationPort),
    TargetHosts = make_set(DestinationIP)
    by SourceIP, bin(TimeGenerated, 5m)
| where DistinctPorts > threshold
| project TimeGenerated, SourceIP, DistinctPorts, Ports, TargetHosts
| order by DistinctPorts desc
```

### Unusual Outbound Connections

```kql
// Identify unusual outbound network connections
let historicalData = 
    CommonSecurityLog
    | where TimeGenerated between(ago(30d)..ago(1d))
    | where DeviceAction == "allow"
    | summarize HistoricalConnections = count() by SourceIP, DestinationIP;
CommonSecurityLog
| where TimeGenerated > ago(1h)
| where DeviceAction == "allow"
| summarize RecentConnections = count() by SourceIP, DestinationIP
| join kind=leftanti (historicalData) on SourceIP, DestinationIP
| where RecentConnections > 0
| project SourceIP, DestinationIP, RecentConnections
```

## User Behavior Analytics

### Impossible Travel

```kql
// Detect impossible travel - successful logins from geographically distant locations
let timeWindow = 1h;
let minimumDistance = 500; // km
SigninLogs
| where TimeGenerated > ago(24h)
| where ResultType == "0"
| extend Country = tostring(LocationDetails.countryOrRegion)
| extend City = tostring(LocationDetails.city)
| project TimeGenerated, UserPrincipalName, Country, City, IPAddress, Location
| order by UserPrincipalName, TimeGenerated asc
| serialize
| extend PrevCountry = prev(Country, 1)
| extend PrevCity = prev(City, 1)
| extend PrevTime = prev(TimeGenerated, 1)
| extend TimeDiff = datetime_diff('minute', TimeGenerated, PrevTime)
| where UserPrincipalName == prev(UserPrincipalName, 1)
| where Country != PrevCountry
| where TimeDiff <= 60
| project TimeGenerated, UserPrincipalName, IPAddress, 
          CurrentLocation = strcat(City, ", ", Country),
          PreviousLocation = strcat(PrevCity, ", ", PrevCountry),
          TimeDifferenceMinutes = TimeDiff
```

### Account Enumeration

```kql
// Detect account enumeration attempts
SigninLogs
| where TimeGenerated > ago(1h)
| where ResultType != "0"
| where ResultDescription has_any ("does not exist", "not found", "invalid")
| summarize 
    AttemptedAccounts = dcount(UserPrincipalName),
    Accounts = make_set(UserPrincipalName),
    FailureTypes = make_set(ResultDescription)
    by IPAddress, bin(TimeGenerated, 5m)
| where AttemptedAccounts >= 10
| project TimeGenerated, IPAddress, AttemptedAccounts, Accounts, FailureTypes
| order by AttemptedAccounts desc
```

## Malware and Threats

### PowerShell Command Obfuscation

```kql
// Detect obfuscated PowerShell commands
SecurityEvent
| where TimeGenerated > ago(24h)
| where EventID == 4688
| where Process has "powershell.exe"
| where CommandLine has_any ("-enc", "-encoded", "frombase64", "invoke-expression", "iex")
| extend 
    HasEncoded = CommandLine has_any ("-enc", "-encoded"),
    HasBase64 = CommandLine has "frombase64",
    HasIEX = CommandLine has_any ("invoke-expression", "iex"),
    CommandLength = strlen(CommandLine)
| where CommandLength > 100
| project TimeGenerated, Computer, Account, Process, CommandLine, 
          HasEncoded, HasBase64, HasIEX, CommandLength
| order by TimeGenerated desc
```

### Suspicious Registry Modifications

```kql
// Detect suspicious registry modifications
SecurityEvent
| where TimeGenerated > ago(24h)
| where EventID == 4657  // Registry value modified
| where ObjectName has_any ("\\Run", "\\RunOnce", "\\Startup", "\\Services")
| extend RegistryPath = ObjectName
| project TimeGenerated, Computer, Account, RegistryPath, OperationType
```

## Privilege Escalation

### Service Installation by Non-Admin

```kql
// Detect service installations by non-privileged users
SecurityEvent
| where TimeGenerated > ago(24h)
| where EventID == 4697  // Service installed
| extend ServiceName = tostring(parse_json(EventData).ServiceName)
| extend ServiceFileName = tostring(parse_json(EventData).ServiceFileName)
| project TimeGenerated, Computer, Account, ServiceName, ServiceFileName
| where Account !endswith "$"  // Exclude system accounts
```

### Privilege Group Modifications

```kql
// Monitor changes to privileged groups
SecurityEvent
| where TimeGenerated > ago(24h)
| where EventID in (4728, 4732, 4756)  // Member added to security group
| where TargetUserName has_any ("Administrators", "Domain Admins", "Enterprise Admins", "Schema Admins")
| extend 
    AddedUser = MemberName,
    PrivilegedGroup = TargetUserName,
    ModifiedBy = SubjectUserName
| project TimeGenerated, Computer, ModifiedBy, AddedUser, PrivilegedGroup
```

## Data Exfiltration

### Large Data Transfers

```kql
// Detect unusually large data transfers
let threshold = 1000000000; // 1GB in bytes
OfficeActivity
| where TimeGenerated > ago(24h)
| where Operation in ("FileUploaded", "FileSyncUploadedFull")
| summarize TotalBytes = sum(Size), FileCount = count() by UserId, ClientIP, bin(TimeGenerated, 1h)
| where TotalBytes > threshold
| project TimeGenerated, UserId, ClientIP, TotalBytes, FileCount
| order by TotalBytes desc
```

### Access to Multiple SharePoint Sites

```kql
// Detect users accessing unusual number of SharePoint sites
let baselineUsers = 
    OfficeActivity
    | where TimeGenerated between(ago(30d)..ago(1d))
    | where OfficeWorkload == "SharePoint"
    | summarize AvgSites = avg(dcount(SiteUrl)) by UserId;
OfficeActivity
| where TimeGenerated > ago(1d)
| where OfficeWorkload == "SharePoint"
| summarize CurrentSites = dcount(SiteUrl), Sites = make_set(SiteUrl) by UserId
| join kind=inner (baselineUsers) on UserId
| where CurrentSites > (AvgSites * 2)
| project UserId, CurrentSites, AvgSites, Sites
```

## Cloud Security

### Risky Azure Resource Changes

```kql
// Detect risky Azure resource configuration changes
AzureActivity
| where TimeGenerated > ago(24h)
| where OperationNameValue has_any ("write", "delete")
| where ResourceProviderValue has_any ("Microsoft.Network", "Microsoft.Security", "Microsoft.Authorization")
| where ActivityStatusValue == "Success"
| project TimeGenerated, Caller, OperationNameValue, ResourceProviderValue, ResourceId, ActivityStatusValue
```

### Unused Service Principal Credentials

```kql
// Identify service principals with credentials that haven't been used recently
AuditLogs
| where TimeGenerated > ago(90d)
| where OperationName == "Update application"
| where Result == "success"
| extend AppId = tostring(TargetResources[0].id)
| summarize LastCredentialUpdate = max(TimeGenerated) by AppId
| join kind=leftouter (
    SigninLogs
    | where TimeGenerated > ago(90d)
    | where AppId != ""
    | summarize LastSignIn = max(TimeGenerated) by AppId
) on AppId
| where isnull(LastSignIn) or LastSignIn < ago(60d)
| project AppId, LastCredentialUpdate, LastSignIn
```

## Advanced Persistent Threats (APT)

### Beacon Detection

```kql
// Detect potential C2 beaconing based on regular intervals
let timeBinSize = 1m;
let connectionThreshold = 10;
CommonSecurityLog
| where TimeGenerated > ago(24h)
| where DeviceAction == "allow"
| summarize Connections = count() by SourceIP, DestinationIP, bin(TimeGenerated, timeBinSize)
| summarize 
    ConnectionIntervals = count(),
    AvgConnections = avg(Connections),
    StdDevConnections = stdev(Connections)
    by SourceIP, DestinationIP
| where ConnectionIntervals >= connectionThreshold
| where StdDevConnections < 2  // Low variance indicates regular intervals
| project SourceIP, DestinationIP, ConnectionIntervals, AvgConnections, StdDevConnections
```

### Living Off the Land Binaries (LOLBins)

```kql
// Detect suspicious use of legitimate system binaries
let suspiciousBinaries = dynamic([
    "certutil.exe", "bitsadmin.exe", "regsvr32.exe", 
    "mshta.exe", "rundll32.exe", "wmic.exe"
]);
SecurityEvent
| where TimeGenerated > ago(24h)
| where EventID == 4688
| where Process has_any (suspiciousBinaries)
| where CommandLine has_any ("http", "ftp", "download", "exec", "script")
| project TimeGenerated, Computer, Account, Process, CommandLine, ParentProcessName
```

## Tips for Effective Hunting

1. **Use Time-Based Baselines**: Compare recent activity against historical patterns
2. **Set Appropriate Thresholds**: Adjust based on your environment's normal behavior
3. **Combine Multiple Indicators**: Look for correlation between different data sources
4. **Iterate and Refine**: Continuously improve queries based on findings
5. **Document Findings**: Keep track of confirmed threats and false positives
6. **Leverage Watchlists**: Enrich queries with known good/bad indicators
