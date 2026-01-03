@description('Name of the Flutter Web Container App')
param containerAppName string

@description('Location for all resources')
param location string = resourceGroup().location

@description('Container Apps Environment ID')
param environmentId string

@description('Container image')
param containerImage string

@description('Enable system-assigned managed identity')
param enableManagedIdentity bool = false

// Note: Flutter web apps are static sites served by nginx.
// The API_BASE_URL must be set at Docker build time using --build-arg API_BASE_URL=...
// See .github/workflows/build-and-push-acr.yml for build configuration.
// The following parameter is for documentation/reference only and is not used at runtime.
@description('Backend API URL (for reference only - must be set at build time)')
param backendApiUrl string = ''

@description('Container registry server (e.g., myregistry.azurecr.io). Leave empty for public images')
param containerRegistryServer string = ''

@description('Container registry username')
param containerRegistryUsername string = ''

@description('Container registry password')
@secure()
param containerRegistryPassword string = ''

@description('Enable Azure AD EasyAuth for the Flutter web app')
param enableAadAuth bool = false

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

var resolvedAadOpenIdIssuer = empty(aadOpenIdIssuer) ? 'https://login.microsoftonline.com/${aadTenantId}/v2.0' : aadOpenIdIssuer
var resolvedAadAllowedAudiences = empty(aadAllowedAudiences) ? [
  aadClientId
] : aadAllowedAudiences

resource flutterWeb 'Microsoft.App/containerApps@2023-05-01' = {
  name: containerAppName
  location: location
  identity: enableManagedIdentity ? {
    type: 'SystemAssigned'
  } : null
  properties: {
    environmentId: environmentId
    configuration: {
      ingress: {
        external: true
        targetPort: 80
        transport: 'http'
        allowInsecure: false
      }
      registries: empty(containerRegistryServer) ? [] : [
        {
          server: containerRegistryServer
          username: containerRegistryUsername
          passwordSecretRef: 'registry-password'
        }
      ]
      secrets: concat(
        empty(containerRegistryPassword) ? [] : [
          {
            name: 'registry-password'
            value: containerRegistryPassword
          }
        ],
        enableAadAuth ? [
          {
            name: 'aad-client-secret'
            value: aadClientSecret
          }
        ] : []
      )
    }
    template: {
      containers: [
        {
          name: 'flutter-web'
          image: containerImage
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
}

resource flutterWebAuth 'Microsoft.App/containerApps/authConfigs@2023-05-01' = if (enableAadAuth) {
  name: 'current'
  parent: flutterWeb
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

output fqdn string = flutterWeb.properties.configuration.ingress.fqdn
output containerAppName string = flutterWeb.name
