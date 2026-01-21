targetScope = 'subscription'

@description('Azure region (used for the AMA extension resource location).')
param location string = 'westeurope'

@description('Windows baseline DCR resourceId (from foundation outputs).')
param dcrWindowsBaselineId string

@description('Windows verbose DCR resourceId (from foundation outputs).')
param dcrWindowsVerboseId string

@description('Linux baseline DCR resourceId (from foundation outputs).')
param dcrLinuxBaselineId string

@description('Linux verbose DCR resourceId (from foundation outputs).')
param dcrLinuxVerboseId string

@description('Default collection mode when not specified per target.')
@allowed([ 'baseline', 'verbose' ])
param defaultMode string = 'baseline'

@description('Allow verbose mode. If false, any verbose request will be forced to baseline (guardrail).')
param allowVerbose bool = true

@description('List of VM targets to onboard. Each item must include rgName, vmName, osType, and optionally mode.')
param targets array


// Normalize targets by computing an effective mode for each item.
// - If t.mode is empty -> defaultMode
// - If allowVerbose == false -> force baseline
var normalizedTargets = [
  for t in targets: union(t, {
    effectiveMode: allowVerbose
      ? (empty(t.mode) ? defaultMode : t.mode)
      : 'baseline'
  })
]

module onboard './modules/onboard-vm.bicep' = [for (t, i) in normalizedTargets: {
  name: 'onboard-${i}-${uniqueString(subscription().id, t.rgName, t.vmName)}'
  scope: resourceGroup(t.rgName)
  params: {
    location: location
    vmName: t.vmName
    osType: t.osType
    mode: t.effectiveMode
    dcrId: t.osType == 'windows'
      ? (t.effectiveMode == 'verbose' ? dcrWindowsVerboseId : dcrWindowsBaselineId)
      : (t.effectiveMode == 'verbose' ? dcrLinuxVerboseId : dcrLinuxBaselineId)
  }
}]

output onboarded array = [for t in normalizedTargets: {
  rgName: t.rgName
  vmName: t.vmName
  osType: t.osType
  mode: t.effectiveMode
}]
