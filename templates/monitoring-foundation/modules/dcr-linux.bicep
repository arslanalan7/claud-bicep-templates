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
param mode string = 'baseline'

var perfCountersLinux = mode == 'verbose'
  ? [
      'Processor(*)\\% Processor Time'
      'Processor(*)\\% IO Wait Time'
      'Memory(*)\\Available MBytes Memory'
      'Memory(*)\\% Available Memory'
      'Memory(*)\\Pages/sec'
      'Memory(*)\\Page Reads/sec'
      'Memory(*)\\Page Writes/sec'
      'Memory(*)\\Available MBytes Swap'
      'Memory(*)\\% Available Swap Space'
      'Process(*)\\Pct User Time'
      'Process(*)\\Pct Privileged Time'
      'Logical Disk(*)\\% Free Space'
      'Logical Disk(*)\\Free Megabytes'
      'Logical Disk(*)\\Disk Reads/sec'
      'Logical Disk(*)\\Disk Writes/sec'
      'Network(*)\\Total Bytes Transmitted'
      'Network(*)\\Total Bytes Received'
      'System(*)\\Load1'
      'System(*)\\Load5'
      'System(*)\\Load15'
      'System(*)\\Users'
    ]
  : [
      'Processor(*)\\% Processor Time'
      'Memory(*)\\Available MBytes Memory'
      'Memory(*)\\Available MBytes Swap'
      'Logical Disk(*)\\% Free Space'
      'Network(*)\\Total Bytes'
      'System(*)\\Load5'
    ]

var facilityNamesLinux = mode == 'verbose'
  ? [
      'auth'
      'authpriv'
      'kern'
      'daemon'
      'syslog'
      'user'
    ]
  : [
      'auth'
      'authpriv'
      'syslog'
      'user'
    ]

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
          facilityNames: facilityNamesLinux
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
          counterSpecifiers: perfCountersLinux
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
