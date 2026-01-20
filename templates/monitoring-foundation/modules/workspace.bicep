targetScope = 'resourceGroup'

@description('Region for the workspace.')
param location string

@description('If not empty, reference this existing workspace. If empty, create a new one.')
param existingWorkspaceResourceId string = ''

@description('Workspace name (used only when creating).')
param workspaceName string

@description('Retention in days (used only when creating).')
param retentionInDays int

// Decide whether to create a workspace.
var createWorkspace = empty(existingWorkspaceResourceId)

// Create workspace only if we were not given an existing resourceId.
// This avoids accidental adoption/changes to shared workspaces.
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2021-06-01' = if (createWorkspace) {
  name: workspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: retentionInDays
  }
}

// Use created workspace id OR the provided existing one.
var workspaceId = createWorkspace ? logAnalytics.id : existingWorkspaceResourceId

output workspaceResourceId string = workspaceId
