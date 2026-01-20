targetScope = 'subscription'

@description('Azure region for monitoring resources.')
param location string = 'westeurope'

@description('Resource group where the monitoring foundation will live.')
param monitoringRgName string

@description('If provided, use this existing workspace resourceId. If empty, create a new workspace.')
param existingWorkspaceResourceId string = ''

@description('Workspace name (used only when existingWorkspaceResourceId is empty).')
param workspaceName string = 'log-prod-ws'

@description('Retention in days for a newly created workspace.')
@minValue(30)
@maxValue(730)
param retentionInDays int = 30

@description('Windows DCR base name. Suffixes -baseline / -verbose will be added.')
param dcrWindowsBaseName string = 'dcr-windows'

@description('Linux DCR base name. Suffixes -baseline / -verbose will be added.')
param dcrLinuxBaseName string = 'dcr-linux'

@description('Sampling frequency for baseline perf counters (seconds).')
@minValue(10)
@maxValue(300)
param perfSamplingBaselineSeconds int = 30

@description('Sampling frequency for verbose perf counters (seconds).')
@minValue(10)
@maxValue(300)
param perfSamplingVerboseSeconds int = 15

// 1) Workspace: create or reference existing
module workspaceMod './modules/workspace.bicep' = {
  name: 'foundation-workspace-${uniqueString(subscription().id, monitoringRgName)}'
  scope: resourceGroup(monitoringRgName)
  params: {
    location: location
    existingWorkspaceResourceId: existingWorkspaceResourceId
    workspaceName: workspaceName
    retentionInDays: retentionInDays
  }
}

// 2) Windows DCRs: baseline + verbose
module dcrWinBaseline './modules/dcr-windows.bicep' = {
  name: 'foundation-dcr-win-baseline-${uniqueString(subscription().id, monitoringRgName)}'
  scope: resourceGroup(monitoringRgName)
  params: {
    location: location
    dcrName: '${dcrWindowsBaseName}-baseline'
    workspaceResourceId: workspaceMod.outputs.workspaceResourceId
    mode: 'baseline'
    perfSamplingSeconds: perfSamplingBaselineSeconds
  }
}

module dcrWinVerbose './modules/dcr-windows.bicep' = {
  name: 'foundation-dcr-win-verbose-${uniqueString(subscription().id, monitoringRgName)}'
  scope: resourceGroup(monitoringRgName)
  params: {
    location: location
    dcrName: '${dcrWindowsBaseName}-verbose'
    workspaceResourceId: workspaceMod.outputs.workspaceResourceId
    mode: 'verbose'
    perfSamplingSeconds: perfSamplingVerboseSeconds
  }
}

// 3) Linux DCRs: baseline + verbose
module dcrLinuxBaseline './modules/dcr-linux.bicep' = {
  name: 'foundation-dcr-linux-baseline-${uniqueString(subscription().id, monitoringRgName)}'
  scope: resourceGroup(monitoringRgName)
  params: {
    location: location
    dcrName: '${dcrLinuxBaseName}-baseline'
    workspaceResourceId: workspaceMod.outputs.workspaceResourceId
    mode: 'baseline'
    perfSamplingSeconds: perfSamplingBaselineSeconds
  }
}

module dcrLinuxVerbose './modules/dcr-linux.bicep' = {
  name: 'foundation-dcr-linux-verbose-${uniqueString(subscription().id, monitoringRgName)}'
  scope: resourceGroup(monitoringRgName)
  params: {
    location: location
    dcrName: '${dcrLinuxBaseName}-verbose'
    workspaceResourceId: workspaceMod.outputs.workspaceResourceId
    mode: 'verbose'
    perfSamplingSeconds: perfSamplingVerboseSeconds
  }
}

// Outputs: these are the contract for onboarding packages.
output workspaceResourceId string = workspaceMod.outputs.workspaceResourceId
output dcrWindowsBaselineId string = dcrWinBaseline.outputs.dcrResourceId
output dcrWindowsVerboseId string = dcrWinVerbose.outputs.dcrResourceId
output dcrLinuxBaselineId string = dcrLinuxBaseline.outputs.dcrResourceId
output dcrLinuxVerboseId string = dcrLinuxVerbose.outputs.dcrResourceId
