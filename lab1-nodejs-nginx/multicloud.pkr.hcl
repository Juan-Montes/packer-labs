# =============================================================================
# Ejercicio 3 — Template Multinube: Azure + GCP
# Genera imágenes equivalentes en paralelo en ambas nubes
# Materia: Herramientas DevOps - UNIR
# =============================================================================

packer {
  required_plugins {
    azure = {
      source  = "github.com/hashicorp/azure"
      version = "~> 2"
    }
    googlecompute = {
      source  = "github.com/hashicorp/googlecompute"
      version = "~> 1"
    }
  }
}

# -----------------------------------------------------------------------------
# Variables Azure
# -----------------------------------------------------------------------------
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
variable "location" {
  type    = string
  default = "West US"
}
variable "image_name" {
  type    = string
  default = "ubuntu-nodejs-nginx"
}

# -----------------------------------------------------------------------------
# Variables GCP
# -----------------------------------------------------------------------------
variable "gcp_project_id" {
  type = string
}
variable "gcp_zone" {
  type    = string
  default = "us-central1-a"
}

# -----------------------------------------------------------------------------
# Builder 1: Azure ARM
# -----------------------------------------------------------------------------
source "azure-arm" "nodejs_nginx" {
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

  managed_image_name                = var.image_name
  managed_image_resource_group_name = var.resource_group

  communicator = "ssh"
  ssh_username = "packer"
  ssh_timeout  = "20m"

  azure_tags = {
    Environment = "DevOps-Maestria"
    Project     = "Lab1-Multicloud"
    CreatedBy   = "Packer"
  }
}

# -----------------------------------------------------------------------------
# Builder 2: Google Compute
# -----------------------------------------------------------------------------
source "googlecompute" "nodejs_nginx" {
  project_id          = var.gcp_project_id
  source_image_family = "ubuntu-2204-lts"
  zone                = var.gcp_zone
  machine_type        = "e2-medium"

  image_name        = "ubuntu-nodejs-nginx-gcp"
  image_description = "Node.js 20 LTS + PM2 + Nginx — DevOps UNIR"
  image_family      = "nodejs-nginx"

  ssh_username = "packer"
  ssh_timeout  = "20m"

  tags = ["packer", "devops", "nodejs"]
}

# -----------------------------------------------------------------------------
# Build: ambos builders comparten los mismos provisioners
# -----------------------------------------------------------------------------
build {
  name = "nodejs-nginx-multicloud"
  sources = [
    "source.azure-arm.nodejs_nginx",
    "source.googlecompute.nodejs_nginx",
  ]

  # Paso 1 — Actualizar sistema
  provisioner "shell" {
    inline = [
      "echo '>>> [1/6] Actualizando el sistema operativo...'",
      "sudo apt-get clean",
      "sudo rm -rf /var/lib/apt/lists/*",
      "sudo apt-get update -y || true",
      "sudo apt-get upgrade -y || true",
      "sudo apt-get update -y && sudo apt-get install -y curl wget git build-essential",
    ]
  }

  # Paso 2 — Node.js 20 LTS
  provisioner "shell" {
    inline = [
      "echo '>>> [2/6] Instalando Node.js 20 LTS...'",
      "curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -",
      "sudo apt-get install -y nodejs",
      "node --version",
      "npm --version",
    ]
  }

  # Paso 3 — PM2
  provisioner "shell" {
    inline = [
      "echo '>>> [3/6] Instalando PM2...'",
      "sudo npm install -g pm2",
      "pm2 --version",
      "sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u packer --hp /home/packer || true",
      "sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u azureuser --hp /home/azureuser || true",
      "sudo loginctl enable-linger azureuser || true",
    ]
  }

  # Paso 4 — App Node.js
  provisioner "file" {
    source      = "app/hello.js"
    destination = "/tmp/hello.js"
  }

  provisioner "file" {
    source      = "app/ecosystem.config.js"
    destination = "/tmp/ecosystem.config.js"
  }

  provisioner "shell" {
    inline = [
      "echo '>>> [4/6] Instalando la aplicacion Node.js...'",
      "sudo mkdir -p /opt/myapp",
      "sudo mkdir -p /var/log/pm2",
      "sudo chown -R packer:packer /var/log/pm2",
      "sudo cp /tmp/hello.js /opt/myapp/hello.js",
      "sudo cp /tmp/ecosystem.config.js /opt/myapp/ecosystem.config.js",
      "sudo chown -R packer:packer /opt/myapp",
      "cd /opt/myapp && pm2 start ecosystem.config.js",
      "pm2 save",
    ]
  }

  # Paso 5 — Nginx
  provisioner "shell" {
    inline = [
      "echo '>>> [5/6] Instalando y configurando Nginx...'",
      "sudo apt-get install -y nginx",
      "sudo rm -f /etc/nginx/sites-enabled/default",
      "sudo bash -c 'cat > /etc/nginx/sites-available/myapp <<NGINX",
      "server {",
      "    listen 80;",
      "    server_name _;",
      "    location / {",
      "        proxy_pass http://localhost:3000;",
      "        proxy_http_version 1.1;",
      "        proxy_set_header Host \\$host;",
      "        proxy_set_header X-Real-IP \\$remote_addr;",
      "    }",
      "}",
      "NGINX'",
      "sudo ln -s /etc/nginx/sites-available/myapp /etc/nginx/sites-enabled/myapp",
      "sudo nginx -t",
      "sudo systemctl enable nginx",
      "sudo systemctl start nginx",
    ]
  }

  # Paso 6 — Generalizar
  # Solo aplica a Azure — GCP no necesita deprovision
  provisioner "shell" {
    only   = ["azure-arm.nodejs_nginx"]
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E sh '{{ .Path }}'"
    inline = [
      "echo '>>> [6/6] Generalizando imagen Azure...'",
      "/usr/sbin/waagent -force -deprovision+user",
      "sync",
    ]
    inline_shebang = "/bin/sh -x"
  }
}
