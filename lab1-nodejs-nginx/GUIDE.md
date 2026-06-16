# 📖 GUIDE — Lab 1: Node.js + PM2 + Nginx en Azure y GCP

Guía completa del laboratorio 1. Documenta cómo se llevó a cabo,
qué problemas se encontraron y cómo se resolvieron.

---

## Stack desplegado

| Componente | Versión | Rol |
|------------|---------|-----|
| Ubuntu     | 22.04 LTS (Jammy) | Sistema operativo base |
| Node.js    | v20.20.2 LTS | Servidor de aplicaciones (puerto 3000) |
| PM2        | v7.0.1 | Gestor de procesos — arranque automático |
| Nginx      | 1.18.0 | Reverse proxy (puerto 80 → 3000) |

**Flujo de red:**
```
Internet → Nginx :80 → Node.js :3000 → JSON response
```

---

## Prerrequisitos

### En Pop!_OS 22.04 (workstation local)

**Azure CLI:**
```bash
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
# ⚠️ En Pop!_OS forzar codename jammy en el repo de Microsoft
# (Pop!_OS usa ID "pop", no "ubuntu")
```

**Packer CLI:**
```bash
wget -O- https://apt.releases.hashicorp.com/gpg | \
  sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com jammy main" | \
  sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt-get update && sudo apt-get install -y packer
```

**Google Cloud SDK:**
```bash
curl https://sdk.cloud.google.com | bash
# Agregar al .zshrc (no al .bashrc si usas zsh):
echo "source /home/$USER/google-cloud-sdk/path.zsh.inc" >> ~/.zshrc
echo "source /home/$USER/google-cloud-sdk/completion.zsh.inc" >> ~/.zshrc
source ~/.zshrc
```

---

## Ejercicio 1 — Crear imagen en Azure

### 1. Autenticación Azure

```bash
# Login con device code (evita conflicto con cuenta institucional UNIR)
az login --use-device-code
```

### 2. Crear Resource Group y Service Principal

```bash
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

az group create --name rg-packer-devops --location westus

az ad sp create-for-rbac \
  --name sp-packer-devops \
  --role Contributor \
  --scopes /subscriptions/$SUBSCRIPTION_ID \
  --output json

# Guardar appId, password y tenant en azure.pkrvars.hcl
```

### 3. Completar azure.pkrvars.hcl

```hcl
client_id       = "appId del SP"
client_secret   = "password del SP"
subscription_id = "tu subscription ID"
tenant_id       = "tu tenant ID"
resource_group  = "rg-packer-devops"
location        = "West US"
image_name      = "ubuntu-nodejs-nginx"
```

### 4. Ejecutar el build

```bash
packer init     azure-nodejs.pkr.hcl
packer validate -var-file=azure.pkrvars.hcl azure-nodejs.pkr.hcl
packer build    -var-file=azure.pkrvars.hcl azure-nodejs.pkr.hcl
```

**Duración:** ~6 minutos 29 segundos  
**Resultado:** Managed Image `ubuntu-nodejs-nginx` en `rg-packer-devops` (West US)

### Problemas encontrados y soluciones

| Error | Causa | Solución |
|-------|-------|----------|
| `An os_type must be specified` | Plugin azure-arm v2 lo requiere explícitamente | Agregar `os_type = "Linux"` en el bloque source |
| `Bad source '../app/hello.js'` | Ruta incorrecta del provisioner file | Cambiar `../app/` por `app/` |
| `SkuNotAvailable Standard_B2s` | Sin capacidad en eastus con cuenta gratuita | Cambiar a `Standard_D2s_v3` en `westus` |
| `exit code 100` en apt-get update | Bug de cnf-update-db en Ubuntu 22.04 | Agregar `|| true` y limpiar cache con `apt-get clean` |
| `Unable to locate package build-essential` | Índices apt corruptos tras apt-get clean | Agregar segundo `apt-get update` antes del install |
| `Could not create folder /var/log/pm2` | Usuario packer sin permisos en /var/log | Crear directorio con sudo y asignar ownership antes de PM2 |

---

## Ejercicio 2 — Despliegue automático

El script `deploy.sh` encadena todo sin intervención manual:

```bash
./deploy.sh
```

**Pasos internos:**
1. `packer build -force` → genera/actualiza la imagen
2. `az vm create --size Standard_D2s_v3` → despliega VM
3. `az vm open-port --port 80` → abre HTTP
4. `curl` con 5 reintentos → verifica respuesta

**Resultado verificado:**
```json
{
  "message": "¡Hola desde Node.js en Azure!",
  "hostname": "vm-nodejs-nginx-auto",
  "nodeVersion": "v20.20.2",
  "stack": "Node.js + PM2 + Nginx (reverse proxy)"
}
```

### Problema: PM2 no arranca automáticamente

**Causa:** PM2 startup se configuró para el usuario `packer` durante el build,
pero la VM corre como `azureuser`.

**Solución:** Agregar en el provisioner del Paso 3:
```bash
sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u azureuser --hp /home/azureuser || true
sudo loginctl enable-linger azureuser || true
```

---

## Ejercicio 3 — Despliegue multinube (Azure + GCP)

### 1. Configurar GCP

```bash
# Autenticación
gcloud auth login
gcloud auth application-default login

# Configurar proyecto
gcloud config set project TU_PROJECT_ID
gcloud auth application-default set-quota-project TU_PROJECT_ID

# Habilitar API
gcloud services enable compute.googleapis.com
```

> ⚠️ **GCP no permite crear JSON keys en cuentas nuevas** por política de seguridad.
> Usar **Application Default Credentials (ADC)** — Packer lo soporta nativamente.
> No se necesita archivo JSON de credenciales.

### 2. Completar gcp.pkrvars.hcl

```hcl
gcp_project_id = "tu-project-id"
gcp_zone       = "us-central1-a"
```

### 3. Ejecutar el build multinube

```bash
packer init multicloud.pkr.hcl

packer validate \
  -var-file=azure.pkrvars.hcl \
  -var-file=gcp.pkrvars.hcl \
  multicloud.pkr.hcl

packer build -force \
  -var-file=azure.pkrvars.hcl \
  -var-file=gcp.pkrvars.hcl \
  multicloud.pkr.hcl
```

**Duración:** ~5 minutos 21 segundos (builders en paralelo)

**Resultado:**
```
--> GCP:   ubuntu-nodejs-nginx-gcp  (us, project-a48e5f83-fce8-49fa-894)
--> Azure: ubuntu-nodejs-nginx      (West US, rg-packer-devops)
```

### Concepto clave del template multinube

```hcl
build {
  sources = [
    "source.azure-arm.nodejs_nginx",      # Builder 1
    "source.googlecompute.nodejs_nginx",  # Builder 2 — corre en paralelo
  ]

  # Los provisioners se comparten entre ambos builders
  # Para pasos exclusivos de una nube usar "only":
  provisioner "shell" {
    only   = ["azure-arm.nodejs_nginx"]   # Solo ejecuta en Azure
    inline = ["/usr/sbin/waagent -force -deprovision+user"]
  }
}
```

---

## Verificación de resultados

### Azure
```bash
# Ver imagen creada
az image list --resource-group rg-packer-devops --output table

# Desplegar VM de prueba
az vm create \
  --resource-group rg-packer-devops \
  --name vm-test \
  --image ubuntu-nodejs-nginx \
  --size Standard_D2s_v3 \
  --location westus \
  --admin-username azureuser \
  --generate-ssh-keys

az vm open-port --port 80 --resource-group rg-packer-devops --name vm-test
curl http://$(az vm show -d -g rg-packer-devops -n vm-test --query publicIps -o tsv)
```

### GCP
```bash
# Ver imagen creada
gcloud compute images list --filter="name:ubuntu-nodejs-nginx-gcp"

# Desplegar VM de prueba
gcloud compute instances create vm-test-gcp \
  --image=ubuntu-nodejs-nginx-gcp \
  --machine-type=e2-medium \
  --zone=us-central1-a \
  --tags=http-server

gcloud compute firewall-rules create allow-http \
  --allow=tcp:80 --target-tags=http-server

curl http://$(gcloud compute instances describe vm-test-gcp \
  --zone=us-central1-a --format='get(networkInterfaces[0].accessConfigs[0].natIP)')
```

---

## Aprendizajes clave

1. **Infraestructura inmutable** — nunca modificar VMs en producción, siempre reconstruir la imagen.

2. **Variables sensitive** — las credenciales se declaran como `sensitive = true` y nunca aparecen en logs.

3. **`-force` en packer build** — necesario en pipelines CI/CD para reemplazar imágenes existentes automáticamente.

4. **`only` en provisioners** — permite compartir la mayoría del código entre nubes y aislar pasos específicos de cada proveedor.

5. **ADC en GCP** — más seguro que JSON keys para entornos de desarrollo local.

6. **Pop!_OS + repos externos** — siempre forzar el codename `jammy` en repos de terceros (HashiCorp, Microsoft), ya que Pop!_OS tiene ID de distro propio.

---

## Recursos

- [Packer Azure ARM Builder](https://developer.hashicorp.com/packer/integrations/hashicorp/azure)
- [Packer Google Compute Builder](https://developer.hashicorp.com/packer/integrations/hashicorp/googlecompute)
- [DigitalOcean — Node.js en producción Ubuntu 22.04](https://www.digitalocean.com/community/tutorials/how-to-set-up-a-node-js-application-for-production-on-ubuntu-22-04)
- [Azure CLI — Crear Service Principal](https://learn.microsoft.com/es-mx/cli/azure/ad/sp#az-ad-sp-create-for-rbac)
- [GCP — Application Default Credentials](https://cloud.google.com/docs/authentication/application-default-credentials)
