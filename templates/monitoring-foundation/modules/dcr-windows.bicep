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
param mode string

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
          counterSpecifiers: [
            '\\Processor(_Total)\\% Processor Time'
            '\\Memory\\Available MBytes'
            '\\LogicalDisk(*)\\Free Megabytes'
            '\\LogicalDisk(*)\\% Free Space'
          ]
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
        ]
        destinations: [
          'la'
        ]
      }
    ]
  }
}

output dcrResourceId string = dcr.id
