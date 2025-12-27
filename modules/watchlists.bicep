// Bicep module for deploying Sentinel Watchlists
@description('The name of the Log Analytics workspace')
param workspaceName string

// Reference to existing workspace
resource workspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: workspaceName
}

// Example Watchlist 1: High-Value Assets
resource watchlist1 'Microsoft.SecurityInsights/watchlists@2023-02-01' = {
  scope: workspace
  name: 'HighValueAssets'
  properties: {
    displayName: 'High-Value Assets'
    description: 'List of high-value assets that require special monitoring'
    provider: 'Microsoft'
    source: 'Local file'
    itemsSearchKey: 'AssetName'
    contentType: 'text/csv'
    numberOfLinesToSkip: 0
    rawContent: 'AssetName,AssetType,Owner,CriticalityLevel,Location\nDC01,DomainController,IT-Security,Critical,DataCenter-1\nSQL-PROD-01,Database,IT-Database,Critical,DataCenter-1\nFS-FINANCE-01,FileServer,Finance,High,DataCenter-2\nWEB-APP-01,WebServer,IT-Apps,High,Cloud-Azure\nVPN-GATEWAY,NetworkDevice,IT-Network,Critical,DataCenter-1'
  }
}

// Example Watchlist 2: Known Malicious IPs
resource watchlist2 'Microsoft.SecurityInsights/watchlists@2023-02-01' = {
  scope: workspace
  name: 'KnownMaliciousIPs'
  properties: {
    displayName: 'Known Malicious IPs'
    description: 'List of known malicious IP addresses for threat hunting'
    provider: 'Microsoft'
    source: 'Local file'
    itemsSearchKey: 'IPAddress'
    contentType: 'text/csv'
    numberOfLinesToSkip: 0
    rawContent: 'IPAddress,ThreatType,Severity,FirstSeen,Description\n192.0.2.1,Malware,High,2024-01-01,Known malware C2 server\n192.0.2.2,Phishing,Medium,2024-01-05,Phishing campaign infrastructure\n192.0.2.3,Botnet,High,2024-01-10,Botnet command and control\n192.0.2.4,Scanning,Low,2024-01-15,Port scanning activity\n192.0.2.5,Brute-Force,Medium,2024-01-20,Credential stuffing attacks'
  }
}

// Example Watchlist 3: VIP Users
resource watchlist3 'Microsoft.SecurityInsights/watchlists@2023-02-01' = {
  scope: workspace
  name: 'VIPUsers'
  properties: {
    displayName: 'VIP Users'
    description: 'List of VIP users requiring enhanced monitoring'
    provider: 'Microsoft'
    source: 'Local file'
    itemsSearchKey: 'UserPrincipalName'
    contentType: 'text/csv'
    numberOfLinesToSkip: 0
    rawContent: 'UserPrincipalName,Department,Title,RiskLevel,MonitoringLevel\nceo@contoso.com,Executive,CEO,Critical,Enhanced\ncfo@contoso.com,Executive,CFO,Critical,Enhanced\ncto@contoso.com,Executive,CTO,Critical,Enhanced\nadmin@contoso.com,IT,IT Administrator,High,Enhanced\nsecurity@contoso.com,Security,Security Officer,High,Enhanced'
  }
}

// Example Watchlist 4: Allowed External Domains
resource watchlist4 'Microsoft.SecurityInsights/watchlists@2023-02-01' = {
  scope: workspace
  name: 'AllowedExternalDomains'
  properties: {
    displayName: 'Allowed External Domains'
    description: 'List of approved external domains for business operations'
    provider: 'Microsoft'
    source: 'Local file'
    itemsSearchKey: 'Domain'
    contentType: 'text/csv'
    numberOfLinesToSkip: 0
    rawContent: 'Domain,Category,ApprovedBy,ApprovalDate,Purpose\nmicrosoft.com,Partner,IT-Security,2024-01-01,Cloud services\ngithub.com,Development,IT-Development,2024-01-01,Code repository\noffice365.com,Partner,IT-Security,2024-01-01,Office suite\nlinkedin.com,Social,HR,2024-01-05,Professional networking\nslack.com,Communication,IT-Apps,2024-01-10,Team collaboration'
  }
}

// Example Watchlist 5: Service Accounts
resource watchlist5 'Microsoft.SecurityInsights/watchlists@2023-02-01' = {
  scope: workspace
  name: 'ServiceAccounts'
  properties: {
    displayName: 'Service Accounts'
    description: 'List of service accounts and their expected behavior'
    provider: 'Microsoft'
    source: 'Local file'
    itemsSearchKey: 'AccountName'
    contentType: 'text/csv'
    numberOfLinesToSkip: 0
    rawContent: 'AccountName,ServiceType,Owner,ExpectedSource,ExpectedActivity\nsvc-backup,BackupService,IT-Operations,BACKUP-SRV-01,File access\nsvc-monitoring,MonitoringService,IT-Operations,MON-SRV-01,Performance data collection\nsvc-webapp,WebApplication,IT-Apps,WEB-SRV-01,Database queries\nsvc-integration,IntegrationService,IT-Integration,INT-SRV-01,API calls\nsvc-reporting,ReportingService,IT-BI,RPT-SRV-01,Database queries'
  }
}

output watchlist1Id string = watchlist1.id
output watchlist2Id string = watchlist2.id
output watchlist3Id string = watchlist3.id
output watchlist4Id string = watchlist4.id
output watchlist5Id string = watchlist5.id
