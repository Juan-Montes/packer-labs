# 🧪 Packer Labs

Repositorio de prácticas con **HashiCorp Packer** para la creación de imágenes
de máquina virtual inmutables en entornos multinube.

## ¿Qué es Packer?

Packer es una herramienta de HashiCorp que automatiza la creación de imágenes
de máquina virtual idénticas para múltiples plataformas desde una única fuente
de configuración en formato HCL2. El resultado es una imagen inmutable que puede
desplegarse en cualquier momento con garantía de consistencia.

## Concepto clave: Build vs Deploy

```
packer build  →  Imagen inmutable  →  az vm create / gcloud compute instances create
    (una vez)        (artefacto)              (n veces)
```

La imagen se construye una sola vez y se despliega cuantas veces se necesite.
Nunca se modifica una VM en producción — si hay cambios, se construye una nueva imagen.

## Prácticas

| Lab | Descripción | Nubes | Stack | Estado |
|-----|-------------|-------|-------|--------|
| [lab1-nodejs-nginx](./lab1-nodejs-nginx) | Imagen con Node.js + PM2 + Nginx | Azure + GCP | Ubuntu 22.04 LTS | ✅ |

## Estructura del repositorio

```
packer-labs/
├── README.md
├── .gitignore                      ← protege credenciales
└── lab1-nodejs-nginx/
    ├── GUIDE.md                    ← guía paso a paso del lab
    ├── azure-nodejs.pkr.hcl        ← template Packer (Ejercicios 1 y 2)
    ├── multicloud.pkr.hcl          ← template multinube (Ejercicio 3)
    ├── azure.pkrvars.hcl.example   ← variables Azure (sin credenciales)
    ├── gcp.pkrvars.hcl.example     ← variables GCP (sin credenciales)
    ├── deploy.sh                   ← despliegue automatizado
    ├── setup-azure.sh              ← prerrequisitos Azure
    └── app/
        ├── hello.js                ← aplicación Node.js
        └── ecosystem.config.js     ← configuración PM2
```

## Requisitos generales

- [Packer CLI](https://developer.hashicorp.com/packer/downloads) v1.10+
- [Azure CLI](https://learn.microsoft.com/es-mx/cli/azure/install-azure-cli) v2.50+
- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) v572+
- Cuenta Azure con suscripción activa
- Cuenta GCP con proyecto y Compute Engine API habilitada

## Seguridad — reglas de oro

- Los archivos `*.pkrvars.hcl` **nunca** se suben al repositorio
- Las credenciales van en variables marcadas como `sensitive = true`
- Usar `.pkrvars.hcl.example` como plantilla para documentar sin exponer secretos
- En GCP usar **Application Default Credentials (ADC)** en lugar de JSON keys

## Materia

Herramientas de DevOps — UNIR  
Maestría en Ingeniería de Software y Sistemas Informáticos
