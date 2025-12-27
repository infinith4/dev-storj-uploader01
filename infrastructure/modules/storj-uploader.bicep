@description('Name of the Storj Uploader Container App')
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

@description('Storage Account Key')
@secure()
param storageAccountKey string

@description('Storj Bucket Name')
param storjBucketName string

@description('Storj Remote Name')
param storjRemoteName string = 'storj'

@description('Hash length for deduplication')
param hashLength int = 10

@description('Max workers for parallel upload')
param maxWorkers int = 8

@description('Key Vault URI for secrets')
param keyVaultUri string = ''

@description('Use Key Vault for rclone config')
param useKeyVault bool = true

@description('rclone.conf content (fallback if not using Key Vault)')
@secure()
param rcloneConfig string = ''

resource storjUploader 'Microsoft.App/containerApps@2023-05-01' = {
  name: containerAppName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    environmentId: environmentId
    configuration: {
      secrets: concat([
        {
          name: 'storage-key'
          value: storageAccountKey
        }
      ], useKeyVault && !empty(keyVaultUri) ? [
        {
          name: 'rclone-config'
          keyVaultUrl: '${keyVaultUri}secrets/rclone-config'
          identity: 'system'
        }
      ] : [
        {
          name: 'rclone-config'
          value: rcloneConfig
        }
      ], empty(containerRegistryPassword) ? [] : [
        {
          name: 'registry-password'
          value: containerRegistryPassword
        }
      ])
      registries: empty(containerRegistryServer) ? [] : [
        {
          server: containerRegistryServer
          username: containerRegistryUsername
          passwordSecretRef: 'registry-password'
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'storj-uploader'
          image: containerImage
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
          env: [
            {
              name: 'STORJ_BUCKET_NAME'
              value: storjBucketName
            }
            {
              name: 'STORJ_REMOTE_NAME'
              value: storjRemoteName
            }
            {
              name: 'HASH_LENGTH'
              value: string(hashLength)
            }
            {
              name: 'MAX_WORKERS'
              value: string(maxWorkers)
            }
            {
              name: 'RCLONE_CONFIG'
              secretRef: 'rclone-config'
            }
          ]
          volumeMounts: [
            {
              volumeName: 'upload-target'
              mountPath: '/app/upload_target'
            }
            {
              volumeName: 'uploaded'
              mountPath: '/app/uploaded'
            }
            {
              volumeName: 'rclone-config-volume'
              mountPath: '/root/.config/rclone'
            }
          ]
          command: [
            '/bin/sh'
            '-c'
          ]
          args: [
            'echo "$RCLONE_CONFIG" > /root/.config/rclone/rclone.conf && chmod 600 /root/.config/rclone/rclone.conf && python3 storj_uploader.py'
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
      volumes: [
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
        {
          name: 'rclone-config-volume'
          storageType: 'EmptyDir'
        }
      ]
    }
  }
}

output containerAppName string = storjUploader.name
output principalId string = storjUploader.identity.principalId
