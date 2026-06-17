# =============================================================================
# Lab 2 — CIS Hardened Image
# Ubuntu 22.04 LTS endurecida con CIS Benchmark Level 1
# Validada con Goss antes de publicar
# Materia: Herramientas DevOps — UNIR
# =============================================================================

packer {
  required_plugins {
    azure = {
      source  = "github.com/hashicorp/azure"
      version = "~> 2"
    }
  }
}

variable "client_id" {
  type      = string
  sensitive = true
}

variable "client_secret" {
  type      = string
  sensitive = true
}

variable "subscription_id" {
  type = string
}

variable "tenant_id" {
  type = string
}

variable "resource_group" {
  type    = string
  default = "rg-packer-devops"
}

variable "image_name" {
  type    = string
  default = "ubuntu-hardened-cis"
}


variable "location" {
  type    = string
  default = "West US"
}

source "azure-arm" "hardened" {
  client_id       = var.client_id
  client_secret   = var.client_secret
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id

  image_publisher = "Canonical"
  image_offer     = "0001-com-ubuntu-server-jammy"
  image_sku       = "22_04-lts-gen2"
  image_version   = "latest"

  vm_size  = "Standard_D2s_v3"
  os_type  = "Linux"
  location = var.location

  managed_image_name                = "ubuntu-hardened-cis"
  managed_image_resource_group_name = var.resource_group

  communicator = "ssh"
  ssh_username = "packer"
  ssh_timeout  = "20m"

  azure_tags = {
    CIS-Level   = "Level-1"
    Hardened    = "true"
    Environment = "DevOps-Maestria"
    CreatedBy   = "Packer"
  }
}

build {
  name    = "cis-hardened"
  sources = ["source.azure-arm.hardened"]

  # Subir scripts de hardening
  provisioner "file" {
    source      = "scripts/"
    destination = "/tmp/cis-scripts/"
  }

  provisioner "file" {
    source      = "tests/cis-validation.yaml"
    destination = "/tmp/cis-validation.yaml"
  }

  provisioner "shell" {
    inline = [
      "sudo apt-get clean",
      "sudo rm -rf /var/lib/apt/lists/*",
      "sudo apt-get update -y && sudo apt-get install -y curl",
      "chmod +x /tmp/cis-scripts/*.sh",
    ]
  }

  # Aplicar cada sección CIS
  provisioner "shell" {
    inline = ["sudo /tmp/cis-scripts/01-filesystem.sh"]
  }

  provisioner "shell" {
    inline = ["sudo /tmp/cis-scripts/02-services.sh"]
  }

  provisioner "shell" {
    inline = ["sudo /tmp/cis-scripts/03-network.sh"]
  }

  provisioner "shell" {
    inline = ["sudo /tmp/cis-scripts/04-auditd.sh"]
  }

  provisioner "shell" {
    inline = ["sudo /tmp/cis-scripts/05-access-auth.sh"]
  }

  provisioner "shell" {
    inline = ["sudo /tmp/cis-scripts/06-updates.sh"]
  }

  # Validar con Goss — si falla, el build se aborta
  provisioner "shell" {
    inline = [
      "echo '>>> Instalando Goss...'",
      "curl -fsSL https://goss.rocks/install | sudo sh",
      "echo '>>> Ejecutando validación CIS...'",
      "sudo goss -g /tmp/cis-validation.yaml validate --format documentation",
    ]
  }

  # Generalizar para Azure
  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E sh '{{ .Path }}'"
    inline = [
      "/usr/sbin/waagent -force -deprovision+user",
      "sync",
    ]
    inline_shebang = "/bin/sh -x"
  }
}
