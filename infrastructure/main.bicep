targetScope = 'resourceGroup'

@description('Base name for all resources')
param baseName string

@description('Location for all resources')
param location string = resourceGroup().location

@description('Backend API container image')
param backendContainerImage string

@description('Frontend container image')
param frontendContainerImage string

@description('Storj Uploader container image')
param storjContainerImage string

@description('Container registry server (e.g., myregistry.azurecr.io). Leave empty for public images')
param containerRegistryServer string = ''

@description('Container registry username')
param containerRegistryUsername string = ''

@description('Container registry password')
@secure()
param containerRegistryPassword string = ''

@description('Deploy Azure Container Registry (ACR)')
param deployAcr bool = false

@description('ACR SKU (Basic, Standard, Premium)')
param acrSku string = 'Basic'

@description('Enable admin user for ACR (required for username/password auth)')
param acrAdminUserEnabled bool = true

@description('Principal ID (objectId) to grant AcrPush on the ACR. Leave empty to skip.')
param acrPushPrincipalId string = ''

@description('Principal ID (objectId) to grant Contributor role on the resource group for Container Apps management. Leave empty to skip.')
param contributorPrincipalId string = ''

@description('Enable system-assigned managed identity for Container Apps')
param enableManagedIdentity bool = false

@description('Storj Bucket Name')
param storjBucketName string

@description('Storj Remote Name')
param storjRemoteName string = 'storj'

@description('rclone.conf content')
@secure()
param rcloneConfig string

@description('Max file size in bytes')
param maxFileSize int = 100000000

@description('Hash length for deduplication')
param hashLength int = 10

@description('Max workers for parallel upload')
param maxWorkers int = 8

// Unique names
var uniqueSuffix = uniqueString(resourceGroup().id)
var logAnalyticsName = '${baseName}-logs-${uniqueSuffix}'
var environmentName = '${baseName}-env-${uniqueSuffix}'
var storageAccountName = '${baseName}st${uniqueSuffix}'
var acrName = toLower(replace('${baseName}acr${uniqueSuffix}', '-', ''))
var backendAppName = '${baseName}-backend-${uniqueSuffix}'
var frontendAppName = '${baseName}-frontend-${uniqueSuffix}'
var storjAppName = '${baseName}-storj-${uniqueSuffix}'
var keyVaultName = '${baseName}-kv-${uniqueSuffix}'

// Key Vault
module keyVault 'modules/key-vault.bicep' = {
  name: 'keyVault'
  params: {
    keyVaultName: keyVaultName
    location: location
    secretsUserPrincipalIds: []
  }
}

// Log Analytics Workspace
module logAnalytics 'modules/log-analytics.bicep' = {
  name: 'logAnalytics'
  params: {
    workspaceName: logAnalyticsName
    location: location
  }
}

// Container Apps Environment
module environment 'modules/environment.bicep' = {
  name: 'environment'
  params: {
    environmentName: environmentName
    location: location
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
  }
}

// Azure Container Registry (optional)
module acr 'modules/acr.bicep' = if (deployAcr) {
  name: 'acr'
  params: {
    registryName: acrName
    location: location
    sku: acrSku
    adminUserEnabled: acrAdminUserEnabled
    acrPushPrincipalId: acrPushPrincipalId
  }
}

var resolvedRegistryServer = deployAcr ? acr.outputs.loginServer : containerRegistryServer
var resolvedRegistryUsername = deployAcr ? acr.outputs.username : containerRegistryUsername
var resolvedRegistryPassword = deployAcr ? acr.outputs.password : containerRegistryPassword

// Storage Account with Blob Containers and File Shares
module storage 'modules/storage.bicep' = {
  name: 'storage'
  params: {
    storageAccountName: replace(storageAccountName, '-', '')
    location: location
    fileShares: [
      'temp'
      'thumbnail-cache'
    ]
    blobContainers: [
      'upload-target'
      'uploaded'
    ]
  }
}

// Storage configuration for Container Apps Environment (File Shares only)

resource storageConfigTemp 'Microsoft.App/managedEnvironments/storages@2023-05-01' = {
  name: '${environmentName}/temp'
  properties: {
    azureFile: {
      accountName: storage.outputs.storageAccountName
      accountKey: storage.outputs.storageAccountKey
      shareName: 'temp'
      accessMode: 'ReadWrite'
    }
  }
  dependsOn: [
    environment
  ]
}

resource storageConfigThumbnail 'Microsoft.App/managedEnvironments/storages@2023-05-01' = {
  name: '${environmentName}/thumbnail-cache'
  properties: {
    azureFile: {
      accountName: storage.outputs.storageAccountName
      accountKey: storage.outputs.storageAccountKey
      shareName: 'thumbnail-cache'
      accessMode: 'ReadWrite'
    }
  }
  dependsOn: [
    environment
  ]
}

// Backend API Container App
module backendApi 'modules/backend-api.bicep' = {
  name: 'backendApi'
  params: {
    containerAppName: backendAppName
    location: location
    environmentId: environment.outputs.environmentId
    containerImage: backendContainerImage
    enableManagedIdentity: enableManagedIdentity
    containerRegistryServer: resolvedRegistryServer
    containerRegistryUsername: resolvedRegistryUsername
    containerRegistryPassword: resolvedRegistryPassword
    storageAccountName: storage.outputs.storageAccountName
    storageAccountKey: storage.outputs.storageAccountKey
    keyVaultUri: keyVault.outputs.keyVaultUri
    useKeyVault: true  // Key Vaultからrclone.confを読み込む
    rcloneConfig: rcloneConfig
    storjBucketName: storjBucketName
    storjRemoteName: storjRemoteName
    maxFileSize: maxFileSize
    apiBaseUrl: 'https://${backendAppName}.${environment.outputs.defaultDomain}'
  }
  dependsOn: [
    storageConfigTemp
    storageConfigThumbnail
    storage
  ]
}

// Grant Key Vault Secrets User role to Backend API Managed Identity
resource backendKeyVaultAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, keyVaultName, backendAppName, 'KeyVaultSecretsUser')
  scope: resourceGroup()
  properties: {
    principalId: backendApi.outputs.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
    principalType: 'ServicePrincipal'
  }
  dependsOn: [
    backendApi
    keyVault
  ]
}

// Storj Uploader Container App
module storjUploader 'modules/storj-uploader.bicep' = {
  name: 'storjUploader'
  params: {
    containerAppName: storjAppName
    location: location
    environmentId: environment.outputs.environmentId
    containerImage: storjContainerImage
    containerRegistryServer: resolvedRegistryServer
    containerRegistryUsername: resolvedRegistryUsername
    containerRegistryPassword: resolvedRegistryPassword
    storageAccountName: storage.outputs.storageAccountName
    storageAccountKey: storage.outputs.storageAccountKey
    storjBucketName: storjBucketName
    storjRemoteName: storjRemoteName
    hashLength: hashLength
    maxWorkers: maxWorkers
    keyVaultUri: keyVault.outputs.keyVaultUri
    useKeyVault: true  // Key Vaultからrclone.confを読み込む
    rcloneConfig: rcloneConfig
  }
  dependsOn: [
    storage
  ]
}

// Grant Key Vault Secrets User role to Storj Uploader Managed Identity
resource storjKeyVaultAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, keyVaultName, storjAppName, 'KeyVaultSecretsUser')
  scope: resourceGroup()
  properties: {
    principalId: storjUploader.outputs.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
    principalType: 'ServicePrincipal'
  }
  dependsOn: [
    storjUploader
    keyVault
  ]
}

// Frontend Container App
module frontend 'modules/frontend.bicep' = {
  name: 'frontend'
  params: {
    containerAppName: frontendAppName
    location: location
    environmentId: environment.outputs.environmentId
    containerImage: frontendContainerImage
    enableManagedIdentity: enableManagedIdentity
    containerRegistryServer: resolvedRegistryServer
    containerRegistryUsername: resolvedRegistryUsername
    containerRegistryPassword: resolvedRegistryPassword
    backendApiUrl: 'https://${backendApi.outputs.fqdn}'
  }
}

// Grant Contributor role to Service Principal for Container Apps management
// Note: ロール割り当てが既に存在する場合はスキップされます
resource contributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(contributorPrincipalId)) {
  name: guid(resourceGroup().id, contributorPrincipalId, 'Contributor', subscription().subscriptionId)
  scope: resourceGroup()
  properties: {
    principalId: contributorPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')
    principalType: 'ServicePrincipal'
  }
}

// Outputs
output backendApiUrl string = 'https://${backendApi.outputs.fqdn}'
output frontendUrl string = 'https://${frontend.outputs.fqdn}'
output storageAccountName string = storage.outputs.storageAccountName
output environmentName string = environment.outputs.environmentName
output resourceGroupName string = resourceGroup().name
output acrName string = deployAcr ? acrName : ''
output acrLoginServer string = resolvedRegistryServer
