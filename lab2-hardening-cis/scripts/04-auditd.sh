#!/bin/bash
# =============================================================================
# CIS Ubuntu 22.04 LTS — Sección 4: Logging and Auditing
# auditd registra eventos críticos de seguridad: accesos a archivos
# sensibles, escalada de privilegios, cambios de sistema
# =============================================================================
set -euo pipefail

echo ">>> CIS [4/6] Configuring audit logging..."

# --- 4.1 Configuración principal de auditd ---
cat > /etc/audit/auditd.conf << AUDITD
log_file = /var/log/audit/audit.log
log_format = RAW
log_group = adm
priority_boost = 4
flush = INCREMENTAL_ASYNC
freq = 50
max_log_file = 50
num_logs = 5
max_log_file_action = ROTATE
space_left = 75
space_left_action = SYSLOG
admin_space_left = 50
admin_space_left_action = SUSPEND
disk_full_action = SUSPEND
disk_error_action = SUSPEND
AUDITD

# --- 4.2 Reglas de auditoría CIS ---
cat > /etc/audit/rules.d/99-cis.rules << RULES
# Borrar reglas existentes
-D

# Tamaño del buffer
-b 8192

# Acción ante fallo (2 = kernel panic, 1 = log y continuar)
-f 1

# --- Cambios de identidad ---
-w /etc/group    -p wa -k identity
-w /etc/passwd   -p wa -k identity
-w /etc/gshadow  -p wa -k identity
-w /etc/shadow   -p wa -k identity
-w /etc/security/opasswd -p wa -k identity

# --- Cambios de red ---
-a always,exit -F arch=b64 -S sethostname -S setdomainname -k system-locale
-w /etc/issue         -p wa -k system-locale
-w /etc/issue.net     -p wa -k system-locale
-w /etc/hosts         -p wa -k system-locale
-w /etc/network       -p wa -k system-locale

# --- Control de acceso obligatorio (AppArmor/SELinux) ---
-w /etc/apparmor/       -p wa -k MAC-policy
-w /etc/apparmor.d/     -p wa -k MAC-policy

# --- Inicio/cierre de sesión ---
-w /var/log/faillog  -p wa -k logins
-w /var/log/lastlog  -p wa -k logins
-w /var/log/tallylog -p wa -k logins

# --- Acciones de procesos ---
-w /var/run/utmp -p wa -k session
-w /var/log/wtmp -p wa -k logins
-w /var/log/btmp -p wa -k logins

# --- Control de acceso discrecional (permisos) ---
-a always,exit -F arch=b64 -S chmod -S fchmod -S fchmodat -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b64 -S chown -S fchown -S fchownat -S lchown -F auid>=1000 -F auid!=4294967295 -k perm_mod

# --- Acceso no autorizado ---
-a always,exit -F arch=b64 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EACCES -F auid>=1000 -F auid!=4294967295 -k access
-a always,exit -F arch=b64 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EPERM  -F auid>=1000 -F auid!=4294967295 -k access

# --- Uso de sudo ---
-w /etc/sudoers    -p wa -k scope
-w /etc/sudoers.d/ -p wa -k scope
-w /var/log/sudo.log -p wa -k actions

# --- Carga de módulos del kernel ---
-w /sbin/insmod  -p x -k modules
-w /sbin/rmmod   -p x -k modules
-w /sbin/modprobe -p x -k modules
-a always,exit -F arch=b64 -S init_module -S delete_module -k modules

# --- Hacer las reglas inmutables (requiere reboot para cambiar) ---
-e 2
RULES

# --- 4.3 Configurar rsyslog para retención de logs ---
cat >> /etc/rsyslog.conf << RSYSLOG

# CIS — Retención de logs
\$FileOwner root
\$FileGroup adm
\$FileCreateMode 0640
\$DirCreateMode 0755
\$Umask 0022
RSYSLOG

# --- 4.4 Habilitar y arrancar auditd ---
systemctl enable auditd
systemctl start auditd || true

# Cargar reglas
augenrules --load 2>/dev/null || auditctl -R /etc/audit/rules.d/99-cis.rules || true

echo "✅ CIS Sección 4 completada — Audit logging"
