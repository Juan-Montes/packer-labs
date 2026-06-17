#!/bin/bash
# =============================================================================
# CIS Ubuntu 22.04 LTS — Sección 3: Network Configuration
# Parámetros del kernel para protección contra ataques de red:
# IP spoofing, SYN floods, ICMP redirects, etc.
# =============================================================================
set -euo pipefail

echo ">>> CIS [3/6] Network hardening..."

# --- 3.1 Parámetros de red del kernel (sysctl) ---
cat > /etc/sysctl.d/99-cis-network.conf << SYSCTL
# CIS Ubuntu 22.04 — Network Hardening

# Deshabilitar IP forwarding (no es un router)
net.ipv4.ip_forward                    = 0
net.ipv6.conf.all.forwarding           = 0

# Deshabilitar envío de redirects ICMP
net.ipv4.conf.all.send_redirects       = 0
net.ipv4.conf.default.send_redirects   = 0

# Deshabilitar aceptación de redirects ICMP
net.ipv4.conf.all.accept_redirects     = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects     = 0

# Deshabilitar source routing
net.ipv4.conf.all.accept_source_route  = 0
net.ipv4.conf.default.accept_source_route = 0

# Habilitar protección SYN cookies (anti SYN flood)
net.ipv4.tcp_syncookies                = 1

# Reverse path filtering (anti IP spoofing)
net.ipv4.conf.all.rp_filter            = 1
net.ipv4.conf.default.rp_filter        = 1

# Ignorar ICMP broadcast (protección smurf)
net.ipv4.icmp_echo_ignore_broadcasts   = 1

# Ignorar respuestas ICMP falsas
net.ipv4.icmp_ignore_bogus_error_responses = 1

# Registrar paquetes con rutas imposibles (martians)
net.ipv4.conf.all.log_martians         = 1
net.ipv4.conf.default.log_martians     = 1

# Deshabilitar IPv6 (si no se usa)
net.ipv6.conf.all.disable_ipv6        = 1
net.ipv6.conf.default.disable_ipv6    = 1

# ASLR — aleatorización del espacio de direcciones
kernel.randomize_va_space              = 2

# Deshabilitar magic SysRq
kernel.sysrq                           = 0

# Restringir acceso a dmesg
kernel.dmesg_restrict                  = 1

# Proteger enlaces simbólicos y duros
fs.protected_symlinks                  = 1
fs.protected_hardlinks                 = 1
SYSCTL

# Aplicar inmediatamente
sysctl --system

echo "✅ CIS Sección 3 completada — Network"
