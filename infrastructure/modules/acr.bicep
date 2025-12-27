@description('Name of the Azure Container Registry')
param registryName string

@description('Location for all resources')
param location string = resourceGroup().location

@description('ACR SKU (Basic, Standard, Premium)')
param sku string = 'Basic'

@description('Enable admin user for username/password auth')
param adminUserEnabled bool = true

@description('Principal ID (objectId) to grant AcrPush on this ACR. Leave empty to skip.')
param acrPushPrincipalId string = ''

resource registry 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  name: registryName
  location: location
  sku: {
    name: sku
  }
  properties: {
    adminUserEnabled: adminUserEnabled
  }
}

resource acrPushAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(acrPushPrincipalId)) {
  name: guid(registry.id, acrPushPrincipalId, 'AcrPush')
  scope: registry
  properties: {
    principalId: acrPushPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
    principalType: 'ServicePrincipal'
  }
}

output loginServer string = registry.properties.loginServer
output username string = adminUserEnabled ? listCredentials(registry.id, registry.apiVersion).username : ''
output password string = adminUserEnabled ? listCredentials(registry.id, registry.apiVersion).passwords[0].value : ''
