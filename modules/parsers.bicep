// Bicep module for deploying Sentinel Parsers (Saved Functions)
@description('The name of the Log Analytics workspace')
param workspaceName string

// Reference to existing workspace
resource workspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: workspaceName
}

// Example Parser 1: Custom Syslog Parser
resource parser1 'Microsoft.OperationalInsights/workspaces/savedSearches@2020-08-01' = {
  parent: workspace
  name: 'CustomSyslogParser'
  properties: {
    category: 'Parser'
    displayName: 'Custom Syslog Parser'
    query: '''
      Syslog
      | extend ParsedMessage = parse_json(SyslogMessage)
      | extend 
          EventType = tostring(ParsedMessage.type),
          EventSeverity = tostring(ParsedMessage.severity),
          EventSource = tostring(ParsedMessage.source),
          EventDetails = tostring(ParsedMessage.details)
      | project TimeGenerated, Computer, EventType, EventSeverity, EventSource, EventDetails, SyslogMessage
    '''
    functionAlias: 'CustomSyslogParser'
    functionParameters: ''
    version: 2
  }
}

// Example Parser 2: Web Access Log Parser
resource parser2 'Microsoft.OperationalInsights/workspaces/savedSearches@2020-08-01' = {
  parent: workspace
  name: 'WebAccessLogParser'
  properties: {
    category: 'Parser'
    displayName: 'Web Access Log Parser'
    query: '''
      CommonSecurityLog
      | where DeviceVendor == "WebServer"
      | extend 
          ClientIP = SourceIP,
          RequestedURL = RequestURL,
          HTTPMethod = RequestMethod,
          StatusCode = toint(DeviceCustomNumber1),
          BytesSent = toint(SentBytes),
          UserAgent = DeviceCustomString1
      | project TimeGenerated, ClientIP, RequestedURL, HTTPMethod, StatusCode, BytesSent, UserAgent
    '''
    functionAlias: 'WebAccessLogParser'
    functionParameters: ''
    version: 2
  }
}

// Example Parser 3: Azure Activity Parser with enrichment
resource parser3 'Microsoft.OperationalInsights/workspaces/savedSearches@2020-08-01' = {
  parent: workspace
  name: 'EnrichedAzureActivity'
  properties: {
    category: 'Parser'
    displayName: 'Enriched Azure Activity Parser'
    query: '''
      AzureActivity
      | extend 
          Action = OperationNameValue,
          Result = ActivityStatusValue,
          ResourceType = split(ResourceId, "/")[6],
          ResourceName = split(ResourceId, "/")[-1],
          RiskLevel = case(
              ActivityStatusValue == "Failure", "High",
              OperationNameValue has_any ("delete", "remove"), "Medium",
              "Low"
          )
      | project TimeGenerated, Caller, Action, Result, ResourceType, ResourceName, RiskLevel, ResourceGroup, SubscriptionId
    '''
    functionAlias: 'EnrichedAzureActivity'
    functionParameters: ''
    version: 2
  }
}

output parser1Id string = parser1.id
output parser2Id string = parser2.id
output parser3Id string = parser3.id
