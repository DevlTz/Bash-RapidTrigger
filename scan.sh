#!/bin/bash
# Script que compara IP externo e interno, faz nslookup e ping em ambos,
# verifica NAT e executa Nmap no IP interno para detectar serviços/OS.
# Resultados salvos em "scan_<ipinterno>_<timestamp>.txt" dentro de "Scan_Results/".

######################
#    C O R E S       #
######################
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BLUE='\033[0;34m'
WHITE='\033[1;37m'
BOLD='\033[1m'
RESET='\033[0m'
NO_FORMAT='\033[0m'
F_BOLD='\033[1m'
C_SLATEBLUE1='\033[38;5;99m'
C_GREY100='\033[48;5;231m'

######################
# H E A D E R
######################
header() {
  clear
  echo -e "${BOLD}${WHITE}"
  echo "=================================================="
  echo "      ADVANCED NETWORK DIAGNOSTIC TOOL"
  echo "=================================================="
  echo -e "${RESET}"
  echo -e "${BOLD}Local Hostname: ${GREEN}${HOSTNAME}${RESET}"
  echo -e "${BOLD}Date/Time: ${GREEN}$(date)${RESET}\n"
}

######################
#  D E F I N I Ç Ã O  DE  LOG
######################
# A função log escreve a mensagem na tela e no arquivo de log, se definido.
log() {
  echo -e "$1"
  [ -n "$LOG_FILE" ] && echo -e "$1" >> "$LOG_FILE"
}

######################
# V E R I F I C A  D E  D E P E N D Ê N C I A S
######################
check_dependencies() {
  local deps=("nmap" "nslookup" "ping" "curl")
  local missing=()

  echo -e "\n${BOLD}${WHITE}Verificando dependências...${RESET}"
  for cmd in "${deps[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=("$cmd")
    fi
  done

  if [ ${#missing[@]} -gt 0 ]; then
    echo -e "${RED}✗ Dependências faltando:${RESET} ${missing[*]}"
    echo -e "${YELLOW}Instale com:${RESET}"
    for cmd in "${missing[@]}"; do
      case $cmd in
        nmap) echo "sudo apt-get install nmap" ;;
        *) echo "sudo apt-get install $cmd" ;;
      esac
    done
    exit 1
  else
    echo -e "${GREEN}✓ Todas dependências instaladas${RESET}"
  fi
}
check_dependencies

#################################################
# C O N F I G U R A Ç Ã O  I N I C I A L
#################################################
DNS_SERVER="8.8.8.8"
RESULT_DIR="Scan_Results"
mkdir -p "$RESULT_DIR"
# Lista de S.O para scan
S_O="CentOS,Ubuntu,Windows 2012,VMware Photon,Windows 2008,Windows 2016,Alma Linux 9"
# Porta padrão para scan (pode ser alterada interativamente)
PORTS="21,22,25,80,110,111,143,443,465,587,993,995,1194,3000,3080,4422,6090"
# Flags Nmap padrão
NMAP_FLAGS="-A -T4 -Pn -sT -sC -O -sV -v"
NMAP_FLAGS_2="-A -T4 -Pn -sS -f"
NMAP_FLAGS_4="-A -T4 -Pn -sS -D"
NMAP_FLAGS_3="-a -T4 -Pn -sT"
HOSTNAME=$(hostname)
timestamp=$(date +%Y%m%d%H%M%S)

######################
# L E R   R A N G E  /  I P ÚNICO
######################
fill_ips() {
  local prompt="$1"
  local ip_list=()

  read -p "Deseja configurar $prompt? (s/n or N): " config_resp
  [[ "$config_resp" =~ ^[nN] ]] && return

  read -p "Deseja scanear um range de IP para $prompt? (s/n): " use_range
  if [[ "$use_range" =~ ^[sS] ]]; then
      read -p "Digite o IP base (ex.: 192.168.0.): " ip_base
      read -p "Digite o valor inicial do último octeto: " start_octet
      read -p "Digite o valor final do último octeto: " end_octet
      for i in $(seq "$start_octet" "$end_octet"); do
          ip_list+=("${ip_base}${i}")
      done
  else
      read -p "Digite o IP: " single_ip
      ip_list+=("$single_ip")
  fi
  echo "${ip_list[@]}"
}

######################
#  S C A N  -  N A T 
######################
check_nat() {
  local ip_externo="$1"
  local ip_interno="$2"
  
  local ip_externo_mano
  ip_externo_mano=$(curl -s4 ifconfig.me)
  log "\n${BOLD}${WHITE}[VERIFICANDO O NAT]${RESET}"
  log "=============================="
  log "${BOLD}[+] IP Externo: ${YELLOW}${ip_externo}${RESET} ou ${YELLOW}${ip_externo_mano}${RESET}"
  log "${BOLD}[+] IP Interno: ${CYAN}${ip_interno}${RESET}\n"

 
  log "${BOLD}IP EXTERNO VERDADEIRO: ${MAGENTA}${ip_externo_mano}${RESET}"

  # Se o IP interno estiver em faixa privada
  if [[ "$ip_interno" =~ ^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[0-1])\.) ]]; then
    log "${GREEN}✓ IP INTERNO está numa faixa privada!${RESET}"

    # Se o NAT estiver ativo, o real IP externo deverá ser diferente do IP interno
    if [[ "$ip_externo_mano" != "$ip_interno" ]]; then
      log "${GREEN}✓ NAT detectado: IP externo ≠ IP interno.${RESET}"
    else
      log "${RED}✗ NAT não detectado: IP externo é igual ao IP interno.${RESET}"
    fi

    # Aviso se o IP externo informado diferir do real
    if [[ "$ip_externo" != "$ip_externo_mano" ]]; then
      log "${YELLOW}⚠  AVISO: IP externo enviado é diferente do IP externo real!${RESET}"
    fi
  else
    log "${YELLOW}⚠  IP interno ($ip_interno) não está numa faixa privada.${RESET}"
  fi
}

######################
# FUNÇÃO PARA DETECÇÃO DE S.O.
######################
detecta_so() {
  local nmap_out="$1"
  local found_os=()
  IFS=',' read -ra so_list <<< "$S_O"
  for os in "${so_list[@]}"; do
    if echo "$nmap_out" | grep -qi "$os"; then
      if [[ "$os" =~ ^[Cc]entOS$ ]]; then
        log "${RED}[ALERTA] Sistema Operacional ${os} detectado. Status: MIGRAR!${RESET}"
      else
        log "${CYAN}[INFO] Sistema Operacional ${os} detectado.${RESET}"
      fi
      found_os+=("$os")
    fi
  done
  if [ ${#found_os[@]} -eq 0 ]; then
    log "${YELLOW}[INFO] Nenhum S.O. conhecido foi detectado.${RESET}"
  fi
}

######################
# FUNÇÃO PARA CONFIGURAÇÃO DO NMAP
######################
configura_nmap() {
  local final_ports="$PORTS"
  local final_flags="$NMAP_FLAGS"
  read -p "Deseja alterar as configurações do NMAP? (s/n): " resp_nmap
  if [[ "$resp_nmap" =~ ^[sS] ]]; then
    read -p "Passe portas do seu interesse (Padrão: ${PORTS}): " custom_ports
    if [ -n "$custom_ports" ]; then
      final_ports="$custom_ports"
    fi
    read -p "Passe outras flags para o Nmap (opcional): " extra_flags
    final_flags="${NMAP_FLAGS} ${extra_flags}"
  fi
  # Retorna os valores via echo (separados por espaço)
  echo "$final_ports" "$final_flags"
}


######################
# S C A N   PARA IP INTERNO (apenas)
######################
scan_internal() {
  local ip_interno="$1"
  local ts
  ts=$(date +%m%d%H%M)
  LOG_FILE="${RESULT_DIR}/scan_${ip_interno}_${ts}.txt"
  > "$LOG_FILE"

  log "\n${BOLD}${WHITE}[INICIANDO A BUSCA - IP INTERNO]${RESET}"
  log "${BOLD}IP Interno: ${CYAN}${ip_interno}${RESET}"

  # NSLOOKUP e Ping do IP Interno
  log "\n[NSLOOKUP para IP Interno] ($ip_interno) (usando DNS $DNS_SERVER)"
  nslookup "$ip_interno" "$DNS_SERVER" | tee -a "$LOG_FILE"
  log "\n${F_BOLD}${C_SLATEBLUE1}Ping (4 pacotes) no IP Interno: ($ip_interno)${NO_FORMAT}"
  if ping -c 4 "$ip_interno" &>/dev/null; then
    log "${GREEN}${ip_interno} responde a ping.${RESET}"
  else
    log "${RED}${ip_interno} não responde a ping.${RESET}"
  fi

  # Configuração e execução do NMAP
  log "\n${BOLD}[CONFIGURAÇÃO DO NMAP]${RESET}"
  read -p "Deseja alterar as configurações do NMAP? (s/n): " resp_nmap
  if [[ "$resp_nmap" =~ ^[sS] ]]; then
    read -p "Passe portas do seu interesse (Padrão: ${PORTS}): " custom_ports
    [ -n "$custom_ports" ] && PORTS="$custom_ports"
    read -p "Passe outras flags para o Nmap (opcional): " extra_flags
    final_flags="${NMAP_FLAGS} ${extra_flags}"
  else
    final_flags="$NMAP_FLAGS"
  fi
  log "\n${BOLD}[EXECUTANDO O SCAN DO NMAP]${RESET} em ${CYAN}${ip_interno}${RESET}"
  local nmap_cmd="nmap -n ${final_flags} -p${PORTS} ${ip_interno}"
  log "${BOLD}Comando: ${MAGENTA}${nmap_cmd}${RESET}"
  local nmap_output
  nmap_output=$(eval "$nmap_cmd")
  log "$nmap_output"

  # Exibição do hostname do IP Interno
  log "\n${BOLD}[HOSTNAME ENCONTRADO!]${RESET}"
  local hostname_output
  hostname_output=$(nslookup "$ip_interno" "$DNS_SERVER" | grep 'name =')
  log "${BLUE}$hostname_output${RESET}"

  # Detecção de S.O.
  detecta_so "$nmap_output"

  log "\n--------------------------------------------------\n"
}

######################
# S C A N   PARA IP EXTERNO + IP INTERNO
######################
scan_pair() {
  local ip_externo="$1"
  local ip_interno="$2"
  local ts
  ts=$(date +%m%d%H%M)
  LOG_FILE="${RESULT_DIR}/scan_${ip_interno}_${ts}.txt"
  > "$LOG_FILE"

  log "\n${BOLD}${WHITE}[INICIANDO A BUSCA - PAR DE IPs]${RESET}"
  log "${BOLD}IP Externo: ${YELLOW}${ip_externo}${RESET}  ↔  IP Interno: ${CYAN}${ip_interno}${RESET}"

  # NSLOOKUP e Ping do IP Externo
  log "\n[NSLOOKUP para IP Externo] ($ip_externo) (usando DNS $DNS_SERVER)"
  nslookup "$ip_externo" "$DNS_SERVER" | tee -a "$LOG_FILE"
  log "\n${F_BOLD}${C_SLATEBLUE1}Ping (4 pacotes) no IP Externo: ($ip_externo)${NO_FORMAT}"
  if ping -c 4 "$ip_externo" &>/dev/null; then
    log "${GREEN}${ip_externo} responde a ping.${RESET}"
  else
    log "${RED}${ip_externo} não responde a ping.${RESET}"
  fi

  # NSLOOKUP e Ping do IP Interno
  log "\n[NSLOOKUP para IP Interno] ($ip_interno) (usando DNS $DNS_SERVER)"
  nslookup "$ip_interno" "$DNS_SERVER" | tee -a "$LOG_FILE"
  log "\n${F_BOLD}${C_SLATEBLUE1}Ping (4 pacotes) no IP Interno: ($ip_interno)${NO_FORMAT}"
  if ping -c 4 "$ip_interno" &>/dev/null; then
    log "${GREEN}${ip_interno} responde a ping.${RESET}"
  else
    log "${RED}${ip_interno} não responde a ping.${RESET}"
  fi

  # Verificação NAT
  check_nat "$ip_externo" "$ip_interno"

  # Configuração e execução do NMAP
  log "\n${BOLD}[CONFIGURAÇÃO DO NMAP]${RESET}"
  read -p "Deseja alterar as configurações do NMAP? (s/n): " resp_nmap
  if [[ "$resp_nmap" =~ ^[sS] ]]; then
    read -p "Passe portas do seu interesse (Padrão: ${PORTS}): " custom_ports
    [ -n "$custom_ports" ] && PORTS="$custom_ports"
    read -p "Passe outras flags para o Nmap (opcional): " extra_flags
    final_flags="${NMAP_FLAGS} ${extra_flags}"
  else
    final_flags="$NMAP_FLAGS"
  fi
  log "\n${BOLD}[EXECUTANDO O SCAN DO NMAP]${RESET} em ${CYAN}${ip_interno}${RESET}"
  local nmap_cmd="nmap -n ${final_flags} -p${PORTS} ${ip_interno}"
  log "${BOLD}Comando: ${MAGENTA}${nmap_cmd}${RESET}"
  local nmap_output
  nmap_output=$(eval "$nmap_cmd")
  log "$nmap_output"

  # Exibição do hostname do IP Interno
  log "\n${BOLD}[HOSTNAME ENCONTRADO!]${RESET}"
  local hostname_output
  hostname_output=$(nslookup "$ip_interno" "$DNS_SERVER" | grep 'name =')
  log "${BLUE}$hostname_output${RESET}"

  # Detecção de S.O.
  detecta_so "$nmap_output"

  log "\n--------------------------------------------------\n"
}

######################
#   P R I N C I P A L
######################
header

# Ler lista de IPs Externos
echo -e "\n--- CONFIGURAR IP(s) EXTERNO(s) ---"
mapfile -t ips_externos < <(fill_ips "IP EXTERNO")

# Ler lista de IPs Internos
echo -e "\n--- CONFIGURAR IP(s) INTERNO(s) ---"
mapfile -t ips_internos < <(fill_ips "IP INTERNO")

# Verifica se pelo menos um IP foi configurado
if [[ ${#ips_externos[@]} -eq 0 && ${#ips_internos[@]} -eq 0 ]]; then
  echo -e "${RED}Nenhum IP configurado! Pulando fora do programa. xD ${RESET}"
  exit 1
fi

# Para cada IP externo, para cada IP interno, executa a verificação
#for ip_ext in "${ips_externos[@]}"; do
 # for ip_int in "${ips_internos[@]}"; do
   # scan_pair "$ip_ext" "$ip_int"
  #done
#done

# Se IP externo não foi configurado, faz varredura somente no IP interno
if [ ${#ips_externos[@]} -eq 0 ]; then
  for ip_int in "${ips_internos[@]}"; do
    scan_internal "$ip_int"
  done
else
  # Se ambos foram configurados, para cada combinação executa o scan
  for ip_ext in "${ips_externos[@]}"; do
    for ip_int in "${ips_internos[@]}"; do
      scan_pair "$ip_ext" "$ip_int"
    done
  done
fi

echo -e "\n${BOLD}${GREEN}✅ Varredura concluída!${RESET} Resultados salvos em: ${YELLOW}${RESULT_DIR}${RESET}."

