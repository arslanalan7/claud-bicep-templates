targetScope = 'resourceGroup'

param location string
param vmName string

@allowed([ 'windows', 'linux' ])
param osType string

@allowed([ 'baseline', 'verbose' ])
param mode string

@description('DCR resourceId to associate this VM with.')
param dcrId string

// Existing VM in the current RG scope
resource vm 'Microsoft.Compute/virtualMachines@2021-11-01' existing = {
  name: vmName
}

// Install Azure Monitor Agent extension (AMA)
resource amaExt 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = {
  parent: vm
  name: osType == 'windows' ? 'AzureMonitorWindowsAgent' : 'AzureMonitorLinuxAgent'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: osType == 'windows' ? 'AzureMonitorWindowsAgent' : 'AzureMonitorLinuxAgent'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {}
  }
}


// Associate the VM to the chosen DCR
// IMPORTANT:
// - Do NOT set properties.resourceId (not supported).
// - The association target is defined by the resource scope (the VM itself).
resource dcrAssoc 'Microsoft.Insights/dataCollectionRuleAssociations@2021-09-01-preview' = {
  name: 'dcr-${mode}-${uniqueString(vm.id, dcrId)}'
  scope: vm
  properties: {
    dataCollectionRuleId: dcrId
    description: 'Associated by monitoring-onboarding Bicep'
  }
}

output vmId string = vm.id
output associationId string = dcrAssoc.id
