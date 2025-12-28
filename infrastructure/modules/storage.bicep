@description('Name of the Storage Account')
param storageAccountName string

@description('Location for all resources')
param location string = resourceGroup().location

@description('File share names to create (for temp and thumbnail-cache)')
param fileShares array = [
  'temp'
  'thumbnail-cache'
]

@description('Blob container names to create (for upload-target and uploaded)')
param blobContainers array = [
  'upload-target'
  'uploaded'
]

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
  }
}

// Blob Service
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  name: 'default'
  parent: storageAccount
}

// Blob Containers for upload-target and uploaded
resource containers 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = [for container in blobContainers: {
  name: container
  parent: blobService
  properties: {
    publicAccess: 'None'
  }
}]

// File Service
resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2023-01-01' = {
  name: 'default'
  parent: storageAccount
}

// File Shares for temp and thumbnail-cache (still using Azure Files)
resource shares 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = [for share in fileShares: {
  name: share
  parent: fileService
  properties: {
    shareQuota: 100
  }
}]

output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name
output storageAccountKey string = listKeys(storageAccount.id, '2023-01-01').keys[0].value
