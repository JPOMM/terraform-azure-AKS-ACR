provider "azurerm" {
  features {}

  subscription_id = "bd4eff48"
  tenant_id       = "e7d40ff1"
  client_id       = "85e4fc11"
  client_secret   = "5sX8Q~spBGWSF1"
}

resource "azurerm_resource_group" "rg" {
  name     = "jpommResourceGroup"
  location = "East US"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "jpommVnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "subnet" {
  name                 = "jpommSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"] # Asegúrate de que este rango no se solape con otras subredes
}

resource "azurerm_subnet" "gateway_subnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"] # Asegúrate de que no se solape con otras subredes
}

resource "azurerm_network_security_group" "nsg" {
  name                = "jpommNSG"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet_network_security_group_association" "subnet_nsg_assoc" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_virtual_network_gateway" "vnet_gateway" {
  name                = "jpommVNetGateway"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  type                = "Vpn"
  vpn_type            = "RouteBased"
  active_active       = false
  enable_bgp          = false
  sku                 = "VpnGw1"

  ip_configuration {
    name                          = "vnetGatewayIpConfig"
    public_ip_address_id          = azurerm_public_ip.vpn_pip.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway_subnet.id # Usa la subred correcta
  }
}

resource "azurerm_public_ip" "vpn_pip" {
  name                = "vpnGatewayPIP"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"  # Cambio de "Dynamic" a "Static"
  sku                 = "Standard" # Se requiere para IP estática
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "jpommAKSCluster"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "jpommakscluster"

  default_node_pool {
    name           = "default"
    node_count     = 2
    vm_size        = "Standard_DS2_v2"
    vnet_subnet_id = azurerm_subnet.subnet.id # Asegúrate de que el nombre coincide con la subred definida arriba
  }

  network_profile {
    network_plugin    = "azure"
    service_cidr      = "10.2.0.0/16"
    dns_service_ip    = "10.2.0.10"
  }

  identity {
    type = "SystemAssigned"
  }
}


resource "azurerm_role_assignment" "aks_contributor" {
  scope                = azurerm_resource_group.rg.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_kubernetes_cluster.aks.identity[0].principal_id
}

# Azure Container Registry (ACR)
resource "azurerm_container_registry" "acr" {
  name                = "jpommACR"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic" # Puedes cambiarlo a Standard o Premium
  admin_enabled       = true
}