param location string = resourceGroup().location

@allowed([
  'Production'
  'Test'
])
param environmentType string
param resourceSuffix string = uniqueString(resourceGroup().id)

@secure()
param sqlAdministratorLogin string
@secure()
param sqlAdministratorLoginPassword string

param productSpecsStorageContainerName string = 'productspecs'
param productManualsStorageContainerName string = 'productmanuals'

var webSiteName = 'webSite${resourceSuffix}'
var hostingPlanName = 'hostingplan${resourceSuffix}'
var sqlServerName = 'toywebsite${resourceSuffix}'
var storageAccountName = 'toywebsite${resourceSuffix}'
var webAppManagedIdentityName = 'website'
var contributorRoleDefinitionId = 'b24988ac-6180-42a0-ab88-20f7382dd24c'
var contributorRoleAssignmentName = guid(contributorRoleDefinitionId, resourceGroup().id)
var databaseName = 'ToyCompanyWebsite'
var webAppStorageAccountConnectionString = 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value}'

var environmentConfigurationMap = {
  Production: {
    serverFarm: {
      skuName: 'S1'
      skuCapacity: 2
    }
    storageAccount: {
      skuName: 'Standard_GRS'
    }
    sqlDatabase: {
      skuName: 'S1'
    }
  }
  Test: {
    serverFarm: {
      skuName: 'F1'
      skuCapacity: 1
    }
    storageAccount: {
      skuName: 'Standard_LRS'
    }
    sqlDatabase: {
      skuName: 'Basic'
    }
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2019-06-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: environmentConfigurationMap[environmentType].storageAccount.skuName
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
  }

  resource blobServices 'blobServices' existing = {
    name: 'default'

    resource productSpecsStorageContainer 'containers' = {
      name: productSpecsStorageContainerName
    }

    resource productManualsStorageContainer 'containers' = {
      name: productManualsStorageContainerName
    }
  }
}

resource sqlServer 'Microsoft.Sql/servers@2019-06-01-preview' = {
  name: sqlServerName
  location: location
  properties: {
    administratorLogin: sqlAdministratorLogin
    administratorLoginPassword: sqlAdministratorLoginPassword
    version: '12.0'
  }

  resource database 'databases@2020-08-01-preview' = {
    name: databaseName
    location: location
    sku: {
      name: environmentConfigurationMap[environmentType].sqlDatabase.skuName
    }
    properties: {
      collation: 'SQL_Latin1_General_CP1_CI_AS'
      maxSizeBytes: 1073741824
    }
  }

  resource firewallRuleAllowAllAzureIps 'firewallRules@2014-04-01' = {
    name: 'AllowAllAzureIPs'
    properties: {
      endIpAddress: '0.0.0.0'
      startIpAddress: '0.0.0.0'
    }
  }
}

resource hostingPlan 'Microsoft.Web/serverfarms@2020-06-01' = {
  name: hostingPlanName
  location: location
  sku: {
    name: environmentConfigurationMap[environmentType].serverFarm.skuName
    capacity: environmentConfigurationMap[environmentType].serverFarm.skuCapacity
  }
}

resource webApp 'Microsoft.Web/sites@2020-06-01' = {
  name: webSiteName
  location: location
  properties: {
    serverFarmId: hostingPlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: applicationInsightsWebApp.properties.InstrumentationKey
        }
        {
          name: 'StorageAccountConnectionString'
          value: webAppStorageAccountConnectionString
        }
      ]
    }
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${webAppManagedIdentity.id}': {}
    }
  }
}

resource webAppManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: webAppManagedIdentityName
  location: location
}

resource webAppContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: contributorRoleAssignmentName
  properties: {
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', contributorRoleDefinitionId)
    principalId: webAppManagedIdentity.properties.principalId
  }
}

resource applicationInsightsWebApp 'Microsoft.Insights/components@2018-05-01-preview' = {
  name: 'AppInsights'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
  }
}
