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

// Storage Account with File Shares
module storage 'modules/storage.bicep' = {
  name: 'storage'
  params: {
    storageAccountName: replace(storageAccountName, '-', '')
    location: location
    fileShares: [
      'upload-target'
      'uploaded'
      'temp'
      'thumbnail-cache'
    ]
  }
}

// Storage configuration for Container Apps Environment
resource storageConfig 'Microsoft.App/managedEnvironments/storages@2023-05-01' = {
  name: '${environmentName}/upload-target'
  properties: {
    azureFile: {
      accountName: storage.outputs.storageAccountName
      accountKey: storage.outputs.storageAccountKey
      shareName: 'upload-target'
      accessMode: 'ReadWrite'
    }
  }
  dependsOn: [
    environment
  ]
}

resource storageConfigUploaded 'Microsoft.App/managedEnvironments/storages@2023-05-01' = {
  name: '${environmentName}/uploaded'
  properties: {
    azureFile: {
      accountName: storage.outputs.storageAccountName
      accountKey: storage.outputs.storageAccountKey
      shareName: 'uploaded'
      accessMode: 'ReadWrite'
    }
  }
  dependsOn: [
    environment
  ]
}

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
    storageAccountKey: storage.outputs.storageAccountKey
    storjBucketName: storjBucketName
    storjRemoteName: storjRemoteName
    maxFileSize: maxFileSize
    apiBaseUrl: 'https://${backendAppName}.${environment.outputs.defaultDomain}'
  }
  dependsOn: [
    storageConfig
    storageConfigUploaded
    storageConfigTemp
    storageConfigThumbnail
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
    enableManagedIdentity: enableManagedIdentity
    containerRegistryServer: resolvedRegistryServer
    containerRegistryUsername: resolvedRegistryUsername
    containerRegistryPassword: resolvedRegistryPassword
    storageAccountKey: storage.outputs.storageAccountKey
    storjBucketName: storjBucketName
    storjRemoteName: storjRemoteName
    hashLength: hashLength
    maxWorkers: maxWorkers
    rcloneConfig: rcloneConfig
  }
  dependsOn: [
    storageConfig
    storageConfigUploaded
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

// Outputs
output backendApiUrl string = 'https://${backendApi.outputs.fqdn}'
output frontendUrl string = 'https://${frontend.outputs.fqdn}'
output storageAccountName string = storage.outputs.storageAccountName
output environmentName string = environment.outputs.environmentName
output resourceGroupName string = resourceGroup().name
output acrName string = deployAcr ? acrName : ''
output acrLoginServer string = resolvedRegistryServer
