@minLength(3)
@maxLength(11)
param namePrefix string

param location string = resourceGroup().location

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' = {
  name: '${namePrefix}loganalytics'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

resource containerRegistry 'microsoft.containerregistry/registries@2021-12-01-preview' = {
  name: '${namePrefix}acr'
  location: location
  properties: {
    adminUserEnabled: true
  }
  sku: {
    name: 'Basic'
  }
}

resource conatinerAppEnvironment 'Microsoft.App/managedEnvironments@2022-03-01' = {
  name: '${namePrefix}containerappenvironment'
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
  }
}

resource containerApp 'Microsoft.App/containerApps@2022-03-01' = {
  name: '${namePrefix}containerapp'
  location: location
  properties: {
    managedEnvironmentId: conatinerAppEnvironment.id
    configuration: {
      activeRevisionsMode: 'multiple'
      ingress: {
        external: true
        targetPort: 80
        allowInsecure: false
        traffic: [
          {
            revisionName: '${namePrefix}containerapp--initial'
            weight: 100
          }
        ]
      }
      registries: [
        {
          server: containerRegistry.name
          username: containerRegistry.properties.loginServer
          passwordSecretRef: 'container-registry-password'
        }
      ]
      secrets: [
        {
          name: 'container-registry-password'
          value: containerRegistry.listCredentials().passwords[0].value
        }
      ]
    }
    template: {
      revisionSuffix: 'initial'
      containers: [
        {
          name: '${namePrefix}containerapp'
          image: 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
          resources: {
            cpu: '0.5'
            memory: '1.0Gi'
          }
        }
      ]
    }  
  }
}
