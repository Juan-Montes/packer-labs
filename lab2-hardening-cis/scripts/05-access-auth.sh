#!/bin/bash
# =============================================================================
# CIS Ubuntu 22.04 LTS — Sección 5: Access, Authentication and Authorization
# SSH hardening, políticas de contraseñas, sudo seguro, fail2ban
# =============================================================================
set -euo pipefail

echo ">>> CIS [5/6] Access and authentication hardening..."

# --- 5.1 SSH Hardening ---
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

cat > /etc/ssh/sshd_config << SSH
# CIS Ubuntu 22.04 — SSH Hardening

Protocol 2
Port 22

# Autenticación
PermitRootLogin no
PasswordAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes
PubkeyAuthentication yes

# Seguridad de sesión
LoginGraceTime 60
MaxAuthTries 3
MaxSessions 4
ClientAliveInterval 300
ClientAliveCountMax 0

# Restricciones
AllowAgentForwarding no
AllowTcpForwarding no
X11Forwarding no
PrintMotd no
PermitUserEnvironment no
IgnoreRhosts yes
HostbasedAuthentication no

# Algoritmos seguros (CIS recomendados)
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group14-sha256,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512
Ciphers chacha20-poly1305@openssh.com,aes128-ctr,aes192-ctr,aes256-ctr,aes128-gcm@openssh.com,aes256-gcm@openssh.com
MACs umac-128-etm@openssh.com,umac-256-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com

# Logging
LogLevel VERBOSE
SyslogFacility AUTH

# Banner
Banner /etc/issue.net
SSH

# Corregir permisos de sshd_config
chmod 600 /etc/ssh/sshd_config

# --- 5.2 Banner de advertencia legal ---
cat > /etc/issue.net << BANNER
*******************************************************************************
             SISTEMA DE ACCESO RESTRINGIDO — ACCESO AUTORIZADO ÚNICAMENTE
*******************************************************************************
El uso no autorizado de este sistema está prohibido y será procesado conforme
a las leyes aplicables. Toda actividad es monitoreada y registrada.
*******************************************************************************
BANNER

cat > /etc/issue << BANNER
*******************************************************************************
             SISTEMA DE ACCESO RESTRINGIDO — ACCESO AUTORIZADO ÚNICAMENTE
*******************************************************************************
BANNER

# --- 5.3 Política de contraseñas (PAM pwquality) ---
cat > /etc/security/pwquality.conf << PWQUALITY
minlen = 14
dcredit = -1
ucredit = -1
ocredit = -1
lcredit = -1
maxrepeat = 3
maxsequence = 3
gecoscheck = 1
dictcheck = 1
PWQUALITY

# --- 5.4 Configuración PAM para contraseñas ---
cat > /etc/pam.d/common-password << PAM
# CIS Ubuntu 22.04 — Password policy
password requisite pam_pwquality.so retry=3
password [success=1 default=ignore] pam_unix.so obscure use_authtok try_first_pass yescrypt remember=5
password requisite pam_deny.so
password required pam_permit.so
PAM

# --- 5.5 Lockout por intentos fallidos ---
cat > /etc/pam.d/common-auth << PAM
# CIS Ubuntu 22.04 — Account lockout
auth required pam_faillock.so preauth silent audit deny=5 unlock_time=900
auth [success=1 default=ignore] pam_unix.so nullok
auth [default=die] pam_faillock.so authfail audit deny=5 unlock_time=900
auth sufficient pam_faillock.so authsucc audit deny=5 unlock_time=900
auth requisite pam_deny.so
auth required pam_permit.so
PAM

# --- 5.6 fail2ban para SSH ---
cat > /etc/fail2ban/jail.local << FAIL2BAN
[DEFAULT]
bantime  = 3600
findtime = 600
maxretry = 3
backend  = systemd

[sshd]
enabled  = true
port     = ssh
logpath  = %(sshd_log)s
maxretry = 3
bantime  = 86400
FAIL2BAN

systemctl enable fail2ban

# --- 5.7 Sudo seguro ---
cat > /etc/sudoers.d/99-cis << SUDO
Defaults use_pty
Defaults logfile="/var/log/sudo.log"
Defaults log_input
Defaults log_output
Defaults !visiblepw
Defaults always_set_home
Defaults match_group_by_gid
Defaults always_query_group_plugin
Defaults env_reset
Defaults timestamp_timeout=5
SUDO

chmod 440 /etc/sudoers.d/99-cis

# --- 5.8 Deshabilitar cuentas de sistema innecesarias ---
for user in games gnats irc list news sync uucp; do
  usermod -s /usr/sbin/nologin "$user" 2>/dev/null || true
done

echo "✅ CIS Sección 5 completada — Access & Auth"
