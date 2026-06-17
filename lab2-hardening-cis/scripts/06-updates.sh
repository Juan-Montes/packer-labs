#!/bin/bash
# =============================================================================
# CIS Ubuntu 22.04 LTS — Sección 6: System Maintenance
# Actualizaciones del sistema, parches automáticos de seguridad,
# integridad de archivos con AIDE
# =============================================================================
set -euo pipefail

echo ">>> CIS [6/6] System updates and maintenance..."

# --- 6.1 Actualizar completamente el sistema ---
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y
apt-get dist-upgrade -y
apt-get autoremove -y
apt-get autoclean -y

# --- 6.2 Configurar unattended-upgrades (parches automáticos) ---
apt-get install -y unattended-upgrades apt-listchanges

cat > /etc/apt/apt.conf.d/50unattended-upgrades << UNATTENDED
Unattended-Upgrade::Allowed-Origins {
  "\${distro_id}:\${distro_codename}";
  "\${distro_id}:\${distro_codename}-security";
  "\${distro_id}ESMApps:\${distro_codename}-apps-security";
  "\${distro_id}ESM:\${distro_codename}-infra-security";
};
Unattended-Upgrade::Package-Blacklist {};
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Automatic-Reboot-Time "02:00";
Unattended-Upgrade::Mail "root";
UNATTENDED

cat > /etc/apt/apt.conf.d/20auto-upgrades << AUTO
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
AUTO

systemctl enable unattended-upgrades

# --- 6.3 Inicializar AIDE (detector de intrusiones en archivos) ---
# AIDE crea una base de datos de hashes de archivos críticos
# En el primer arranque de la VM se ejecuta aide --check para detectar cambios
aideinit --yes 2>/dev/null || aide --init 2>/dev/null || true
mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db 2>/dev/null || true

# --- 6.4 Configurar logrotate para logs de seguridad ---
cat > /etc/logrotate.d/cis-security << LOGROTATE
/var/log/audit/audit.log {
  weekly
  rotate 4
  compress
  missingok
  notifempty
  postrotate
    /usr/sbin/service auditd restart 2>/dev/null || true
  endscript
}
/var/log/sudo.log {
  weekly
  rotate 4
  compress
  missingok
  notifempty
}
LOGROTATE

echo "✅ CIS Sección 6 completada — System maintenance"
echo ""
echo "============================================="
echo " Hardening CIS Level 1 completado"
echo " Imagen lista para validación con Goss"
echo "============================================="
