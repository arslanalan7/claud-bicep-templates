targetScope = 'resourceGroup'

@description('Region for the DCR.')
param location string

@description('DCR name.')
param dcrName string

@description('Log Analytics Workspace resourceId.')
param workspaceResourceId string

@description('baseline = Error/Critical only. verbose = Warning+Error+Critical.')
@allowed([
  'baseline'
  'verbose'
])
param mode string = 'baseline'

var perfCounters = mode == 'verbose'
  ? [
      '\\Processor(_Total)\\% Processor Time'
      '\\Process(*)\\% Processor Time'
      '\\Memory\\Available MBytes'
      '\\Memory\\% Committed Bytes In Use'
      '\\Memory\\Page Faults/sec'
      '\\LogicalDisk(*)\\Free Megabytes'
      '\\LogicalDisk(*)\\% Free Space'
      '\\LogicalDisk(*)\\Avg. Disk sec/Read'
      '\\LogicalDisk(*)\\Disk Reads/sec'
      '\\LogicalDisk(*)\\Avg. Disk sec/Write'
      '\\LogicalDisk(*)\\Disk Writes/sec'
      '\\Network Adapter(*)\\Bytes Sent/sec'
      '\\Network Adapter(*)\\Bytes Received/sec'
      '\\System\\Processor Queue Length'
    ]
  : [
      '\\Processor(_Total)\\% Processor Time'
      '\\Memory\\Available MBytes'
      '\\Memory\\% Committed Bytes In Use'
      '\\LogicalDisk(*)\\Free Megabytes'
      '\\LogicalDisk(*)\\% Free Space'
      '\\Network Interface(*)\\Bytes Total/sec'
      '\\System\\Processor Queue Length'
    ]

@description('Performance counter sampling frequency in seconds.')
@minValue(10)
@maxValue(300)
param perfSamplingSeconds int = 30

// Strict baseline: Level 1(Critical) + 2(Error)
// Verbose: add Level 3(Warning) during incidents.
var levelFilter = mode == 'verbose'
  ? '(Level=1 or Level=2 or Level=3)'
  : '(Level=1 or Level=2)'

resource dcr 'Microsoft.Insights/dataCollectionRules@2022-06-01' = {
  name: dcrName
  location: location
  properties: {
    dataSources: {
      windowsEventLogs: [
        {
          name: 'winEvents-${mode}'
          streams: [
            'Microsoft-Event'
          ]
          // We intentionally avoid Security log here (high volume/cost + separate governance).
          xPathQueries: [
            'System!*[System[${levelFilter}]]'
            'Application!*[System[${levelFilter}]]'
          ]
        }
      ]
      performanceCounters: [
        {
          name: 'winPerf'
          streams: [
            'Microsoft-Perf'
          ]
          samplingFrequencyInSeconds: perfSamplingSeconds
          // Keep minimal: KPI + first-pass RCA.
          counterSpecifiers: perfCounters
        }
      ]
    }
    destinations: {
      logAnalytics: [
        {
          name: 'la'
          workspaceResourceId: workspaceResourceId
        }
      ]
    }
    dataFlows: [
      {
        streams: [
          'Microsoft-Event'
          'Microsoft-Perf'
          'Microsoft-Heartbeat'
        ]
        destinations: [
          'la'
        ]
      }
    ]
  }
}

output dcrResourceId string = dcr.id
