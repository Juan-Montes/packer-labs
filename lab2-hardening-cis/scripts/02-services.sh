#!/bin/bash
# =============================================================================
# CIS Ubuntu 22.04 LTS — Sección 2: Services
# Eliminar y deshabilitar servicios innecesarios que amplían
# la superficie de ataque
# =============================================================================
set -euo pipefail

echo ">>> CIS [2/6] Disabling unnecessary services..."

# --- 2.1 Servicios a eliminar completamente ---
PACKAGES_TO_REMOVE=(
  "xserver-xorg*"
  "avahi-daemon"
  "cups"
  "isc-dhcp-server"
  "slapd"
  "nfs-kernel-server"
  "bind9"
  "vsftpd"
  "apache2"
  "dovecot-imapd"
  "dovecot-pop3d"
  "samba"
  "squid"
  "snmpd"
  "telnet"
  "rsh-client"
  "talk"
  "nis"
)

for pkg in "${PACKAGES_TO_REMOVE[@]}"; do
  apt-get purge -y "$pkg" 2>/dev/null || true
done

# --- 2.2 Servicios a deshabilitar (pueden estar instalados) ---
SERVICES_TO_DISABLE=(
  "bluetooth"
  "avahi-daemon"
  "cups"
  "nfs-server"
  "rpcbind"
)

for svc in "${SERVICES_TO_DISABLE[@]}"; do
  systemctl disable "$svc" 2>/dev/null || true
  systemctl stop "$svc" 2>/dev/null || true
done

# --- 2.3 Instalar y habilitar servicios de seguridad requeridos ---
apt-get update -y || true
apt-get install -y \
  ufw \
  aide \
  libpam-pwquality \
  fail2ban \
  auditd \
  audispd-plugins

# --- 2.4 Configurar UFW (firewall básico) ---
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw --force enable

echo "✅ CIS Sección 2 completada — Services"
