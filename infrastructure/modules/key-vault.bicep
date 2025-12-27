@description('Name of the Key Vault')
param keyVaultName string

@description('Location for all resources')
param location string = resourceGroup().location

@description('Tenant ID for the Key Vault')
param tenantId string = tenant().tenantId

@description('Enable public network access')
param publicNetworkAccess string = 'Enabled'

@description('Principal IDs to grant Key Vault Secrets User role')
param secretsUserPrincipalIds array = []

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: tenantId
    enableRbacAuthorization: true
    publicNetworkAccess: publicNetworkAccess
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

// Key Vault Secrets User role definition ID
var keyVaultSecretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'

// Grant Key Vault Secrets User role to specified principals
resource secretsUserRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (principalId, i) in secretsUserPrincipalIds: {
  name: guid(keyVault.id, principalId, keyVaultSecretsUserRoleId)
  scope: keyVault
  properties: {
    principalId: principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsUserRoleId)
    principalType: 'ServicePrincipal'
  }
}]

output keyVaultName string = keyVault.name
output keyVaultId string = keyVault.id
output keyVaultUri string = keyVault.properties.vaultUri
