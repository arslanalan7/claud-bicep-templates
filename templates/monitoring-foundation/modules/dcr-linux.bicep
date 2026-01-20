targetScope = 'resourceGroup'

@description('Region for the DCR.')
param location string

@description('DCR name.')
param dcrName string

@description('Log Analytics Workspace resourceId.')
param workspaceResourceId string

@description('baseline = Warning+. verbose = Info/Notice+ (higher volume).')
@allowed([
  'baseline'
  'verbose'
])
param mode string

@description('Performance counter sampling frequency in seconds.')
@minValue(10)
@maxValue(300)
param perfSamplingSeconds int = 30

// Baseline: warning and above.
// Verbose: include Information/Notice for deeper RCA.
var syslogLevels = mode == 'verbose'
  ? [
      'Info'
      'Notice'
      'Warning'
      'Error'
      'Critical'
      'Alert'
      'Emergency'
    ]
  : [
      'Warning'
      'Error'
      'Critical'
      'Alert'
      'Emergency'
    ]

resource dcr 'Microsoft.Insights/dataCollectionRules@2022-06-01' = {
  name: dcrName
  location: location
  properties: {
    dataSources: {
      syslog: [
        {
          name: 'syslog-${mode}'
          streams: [
            'Microsoft-Syslog'
          ]
          // Minimal facilities with strong RCA value.
          facilityNames: [
            'auth'
            'authpriv'
            'kern'
            'daemon'
            'syslog'
            'user'
          ]
          logLevels: syslogLevels
        }
      ]
      performanceCounters: [
        {
          name: 'linuxPerf'
          streams: [
            'Microsoft-Perf'
          ]
          samplingFrequencyInSeconds: perfSamplingSeconds
          // NOTE: Linux perf counters vary by distro/config.
          // Keep minimal; refine after validating ingestion.
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
          'Microsoft-Syslog'
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
