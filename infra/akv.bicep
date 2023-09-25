targetScope = 'resourceGroup'

@description('The location the resource should deployed to. Defaults to resource group location.')
param location string = resourceGroup().location

@allowed(['Enabled','Disabled'])
@description('Property to specify whether the vault will accept traffic from public internet. If set to \'disabled\' all traffic except private endpoint traffic and that that originates from trusted services will be blocked. This will override the set firewall rules, meaning that even if the firewall rules are present we will not honor the rules.')
param publicNetworkAccess string = 'Disabled'

@allowed(['User', 'ServicePrincipal'])
param principalType string = 'ServicePrincipal'

param deploymentAgentPrincipalId string

var suffix = uniqueString(subscription().id, resourceGroup().id)

resource vault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: 'vault${suffix}'
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'premium'
    }
    tenantId: subscription().tenantId
    accessPolicies: []
    enableRbacAuthorization: true
    publicNetworkAccess: publicNetworkAccess
  }
}

@description('This is the built-in Secret Officer role. See https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles')
resource secretOfficer 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'
}

resource secretAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(vault.id, deploymentAgentPrincipalId, 'reader')
  properties: {
    principalId: deploymentAgentPrincipalId
    roleDefinitionId: secretOfficer.id
    principalType: principalType
  }
  scope: vault
}

output id string = vault.id
output name string = vault.name
