#!/bin/bash
# =============================================================================
# CIS Ubuntu 22.04 LTS — Sección 1: Filesystem Configuration
# Controles: particiones seguras, módulos innecesarios deshabilitados,
# permisos de archivos críticos del sistema
# =============================================================================
set -euo pipefail

echo ">>> CIS [1/6] Filesystem hardening..."

# --- 1.1 Deshabilitar sistemas de archivos innecesarios ---
cat > /etc/modprobe.d/cis-filesystem.conf << MODULES
install cramfs /bin/true
install freevxfs /bin/true
install jffs2 /bin/true
install hfs /bin/true
install hfsplus /bin/true
install squashfs /bin/true
install udf /bin/true
install vfat /bin/true
MODULES

# --- 1.2 Sticky bit en directorios world-writable ---
df --local -P | awk '{if (NR!=1) print $6}' | xargs -I '{}' \
  find '{}' -xdev -type d \( -perm -0002 -a ! -perm -1000 \) 2>/dev/null \
  -exec chmod a+t {} \; || true

# --- 1.3 Permisos en archivos críticos del sistema ---
chmod 644 /etc/passwd
chmod 640 /etc/shadow
chmod 644 /etc/group
chmod 640 /etc/gshadow
chmod 600 /boot/grub/grub.cfg 2>/dev/null || true

# --- 1.4 Deshabilitar automontaje (autofs) ---
systemctl disable autofs 2>/dev/null || true
apt-get remove -y autofs 2>/dev/null || true

echo "✅ CIS Sección 1 completada — Filesystem"
