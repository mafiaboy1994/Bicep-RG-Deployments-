@description('Name your virtual machine')
param vmName string = 'LinuxVM01'

@description('Username for the Virtual Machine 1')
param adminUsernamevm1 string

@description('VM auth')
@allowed([
  'sshPublicKey'
  'password'
])
param authType string = 'password'

@description('SSH key or password for the Virtual Machine. SSH key is recommended')
@secure()
param adminPasswordOrKey string 

@description('Unique DNS Name for the Public IP used to access the Virtual Machine')
param dnsLabelPrefix string = toLower('${vmName}-${uniqueString(resourceGroup().id)}')

@description('The Ubuntu version for the VM. This will pick a fully pateched image of the given ubuntu version')
@allowed([
  '12.04.5-LTS'
  '14.04.5-LTS'
  '16.04.0-LTS'
  '18.04-LTS'
  '20.04-LTS'
])
param ubuntuOSVersion string = '18.04-LTS'

@description('Location for all resources')
param location string = resourceGroup().location

@description('Size of VM')
param vmSize string = 'Standard_B2s'

@description('Name of the vnet')
param virtualNetworkName string = 'vNet'

@description('Name of the subnet in the virtual network')
param subnetName string = 'Subnet'

@description('Name of the NSG')
param networkSecurityGroupName string = 'SecGroupNet'


var publicIpAddressName = '${vmName}PublicIP'
var networkInterfaceName = '${vmName}NetInt'
var osDiskType = 'Standard_LRS'
var subnetAddressPrefix = '10.1.0.0/24'
var addressPrefix = '10.1.0.0/16'
var LinuxConfiguration = {
  disablePasswordAuthentication: true 
  ssh: {
    publickeys: [
      {
        path: '/home/${adminUsernamevm1}/.ssh/authorized_keys'
        keyData: adminPasswordOrKey
      }
    ]
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2021-08-01' = {
  name: networkInterfaceName
  location: location
  properties: {
    ipConfigurations: [
      { 
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnet.id
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIP.id
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: nsg.id
    }
  }
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2021-08-01' = {
  name: networkSecurityGroupName
  location: location
  properties: {
    securityRules: [
      {
        name: 'SSH'
        properties: {
          priority: 1000
          direction: 'Inbound'
          protocol: 'Tcp'
          access: 'Allow'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2021-08-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
  }
}

resource subnet 'Microsoft.Network/virtualnetworks/subnets@2021-05-01' = {
  parent:vnet
  name: subnetName
  properties: {
    addressPrefix: subnetAddressPrefix
    privateEndpointNetworkPolicies: 'Enabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
}

resource publicIP 'Microsoft.Network/publicIPAddresses@2021-08-01' = {
  name: publicIpAddressName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    publicIPAllocationMethod: 'Dynamic'
    publicIPAddressVersion: 'IPv4'
    dnsSettings: {
      domainNameLabel: dnsLabelPrefix
    }
    idleTimeoutInMinutes: 4
  }
}


resource vm 'Microsoft.Compute/virtualMachines@2021-11-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: osDiskType
        }
      }
      imageReference: {
        publisher: 'Canonical'
        offer: 'UbuntuServer'
        sku: ubuntuOSVersion
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsernamevm1
      adminPassword: adminPasswordOrKey
      linuxConfiguration: ((authType == 'password') ?null : LinuxConfiguration)
    }
  }
}

output adminUsername string = adminUsernamevm1
output hostname string = publicIP.properties.dnsSettings.fqdn
output sshCommand string = 'ssh ${adminUsernamevm1}@${publicIP.properties.dnsSettings.fqdn}'


