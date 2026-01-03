@description('Name of the Frontend Container App')
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

@description('Backend API URL')
param backendApiUrl string

@description('Enable Azure AD EasyAuth for the frontend')
param enableAadAuth bool = false

@description('vCPU requested for the frontend container (e.g., 0.5, 1.0)')
param cpu string = '0.5'

@description('Memory requested for the frontend container (e.g., 1.0Gi)')
param memory string = '1.0Gi'

@description('Azure AD tenant ID')
param aadTenantId string = ''

@description('Azure AD application (client) ID')
param aadClientId string = ''

@description('Azure AD client secret')
@secure()
param aadClientSecret string = ''

@description('Azure AD OpenID issuer (v1: https://sts.windows.net/<tenant-id>/, v2: https://login.microsoftonline.com/<tenant-id>/v2.0)')
param aadOpenIdIssuer string = ''

@description('Allowed audiences for AAD tokens (defaults to client ID)')
param aadAllowedAudiences array = []

var resolvedAadOpenIdIssuer = empty(aadOpenIdIssuer)
  ? 'https://login.microsoftonline.com/${aadTenantId}/v2.0'
  : aadOpenIdIssuer
var resolvedAadAllowedAudiences = empty(aadAllowedAudiences)
  ? [
      aadClientId
    ]
  : aadAllowedAudiences

resource frontend 'Microsoft.App/containerApps@2023-05-01' = {
  name: containerAppName
  location: location
  identity: enableManagedIdentity
    ? {
        type: 'SystemAssigned'
      }
    : null
  properties: {
    environmentId: environmentId
    configuration: {
      ingress: {
        external: true
        targetPort: 9010
        transport: 'http'
        allowInsecure: false
      }
      registries: empty(containerRegistryServer)
        ? []
        : [
            {
              server: containerRegistryServer
              username: containerRegistryUsername
              passwordSecretRef: 'registry-password'
            }
          ]
      secrets: concat(
        empty(containerRegistryPassword)
          ? []
          : [
              {
                name: 'registry-password'
                value: containerRegistryPassword
              }
            ],
        enableAadAuth
          ? [
              {
                name: 'aad-client-secret'
                value: aadClientSecret
              }
            ]
          : []
      )
    }
    template: {
      containers: [
        {
          name: 'frontend'
          image: containerImage
          resources: {
            cpu: json(cpu)
            memory: memory
          }
          env: [
            {
              name: 'REACT_APP_API_URL'
              value: backendApiUrl
            }
            {
              name: 'BACKEND_URL'
              value: backendApiUrl
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
}

resource frontendAuth 'Microsoft.App/containerApps/authConfigs@2023-05-01' = if (enableAadAuth) {
  name: 'current'
  parent: frontend
  properties: {
    platform: {
      enabled: true
    }
    globalValidation: {
      unauthenticatedClientAction: 'RedirectToLoginPage'
      redirectToProvider: 'azureActiveDirectory'
    }
    identityProviders: {
      azureActiveDirectory: {
        enabled: true
        registration: {
          clientId: aadClientId
          clientSecretSettingName: 'aad-client-secret'
          openIdIssuer: resolvedAadOpenIdIssuer
        }
        validation: {
          allowedAudiences: resolvedAadAllowedAudiences
        }
      }
    }
    login: {
      preserveUrlFragmentsForLogins: true
    }
  }
}

output fqdn string = frontend.properties.configuration.ingress.fqdn
output containerAppName string = frontend.name
