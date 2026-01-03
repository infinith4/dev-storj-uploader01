@description('Name of the Storj Uploader Container App')
param containerAppName string

@description('Location for all resources')
param location string = resourceGroup().location

@description('Container Apps Environment ID')
param environmentId string

@description('Container image')
param containerImage string

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

// Construct connection string for KEDA scaler
var storageConnectionString = 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};AccountKey=${storageAccountKey};EndpointSuffix=core.windows.net'

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

@description('vCPU requested for the Storj uploader container (e.g., 0.5, 1.0)')
param cpu string = '0.5'

@description('Memory requested for the Storj uploader container (e.g., 1.0Gi)')
param memory string = '1.0Gi'

resource storjUploader 'Microsoft.App/containerApps@2023-05-01' = {
  name: containerAppName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    environmentId: environmentId
    configuration: {
      ingress: {
        external: false
        targetPort: 8080
        transport: 'http'
        allowInsecure: true
      }
      secrets: concat(
        [
          {
            name: 'storage-key'
            value: storageAccountKey
          }
          {
            name: 'storage-connection-string'
            value: storageConnectionString
          }
        ],
        useKeyVault && !empty(keyVaultUri)
          ? [
              {
                name: 'rclone-config'
                keyVaultUrl: '${keyVaultUri}secrets/rclone-config'
                identity: 'system'
              }
            ]
          : [
              {
                name: 'rclone-config'
                value: rcloneConfig
              }
            ],
        empty(containerRegistryPassword)
          ? []
          : [
              {
                name: 'registry-password'
                value: containerRegistryPassword
              }
            ]
      )
      registries: empty(containerRegistryServer)
        ? []
        : [
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
            cpu: json(cpu)
            memory: memory
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
            {
              name: 'FILE_SHARE_MOUNT'
              value: '/mnt/temp'
            }
            {
              name: 'PORT'
              value: '8080'
            }
          ]
          volumeMounts: [
            {
              volumeName: 'rclone-config-volume'
              mountPath: '/root/.config/rclone'
            }
            {
              volumeName: 'temp'
              mountPath: '/mnt/temp'
            }
          ]
          command: [
            '/bin/sh'
            '-c'
          ]
          args: [
            'echo "$RCLONE_CONFIG" > /root/.config/rclone/rclone.conf && chmod 600 /root/.config/rclone/rclone.conf && python3 http_processor.py'
          ]
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 3
        rules: [
          {
            name: 'http-scaling'
            http: {
              metadata: {
                concurrentRequests: '1'
              }
            }
          }
        ]
      }
      volumes: [
        {
          name: 'rclone-config-volume'
          storageType: 'EmptyDir'
        }
        {
          name: 'temp'
          storageType: 'AzureFile'
          storageName: 'temp'
        }
      ]
    }
  }
}

output containerAppName string = storjUploader.name
output principalId string = storjUploader.identity.principalId
