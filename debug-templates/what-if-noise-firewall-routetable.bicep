resource vnet 'Microsoft.Network/virtualNetworks@2020-11-01' = {
  name: 'vnet-name'
  location: resourceGroup().location
  properties: {
    addressSpace: {
      addressPrefixes:[
        '10.240.0.0/18'
      ]
    }
    subnets: [
      {
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: '10.240.0.0/24'
        }
      }
    ]
  }
}

resource firewallPip 'Microsoft.Network/publicIPAddresses@2020-05-01' = {
  name: 'pip-00'
  location: resourceGroup().location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
    publicIPAddressVersion: 'IPv4'
  }
}

resource firewall 'Microsoft.Network/azureFirewalls@2020-11-01' = {
  name: 'azf-name'
  location: resourceGroup().location
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: 'Standard'
    }
    ipConfigurations: [
      {
        name: firewallPip.name
        properties: {
          subnet: {
            id: vnet.properties.subnets[0].id
          }
          publicIPAddress: {
            id: firewallPip.id
          }
        }
      }
    ]
  }
}

resource routeTable 'Microsoft.Network/routeTables@2020-05-01' = {
  name: 'route-name'
  location: resourceGroup().location
  properties: {
    routes: [
      {
        name: 'all-to-fw'
        properties: {
          nextHopType: 'VirtualAppliance'
          addressPrefix: '0.0.0.0/0'
          nextHopIpAddress: firewall.properties.ipConfigurations[0].properties.privateIPAddress
        }
      }
    ]
  }
}
