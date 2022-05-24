@description('リージョン。')
param location string = resourceGroup().location
// Settings for Virtual Machine
@description('仮想マシンの管理者ユーザー名。')
param adminUsername string = 'dataops-user'
@description('仮想マシンのパスワード。(Ex. P@ssw0rd1234-)')
@minLength(12)
@secure()
param adminPassword string
@description('仮想ネットワーク名。')
param virtualNetworkName string = 'dataops-vnet'
@description('仮想マシン名。')
param vmName string = 'dataops-vm'
@description('仮想マシンのネットワークインターフェース名。')
param vmNetworkInterfaceName string = 'dataops-vm-interface'
@description('仮想マシンのネットワークセキュリティグループ名。')
param networkSecurityGroupName string = 'dataops-vm-sg'
// CosmosDB Settings
@description('Cosmos DBアカウント名。')
param cosmosDBAccountName string = 'dataops-cosmos-${uniqueString(resourceGroup().id)}'
@description('データベース名。')
param databaseName string = 'opendata'
// DNS Settings for CosmosDB
@description('CosmosDBのプライベートエンドポイント名。')
param cosmosDBPrivateEndpointName string = 'dataops-cosmos-private-endpoint'
@description('CosmosDBのプライベートDNSゾーン名。')
param cosmosDBPrivateDnsZoneName string = 'privatelink.documents.azure.com'
@description('CosmosDBのネットワークインターフェース名。')
param cosmosDBNetworkInterfaceName string = 'dataops-cosmos-interface'
// Azure Bastion Settings
@description('Azure Bastionホスト名。')
param bastionHostName string = 'dataops-bastion-host'
@description('Azure BastionのパブリックIP名。')
param bastionPublicIPAddressName string = 'dataops-bustion-public-ip'
@description('Azure Bastionのネットワークセキュリティグループ名。')
param bastionSecurityGroupName string = 'dataops-bastion-sg'

resource virtualMachine 'Microsoft.Compute/virtualMachines@2021-07-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B2ms'
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-azure-edition'
        version: 'latest'
      }
      osDisk: {
        osType: 'Windows'
        name: '${vmName}_OsDisk_1_34bf20d57acd4a7386a9d772306e7814'
        createOption: 'FromImage'
        caching: 'ReadWrite'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
        deleteOption: 'Delete'
        diskSizeGB: 127
      }
      dataDisks: []
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: true
        patchSettings: {
          patchMode: 'AutomaticByOS'
          assessmentMode: 'ImageDefault'
          enableHotpatching: false
        }
      }
      secrets: []
      allowExtensionOperations: true
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: vmNetworkInterface.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}

resource vmSetupScript 'Microsoft.Compute/virtualMachines/extensions@2021-03-01' = {
  parent: virtualMachine
  name: 'vm-setup-script'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      timestamp: 123456789
    }
    protectedSettings: {
      fileUris: [
        'https://raw.githubusercontent.com/YujiAzama/ARMTest/main/installPowerPlatformPackages.ps1'
      ]
      commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File installPowerPlatformPackages.ps1'
    }
  }
}

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2020-11-01' = {
  name: networkSecurityGroupName
  location: location
  tags: {
    org: 'ool'
  }
  properties: {
    securityRules: [
      {
        name: 'AllowBastionInbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: '10.0.255.0/27'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 1001
          direction: 'Inbound'
          sourcePortRanges: []
          destinationPortRanges: [
            '22'
            '3389'
          ]
          sourceAddressPrefixes: []
          destinationAddressPrefixes: []
        }
      }
    ]
  }
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2020-11-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'VMSubnet'
        properties: {
          addressPrefix: '10.0.1.0/28'
          serviceEndpoints: [
            {
              service: 'Microsoft.AzureCosmosDB'
              locations: [
                '*'
              ]
            }
          ]
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
    virtualNetworkPeerings: []
    enableDdosProtection: false
  }
}

resource allowBastionInboundSecurityRule 'Microsoft.Network/networkSecurityGroups/securityRules@2020-11-01' = {
  parent: networkSecurityGroup
  name: 'AllowBastionInbound'
  properties: {
    protocol: '*'
    sourcePortRange: '*'
    sourceAddressPrefix: '10.0.255.0/27'
    destinationAddressPrefix: 'VirtualNetwork'
    access: 'Allow'
    priority: 1001
    direction: 'Inbound'
    sourcePortRanges: []
    destinationPortRanges: [
      '22'
      '3389'
    ]
    sourceAddressPrefixes: []
    destinationAddressPrefixes: []
  }
}

resource vmSubnet 'Microsoft.Network/virtualNetworks/subnets@2020-11-01' = {
  parent: virtualNetwork
  name: 'VMSubnet'
  properties: {
    addressPrefix: '10.0.1.0/28'
    serviceEndpoints: [
      {
        service: 'Microsoft.AzureCosmosDB'
        locations: [
          '*'
        ]
      }
    ]
    delegations: []
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
}

resource vmNetworkInterface 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: vmNetworkInterfaceName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAddress: '10.0.1.5'
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: vmSubnet.id
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
    dnsSettings: {
      dnsServers: []
    }
    enableAcceleratedNetworking: false
    enableIPForwarding: false
    networkSecurityGroup: {
      id: networkSecurityGroup.id
    }
  }
}

resource cosmosDBAccount 'Microsoft.DocumentDB/databaseAccounts@2021-07-01-preview' = {
  name: toLower(cosmosDBAccountName)
  location: location
  properties: {
    //enableFreeTier: true
    databaseAccountOfferType: 'Standard'
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: [
      {
        locationName: location
      }
    ]
    createMode: 'Default'
  }
}

resource cosmosDB 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2021-07-01-preview' = {
  parent: cosmosDBAccount
  name: databaseName
  properties: {
    resource: {
      id: databaseName
    }
  }
}

resource benokiContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2021-07-01-preview' = {
  parent: cosmosDB
  name: 'benoki'
  properties: {
    resource: {
      id: 'benoki'
      indexingPolicy: {
        indexingMode: 'consistent'
        automatic: true
        includedPaths: [
          {
            path: '/*'
          }
        ]
        excludedPaths: [
          {
            path: '/"_etag"/?'
          }
        ]
      }
      partitionKey: {
        paths: [
          '/riverName'
        ]
        kind: 'Hash'
      }
      uniqueKeyPolicy: {
        uniqueKeys: []
      }
      conflictResolutionPolicy: {
        mode: 'LastWriterWins'
        conflictResolutionPath: '/_ts'
      }
    }
  }
}

resource hukutiContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2021-07-01-preview' = {
  parent: cosmosDB
  name: 'hukuti'
  properties: {
    resource: {
      id: 'hukuti'
      indexingPolicy: {
        indexingMode: 'consistent'
        automatic: true
        includedPaths: [
          {
            path: '/*'
          }
        ]
        excludedPaths: [
          {
            path: '/"_etag"/?'
          }
        ]
      }
      partitionKey: {
        paths: [
          '/riverName'
        ]
        kind: 'Hash'
      }
      uniqueKeyPolicy: {
        uniqueKeys: []
      }
      conflictResolutionPolicy: {
        mode: 'LastWriterWins'
        conflictResolutionPath: '/_ts'
      }
    }
  }
}

resource benokiThroughputSettings 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/throughputSettings@2021-07-01-preview' = {
  parent: benokiContainer
  name: 'default'
  properties: {
    resource: {
      throughput: 400
    }
  }
}

resource hukutiThroughputSettings 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/throughputSettings@2021-07-01-preview' = {
  parent: hukutiContainer
  name: 'default'
  properties: {
    resource: {
      throughput: 400
    }
  }
}

resource sqlRoleDefinitions_00000000_0000_0000_0000_000000000001 'Microsoft.DocumentDB/databaseAccounts/sqlRoleDefinitions@2021-07-01-preview' = {
  parent: cosmosDBAccount
  name: '00000000-0000-0000-0000-000000000001'
  properties: {
    roleName: 'Cosmos DB Built-in Data Reader'
    type: 'BuiltInRole'
    assignableScopes: [
      cosmosDBAccount.id
    ]
    permissions: [
      {
        dataActions: [
          'Microsoft.DocumentDB/databaseAccounts/readMetadata'
          'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/executeQuery'
          'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/readChangeFeed'
          'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/read'
        ]
        notDataActions: []
      }
    ]
  }
}

resource sqlRoleDefinitions_00000000_0000_0000_0000_000000000002 'Microsoft.DocumentDB/databaseAccounts/sqlRoleDefinitions@2021-07-01-preview' = {
  parent: cosmosDBAccount
  name: '00000000-0000-0000-0000-000000000002'
  properties: {
    roleName: 'Cosmos DB Built-in Data Contributor'
    type: 'BuiltInRole'
    assignableScopes: [
      cosmosDBAccount.id
    ]
    permissions: [
      {
        dataActions: [
          'Microsoft.DocumentDB/databaseAccounts/readMetadata'
          'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/*'
          'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/*'
        ]
        notDataActions: []
      }
    ]
  }
}

resource cosmosDBPrivateEndpoint 'Microsoft.Network/privateEndpoints@2020-11-01' = {
  name: cosmosDBPrivateEndpointName
  location: location
  properties: {
    privateLinkServiceConnections: [
      {
        name: cosmosDBPrivateEndpointName
        properties: {
          privateLinkServiceId: cosmosDBAccount.id
          groupIds: [
            'Sql'
          ]
          privateLinkServiceConnectionState: {
            status: 'Approved'
            actionsRequired: 'None'
          }
        }
      }
    ]
    manualPrivateLinkServiceConnections: []
    subnet: {
      id: '${virtualNetwork.id}/subnets/VMSubnet'
    }
    customDnsConfigs: [
      {
        fqdn: 'ool-dataops.documents.azure.com'
        ipAddresses: [
          '10.0.1.7'
        ]
      }
      {
        fqdn: 'ool-dataops-japaneast.documents.azure.com'
        ipAddresses: [
          '10.0.1.8'
        ]
      }
    ]
  }
}

resource cosmosDBNetworkInterface 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: cosmosDBNetworkInterfaceName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'privateEndpointIpConfig.9ab0d39c-f07d-4f95-9c37-05d0c6dccfe8'
        properties: {
          privateIPAddress: '10.0.1.7'
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: vmSubnet.id
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
        }
      }
      {
        name: 'privateEndpointIpConfig.222ff169-5ba0-464b-bff6-2e883ec5f0c9'
        properties: {
          privateIPAddress: '10.0.1.8'
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: vmSubnet.id
          }
          primary: false
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
    dnsSettings: {
      dnsServers: []
    }
    enableAcceleratedNetworking: false
    enableIPForwarding: false
  }
}

resource cosmosDBPrivateDnsZone 'Microsoft.Network/privateDnsZones@2018-09-01' = {
  name: cosmosDBPrivateDnsZoneName
  location: 'global'
  properties: {}
}

resource privateDnsZoneA01 'Microsoft.Network/privateDnsZones/A@2018-09-01' = {
  parent: cosmosDBPrivateDnsZone
  name: 'ool-dataops'
  properties: {
    ttl: 3600
    aRecords: [
      {
        ipv4Address: '10.0.1.7'
      }
    ]
  }
}

resource privateDnsZoneA02 'Microsoft.Network/privateDnsZones/A@2018-09-01' = {
  parent: cosmosDBPrivateDnsZone
  name: 'ool-dataops-japaneast'
  properties: {
    ttl: 3600
    aRecords: [
      {
        ipv4Address: '10.0.1.8'
      }
    ]
  }
}

resource privateDnsZoneSOA 'Microsoft.Network/privateDnsZones/SOA@2018-09-01' = {
  parent: cosmosDBPrivateDnsZone
  name: '@'
  properties: {
    ttl: 3600
    soaRecord: {
      email: 'azureprivatedns-host.microsoft.com'
      expireTime: 2419200
      host: 'azureprivatedns.net'
      minimumTtl: 10
      refreshTime: 3600
      retryTime: 300
      serialNumber: 1
    }
  }
}

resource virtualNetworkLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2018-09-01' = {
  parent: cosmosDBPrivateDnsZone
  name: 'vmpruztkk5r5d'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: virtualNetwork.id
    }
  }
}

resource bastionHost 'Microsoft.Network/bastionHosts@2020-11-01' = {
  name: bastionHostName
  location: location
  properties: {
    dnsName: 'bst-b33ee165-8294-4b54-a5b3-06ac7c96b64d.bastion.azure.com'
    ipConfigurations: [
      {
        name: 'IpConf'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: bastionPublicIPAddresses.id
          }
          subnet: {
            id: azureBastionSubnet.id
          }
        }
      }
    ]
  }
}

resource bastionPublicIPAddresses 'Microsoft.Network/publicIPAddresses@2020-11-01' = {
  name: bastionPublicIPAddressName
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
    ipTags: []
  }
}

resource azureBastionSubnet 'Microsoft.Network/virtualNetworks/subnets@2020-11-01' = {
  parent: virtualNetwork
  name: 'AzureBastionSubnet'
  properties: {
    addressPrefix: '10.0.255.0/27'
    networkSecurityGroup: {
      id: bastionSecurityGroup.id
    }
    delegations: []
    privateEndpointNetworkPolicies: 'Enabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
}

resource bastionSecurityGroup 'Microsoft.Network/networkSecurityGroups@2020-11-01' = {
  name: bastionSecurityGroupName
  location: location
  tags: {
    org: 'ool'
  }
  properties: {
    securityRules: [
      {
        name: 'AllowHTTPSInbound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 120
          direction: 'Inbound'
          sourcePortRanges: []
          destinationPortRanges: []
          sourceAddressPrefixes: []
          destinationAddressPrefixes: []
        }
      }
      {
        name: 'AllowGatewayManagerInbound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'GatewayManager'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 130
          direction: 'Inbound'
          sourcePortRanges: []
          destinationPortRanges: []
          sourceAddressPrefixes: []
          destinationAddressPrefixes: []
        }
      }
      {
        name: 'AllowAzureLoadBalancerInbound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 140
          direction: 'Inbound'
          sourcePortRanges: []
          destinationPortRanges: []
          sourceAddressPrefixes: []
          destinationAddressPrefixes: []
        }
      }
      {
        name: 'AllowBastionHostCommunication'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 150
          direction: 'Inbound'
          sourcePortRanges: []
          destinationPortRanges: [
            '8080'
            '5701'
          ]
          sourceAddressPrefixes: []
          destinationAddressPrefixes: []
        }
      }
      {
        name: 'AllowSshRdpOutbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 100
          direction: 'Outbound'
          sourcePortRanges: []
          destinationPortRanges: [
            '22'
            '3389'
          ]
          sourceAddressPrefixes: []
          destinationAddressPrefixes: []
        }
      }
      {
        name: 'AllowAzureCloudOutbound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'AzureCloud'
          access: 'Allow'
          priority: 110
          direction: 'Outbound'
          sourcePortRanges: []
          destinationPortRanges: []
          sourceAddressPrefixes: []
          destinationAddressPrefixes: []
        }
      }
      {
        name: 'AllowBastionCommunication'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 120
          direction: 'Outbound'
          sourcePortRanges: []
          destinationPortRanges: [
            '8080'
            '5701'
          ]
          sourceAddressPrefixes: []
          destinationAddressPrefixes: []
        }
      }
      {
        name: 'AllowGetSessionInformation'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Internet'
          access: 'Allow'
          priority: 130
          direction: 'Outbound'
          sourcePortRanges: []
          destinationPortRanges: []
          sourceAddressPrefixes: []
          destinationAddressPrefixes: []
        }
      }
    ]
  }
}
