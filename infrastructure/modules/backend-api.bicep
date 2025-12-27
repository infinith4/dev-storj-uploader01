@description('Name of the Backend API Container App')
param containerAppName string

@description('Location for all resources')
param location string = resourceGroup().location

@description('Container Apps Environment ID')
param environmentId string

@description('Container image')
param containerImage string

@description('Enable system-assigned managed identity')
param enableManagedIdentity bool = false

@description('Container registry server (e.g., myregistry.azurecr.io). Leave empty for public images')
param containerRegistryServer string = ''

@description('Container registry username')
param containerRegistryUsername string = ''

@description('Container registry password')
@secure()
param containerRegistryPassword string = ''

@description('Storage Account Name')
param storageAccountName string

@description('Storage Account Key')
@secure()
param storageAccountKey string

@description('Storj Bucket Name')
param storjBucketName string

@description('Storj Remote Name')
param storjRemoteName string = 'storj'

@description('Max file size in bytes')
param maxFileSize int = 100000000

@description('API Base URL for generating image URLs')
param apiBaseUrl string

resource backendApi 'Microsoft.App/containerApps@2023-05-01' = {
  name: containerAppName
  location: location
  properties: {
    environmentId: environmentId
    configuration: {
      ingress: {
        external: true
        targetPort: 8010
        transport: 'http'
        allowInsecure: false
        corsPolicy: {
          allowedOrigins: [
            '*'
          ]
          allowedMethods: [
            'GET'
            'POST'
            'PUT'
            'DELETE'
            'OPTIONS'
          ]
          allowedHeaders: [
            '*'
          ]
        }
      }
      secrets: [
        {
          name: 'storage-key'
          value: storageAccountKey
        }
        if (!empty(containerRegistryPassword)) {
          name: 'registry-password'
          value: containerRegistryPassword
        }
      ]
      registries: empty(containerRegistryServer) ? [] : [
        {
          server: containerRegistryServer
          username: containerRegistryUsername
          passwordSecretRef: 'registry-password'
        }
      ]
    }
    identity: enableManagedIdentity ? {
      type: 'SystemAssigned'
    } : null
    template: {
      containers: [
        {
          name: 'backend-api'
          image: containerImage
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
          env: [
            {
              name: 'UPLOAD_TARGET_DIR'
              value: '/mnt/upload-target'
            }
            {
              name: 'TEMP_DIR'
              value: '/mnt/temp'
            }
            {
              name: 'MAX_FILE_SIZE'
              value: string(maxFileSize)
            }
            {
              name: 'STORJ_BUCKET_NAME'
              value: storjBucketName
            }
            {
              name: 'STORJ_REMOTE_NAME'
              value: storjRemoteName
            }
            {
              name: 'API_HOST'
              value: '0.0.0.0'
            }
            {
              name: 'API_PORT'
              value: '8010'
            }
            {
              name: 'API_BASE_URL'
              value: apiBaseUrl
            }
          ]
          volumeMounts: [
            {
              volumeName: 'temp'
              mountPath: '/mnt/temp'
            }
            {
              volumeName: 'thumbnail-cache'
              mountPath: '/app/thumbnail_cache'
            }
            {
              volumeName: 'upload-target'
              mountPath: '/mnt/upload-target'
            }
            {
              volumeName: 'uploaded'
              mountPath: '/mnt/uploaded'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
      volumes: [
        {
          name: 'temp'
          storageType: 'AzureFile'
          storageName: 'temp'
        }
        {
          name: 'thumbnail-cache'
          storageType: 'AzureFile'
          storageName: 'thumbnail-cache'
        }
        {
          name: 'upload-target'
          storageType: 'AzureFile'
          storageName: 'upload-target'
        }
        {
          name: 'uploaded'
          storageType: 'AzureFile'
          storageName: 'uploaded'
        }
      ]
    }
  }
}

output fqdn string = backendApi.properties.configuration.ingress.fqdn
output containerAppName string = backendApi.name
