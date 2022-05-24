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
// Automation Settings
@description('Runbook内からAzureリソースを操作する権限を与えるためのマネージドID名。')
param userAssignedIdentitiesName string = 'user-assigned-id-for-automation'
@description('Automationアカウント名。')
param automationAccountsName string = 'dataops-bastion-automation'
@description('Bastionを起動する時間。(現在時刻より5分後以降を指定してください。)')
param createTime string = '2022-05-25T07:00+09:00'
@description('Bastionを削除する時間。(現在時刻より5分後以降を指定してください。)')
param deleteTime string = '2022-05-25T23:00+09:00'

@description('The IDs of the role definitions to assign to the managed identity. Each role assignment is created at the resource group scope. Role definition IDs are GUIDs. To find the GUID for built-in Azure role definitions, see https://docs.microsoft.com/azure/role-based-access-control/built-in-roles. You can also use IDs of custom role definitions.')
param roleDefinitionIds array = [
  'b24988ac-6180-42a0-ab88-20f7382dd24c'
]

var roleAssignmentsToCreate = [for roleDefinitionId in roleDefinitionIds: {
  name: guid(userAssignedIdentities.id, deployment().name, roleDefinitionId)
  roleDefinitionId: roleDefinitionId
}]

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

resource userAssignedIdentities 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: userAssignedIdentitiesName
  location: location
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = [for roleAssignmentToCreate in roleAssignmentsToCreate: {
  name: roleAssignmentToCreate.name
  scope: automationAccounts
  properties: {
    description: '共同作成者'
    principalId: userAssignedIdentities.properties.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleAssignmentToCreate.roleDefinitionId)
    principalType: 'ServicePrincipal'
  }
}]

resource automationAccounts 'Microsoft.Automation/automationAccounts@2021-06-22' = {
  name: automationAccountsName
  location: location
  identity: {
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentities.id}': {}
    }
  }
  properties: {
    publicNetworkAccess: false
    disableLocalAuth: false
    sku: {
      name: 'Basic'
    }
    encryption: {
      keySource: 'Microsoft.Automation'
      identity: {}
    }
  }
}

resource automationAccounts_DataOpsAutomation_name_Azure 'Microsoft.Automation/automationAccounts/connectionTypes@2020-01-13-preview' = {
  parent: automationAccounts
  name: guid('Azure', automationAccounts.id)
  properties: {
    isGlobal: false
    fieldDefinitions: {
      AutomationCertificateName: {
        isEncrypted: false
        isOptional: false
        type: 'System.String'
      }
      SubscriptionID: {
        isEncrypted: false
        isOptional: false
        type: 'System.String'
      }
    }
  }
}

resource automationAccounts_DataOpsAutomation_name_AzureClassicCertificate 'Microsoft.Automation/automationAccounts/connectionTypes@2020-01-13-preview' = {
  parent: automationAccounts
  name: guid('AzureClassicCertificate', automationAccounts.id)
  properties: {
    isGlobal: false
    fieldDefinitions: {
      SubscriptionName: {
        isEncrypted: false
        isOptional: false
        type: 'System.String'
      }
      SubscriptionId: {
        isEncrypted: false
        isOptional: false
        type: 'System.String'
      }
      CertificateAssetName: {
        isEncrypted: false
        isOptional: false
        type: 'System.String'
      }
    }
  }
}

resource automationAccounts_DataOpsAutomation_name_AzureServicePrincipal 'Microsoft.Automation/automationAccounts/connectionTypes@2020-01-13-preview' = {
  parent: automationAccounts
  name: guid('AzureServicePrincipal', automationAccounts.id)
  properties: {
    isGlobal: false
    fieldDefinitions: {
      ApplicationId: {
        isEncrypted: false
        isOptional: false
        type: 'System.String'
      }
      TenantId: {
        isEncrypted: false
        isOptional: false
        type: 'System.String'
      }
      CertificateThumbprint: {
        isEncrypted: false
        isOptional: false
        type: 'System.String'
      }
      SubscriptionId: {
        isEncrypted: false
        isOptional: false
        type: 'System.String'
      }
    }
  }
}

resource automationAccounts_DataOpsAutomation_name_Az_Accounts 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: automationAccounts
  name: 'Az.Accounts'
  properties: {
    contentLink: {
      uri: 'https://psg-prod-eastus.azureedge.net/packages/az.accounts.2.7.6.nupkg'
    }
  }
}

resource automationAccounts_DataOpsAutomation_name_Az_ManagedServiceIdentity 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: automationAccounts
  name: 'Az.ManagedServiceIdentity'
  dependsOn: [
    automationAccounts_DataOpsAutomation_name_Az_Accounts
  ]
  properties: {
    contentLink: {
      uri: 'https://psg-prod-eastus.azureedge.net/packages/az.managedserviceidentity.0.8.0.nupkg'
    }
  }
}

resource automationAccounts_DataOpsAutomation_name_Az_ManagedServices 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: automationAccounts
  name: 'Az.ManagedServices'
  dependsOn: [
    automationAccounts_DataOpsAutomation_name_Az_Accounts
  ]
  properties: {
    contentLink: {
      uri: 'https://psg-prod-eastus.azureedge.net/packages/az.managedservices.3.0.0.nupkg'
    }
  }
}

resource bastionCreateRunbook 'Microsoft.Automation/automationAccounts/runbooks@2019-06-01' = {
  parent: automationAccounts
  name: 'BastionCreate'
  location: location
  properties: {
    runbookType: 'PowerShell'
    logVerbose: true
    logProgress: true
    logActivityTrace: 0
    publishContentLink: {
      uri: 'https://raw.githubusercontent.com/YujiAzama/ARMTest/main/bastion/automation/runbook/createBastion.ps1'
      version: '1.0.0.0'
    }
  }
}

resource bastionDeleteRunbook 'Microsoft.Automation/automationAccounts/runbooks@2019-06-01' = {
  parent: automationAccounts
  name: 'BastionDelete'
  location: location
  properties: {
    runbookType: 'PowerShell'
    logVerbose: false
    logProgress: false
    logActivityTrace: 0
    publishContentLink: {
      uri: 'https://raw.githubusercontent.com/YujiAzama/ARMTest/main/bastion/automation/runbook/deleteBastion.ps1'
      version: '1.0.0.0'
    }
  }
}

resource bastionCreateSchedule 'Microsoft.Automation/automationAccounts/schedules@2020-01-13-preview' = {
  parent: automationAccounts
  name: 'BastionCreate'
  properties: {
    startTime: createTime
    expiryTime: '9999-12-31T23:59:59.9999999+00:00'
    interval: 1
    frequency: 'Week'
    timeZone: 'Asia/Tokyo'
    advancedSchedule: {
      weekDays: [
        'Monday'
        'Tuesday'
        'Wednesday'
        'Thursday'
        'Friday'
      ]
    }
  }
}

resource bastionDeleteSchedule 'Microsoft.Automation/automationAccounts/schedules@2020-01-13-preview' = {
  parent: automationAccounts
  name: 'BastionDelete'
  properties: {
    startTime: deleteTime
    expiryTime: '9999-12-31T23:59:59.9999999+00:00'
    interval: 1
    frequency: 'Week'
    timeZone: 'Asia/Tokyo'
    advancedSchedule: {
      weekDays: [
        'Monday'
        'Tuesday'
        'Wednesday'
        'Thursday'
        'Friday'
      ]
    }
  }
}

resource bastionCreateJobSchedule 'Microsoft.Automation/automationAccounts/jobSchedules@2020-01-13-preview' = {
  parent: automationAccounts
  name: guid('bastionCreate', resourceGroup().id, deployment().name)
  properties: {
    runbook: {
      name: bastionCreateRunbook.name
    }
    schedule: {
      name: bastionCreateSchedule.name
    }
    parameters: {
      resourceGroup: resourceGroup().name
      userAssignedManagedIdentity: userAssignedIdentities.name
    }
  }
}

resource bastionDeleteJobSchedule 'Microsoft.Automation/automationAccounts/jobSchedules@2020-01-13-preview' = {
  parent: automationAccounts
  name: guid('bastionDelete', resourceGroup().id, deployment().name)
  properties: {
    runbook: {
      name: bastionDeleteRunbook.name
    }
    schedule: {
      name: bastionDeleteSchedule.name
    }
  }
}
