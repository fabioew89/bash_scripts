#!/usr/bin/env bash
set -e

# ================================
# Configurações
# ================================
DOMAIN="clickip.local"                                  # Seu domínio AD
AD_USER="fabio.ewerton"                                 # Usuário com permissão de join
OU_PATH="DC=clickip,DC=local"                           # Opcional: "OU=Servers,DC=exemplo,DC=local"

# ================================
# Funções auxiliares
# ================================

msg() { echo -e "\n[INFO] $1\n"; }
err() { echo -e "\n[ERRO] $1\n"; exit 1; }

# ================================
# 1. Pacotes obrigatórios
# ================================
msg "Instalando pacotes necessários..."
apt update -y
apt install -y realmd sssd-ad sssd-tools adcli oddjob oddjob-mkhomedir packagekit samba-common-bin

# ================================
# 2. Descobrir domínio
# ================================
msg "Descobrindo o domínio $DOMAIN..."
realm discover "$DOMAIN" || err "Não foi possível detectar o domínio."

# ================================
# 3. Entrar no domínio
# ================================
JOIN_CMD="realm join $DOMAIN -U $AD_USER"

if [[ -n "$OU_PATH" ]]; then
    JOIN_CMD+=" --computer-ou=\"$OU_PATH\""
fi

msg "Ingressando no domínio..."
eval "$JOIN_CMD" || err "Falha no join ao domínio."

# ================================
# 4. Ativar criação automática de home
# ================================
msg "Ativando oddjob para criar home automaticamente..."
systemctl enable --now oddjobd

# Habilita no PAM
msg "Configurando PAM para oddjob-mkhomedir..."
pam-auth-update --enable mkhomedir

# ================================
# 5. Configurar acesso
# ================================
msg "Permitindo logins de usuários do domínio..."
realm permit --all

# ================================
# 6. Configurar SSSD
# ================================
msg "Gerando configuração customizada do SSSD..."

cat > /etc/sssd/sssd.conf <<EOF
[sssd]
domains = $DOMAIN
config_file_version = 2
services = nss, pam

[domain/$DOMAIN]
ad_domain = $DOMAIN
krb5_realm = ${DOMAIN^^}
realmd_tags = manages-system
cache_credentials = true
id_provider = ad
auth_provider = ad
chpass_provider = ad
access_provider = ad
enumerate = false
fallback_homedir = /home/%u
default_shell = /bin/bash
EOF

chmod 600 /etc/sssd/sssd.conf

# ================================
# 7. Reiniciar serviços
# ================================
msg "Reiniciando serviços SSSD..."
systemctl restart sssd

# ================================
# 8. Teste básico
# ================================
msg "Teste rápido de comunicação:"
realm list || err "Algo está errado. O domínio não aparece."

msg "Script finalizado! O servidor está no domínio."
msg "Teste com: id usuario@$DOMAIN"
