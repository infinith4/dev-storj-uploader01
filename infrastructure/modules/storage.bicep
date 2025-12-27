@description('Name of the Storage Account')
param storageAccountName string

@description('Location for all resources')
param location string = resourceGroup().location

@description('File share names to create')
param fileShares array = [
  'upload-target'
  'uploaded'
  'temp'
  'thumbnail-cache'
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
  }
}

resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2023-01-01' = {
  name: 'default'
  parent: storageAccount
}

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
