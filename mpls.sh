#!/usr/bin/env bash

USERNAME="fabio.ewerton"

RED="\e[31;1m"
GREEN="\e[32;1m"
YELLOW="\e[33;1m"
RESET="\e[0m"

ssh_config(){
  # Captura saída do SSH
  ssh_output=$(sshpass -f pass_file ssh -o StrictHostKeyChecking=no -q "$USERNAME"@"$1" 2>&1 << EOF
  config

  mpls ldp lsr-id loopback-0 neighbor targeted 100.127.0.203
  mpls ldp lsr-id loopback-0 neighbor targeted 100.127.0.204

  mpls l2vpn
  vpls-group tunnel-$2
    vpn $2
    vfi
      pw-type vlan
      neighbor 100.127.0.203
      pw-id $2
      pw-mtu 1600
      pw-load-balance
        flow-label both
      !
    !
      neighbor 100.127.0.204
      pw-id $2
      pw-mtu 1600
      pw-load-balance
        flow-label both
      !
    !

  top
  commit label bash comment "config mpls tunnel-$2"
  do show mpls l2vpn vpls-group brief | include $2
  exit

EOF
)
  
  # Verifica se houve erro na saída
  if echo "$ssh_output" | grep -iE "(aborted|error|invalid|failed|reject)" > /dev/null; then
    echo -e "${RED}[✗] ERRO na configuração!${RESET}"
    echo ""
    echo -e "${RED}Saída do switch:${RESET}"
    echo -e "${RED}$ssh_output${RESET}"
    echo ""
    
    # Captura configuração atual do tunnel
    echo -e "${YELLOW}[*] Consultando configuração atual do tunnel...${RESET}"
    current_config=$(sshpass -f pass_file ssh -o StrictHostKeyChecking=no -q "$USERNAME"@"$1" "show running-config mpls l2vpn vpls-group tunnel-$2" 2>&1)
    echo ""
    echo -e "${YELLOW}════════════════════════════════════════${RESET}"
    echo -e "${YELLOW}Configuração Atual do Tunnel:${RESET}"
    echo -e "${YELLOW}════════════════════════════════════════${RESET}"
    echo -e "${YELLOW}$current_config${RESET}"
    echo -e "${YELLOW}════════════════════════════════════════${RESET}"
    echo ""
    echo -e "${YELLOW}════════════════════════════════════════${RESET}"
    echo -e "${YELLOW}DICAS PARA DEBUG:${RESET}"
    echo -e "${YELLOW}════════════════════════════════════════${RESET}"
    echo -e "${YELLOW}Conectar manualmente (já com sshpass):${RESET}"
    echo -e "${RED}sshpass -f pass_file ssh -o StrictHostKeyChecking=no -q $USERNAME@$1${RESET}"
    echo ""
    echo -e "${YELLOW}Entrar na config do tunnel:${RESET}"
    echo -e "${RED}config ; show mpls l2vpn vpls-group tunnel-$2${RESET}"
    echo -e "${YELLOW}════════════════════════════════════════${RESET}"
    echo ""
    echo -e "${YELLOW}Deletar a config do tunnel:${RESET}"
    echo -e "${RED}no mpls l2vpn vpls-group tunnel-$2 ; commit${RESET}"
    echo -e "${YELLOW}════════════════════════════════════════${RESET}"
    echo ""
    return 1
  else
    echo -e "${GREEN}[✓] Configuração aplicada com sucesso!${RESET}"
    echo ""
    echo -e "${GREEN}════════════════════════════════════════${RESET}"
    echo -e "${GREEN}Brief dos Tuneis:${RESET}"
    echo -e "${GREEN}════════════════════════════════════════${RESET}"
    echo "$ssh_output" | tail -20
    echo -e "${GREEN}════════════════════════════════════════${RESET}"
    echo ""
    return 0
  fi
}

show_help(){
cat << HELP
================================================================================
                    MPLS L2VPN Configuration Script
================================================================================

USAGE:
    $(basename "$0") [-h|--help] <IP> <VLAN>

DESCRIPTION:
    Configura MPLS L2VPN em switches remotos via SSH.
    Estabelece Virtual Private LAN Service com dois neighbors para redundância.

PARAMETERS:
    -h, --help          Mostra esta ajuda
    <IP>                IP do switch/roteador (ex: 192.168.1.1)
    <VLAN>              ID da VLAN/Tunnel (ex: 100)

EXAMPLES:
    $(basename "$0") -h
    $(basename "$0") 192.168.1.1 100

REQUIREMENTS:
    - sshpass instalado
    - pass_file com senha configurada
    - Acesso SSH ao switch

================================================================================
HELP
}

# Verifica se não há argumentos
if [[ $# -eq 0 ]]; then
    echo "ERROR: Nenhum parâmetro fornecido!"
    echo ""
    show_help
    exit 1
fi

# Processa argumentos
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            IP="$1"
            VLAN="$2"
            break
            ;;
    esac
done

# Valida parâmetros obrigatórios
if [[ -z "$IP" ]] || [[ -z "$VLAN" ]]; then
    echo "ERROR: Parâmetros IP e VLAN são obrigatórios!"
    echo ""
    show_help
    exit 1
fi

# Executa configuração
echo -e "${GREEN}[+] Iniciando configuração MPLS para $IP (VLAN $VLAN)${RESET}"
ssh_config "$IP" "$VLAN"

if [[ $? -eq 0 ]]; then
    echo
else
    echo -e "${RED}[✗] Configuração FALHOU!${RESET}"
    echo
    exit 1
fi
