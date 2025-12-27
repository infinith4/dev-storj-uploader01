@description('Name of the Azure Container Registry')
param registryName string

@description('Location for all resources')
param location string = resourceGroup().location

@description('ACR SKU (Basic, Standard, Premium)')
param sku string = 'Basic'

@description('Enable admin user for username/password auth')
param adminUserEnabled bool = true

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

output loginServer string = registry.properties.loginServer
output username string = adminUserEnabled ? listCredentials(registry.id, registry.apiVersion).username : ''
output password string = adminUserEnabled ? listCredentials(registry.id, registry.apiVersion).passwords[0].value : ''
