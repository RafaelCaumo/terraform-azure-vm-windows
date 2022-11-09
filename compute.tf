data "azurerm_virtual_network" "current" {
  name                = var.vnet
  resource_group_name = var.resource_group_name
}

data "azurerm_subnet" "current" {
  name                 = var.subnet
  virtual_network_name = var.vnet
  resource_group_name  = var.resource_group_name
}

resource "azurerm_public_ip" "pip" {
  count = var.private_ip_address == null ? 1 : 0

  name                = "pip-${var.vm_name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = var.public_ip_allocation
  sku                 = "Standard"

  tags = var.tags
}

resource "azurerm_network_interface" "nic" {
  name                = "nic-${var.vm_name}"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    private_ip_address_allocation = var.private_ip_address == null ? "Dynamic" : "Static"
    private_ip_address_version    = "IPv4"
    subnet_id                     = data.azurerm_subnet.current.id
    private_ip_address            = var.private_ip_address
    public_ip_address_id          = var.private_ip_address == null ? join("", azurerm_public_ip.lb.*.id) : null
  }
  tags = var.tags
}

resource "azurerm_windows_virtual_machine" "vm" {
  name                     = var.vm_name
  location                 = var.location
  resource_group_name      = var.resource_group_name
  size                     = var.vm_size
  admin_username           = var.username#"adminuser"
  admin_password           = var.password
  network_interface_ids    = [azurerm_network_interface.nic.id]
  patch_mode               = var.patch_mode#"Manual"
  enable_automatic_updates = var.enable_automatic_updates#false
  license_type             = var.license_type
  
  os_disk {
    caching                = "ReadWrite"
    storage_account_type   = var.bootdisk_type
    disk_size_gb           = var.bootdisk_size
  }

  dynamic "source_image_reference" {
    for_each = var.image_id != null ? [] : [1]
    content {
      publisher = var.image.os_publisher
      offer     = var.image.os_offer
      sku       = var.image.os_sku
      version   = var.image.os_version
    }
  }

  source_image_id = var.image_id != null ? var.image_id : null

  dynamic "plan" {
    for_each = var.plan.os_publisher != null ? [1] : []
    content {
      publisher = var.plan.os_publisher
      product   = var.plan.os_offer
      name      = var.plan.os_sku
    }
  }

  boot_diagnostics {
    #When empty utilize a Platform-Managed Storage Account.
  }

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags

  depends_on = [azurerm_network_interface.nic]
}