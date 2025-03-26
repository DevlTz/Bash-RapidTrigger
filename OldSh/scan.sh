#!/bin/bash
# Script que compara IP externo e interno, faz nslookup e ping em ambos,
# verifica NAT e executa Nmap no IP interno para detectar serviços/OS.
# Resultados salvos em "scan_<ipinterno>_<timestamp>.txt" dentro de "scan_results/".

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
#  V E R I F I C A   #
# D E P E N D E N C I A S
######################
#

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
# Porta padrão para scan (pode ser alterada interativamente)
PORTS="21,22,25,80,110,111,143,443,465,587,993,995,1194,3000,3080,4422,6090"
# Flags Nmap padrão
NMAP_FLAGS="-A -T4 -Pn -sT -sC -O -sV -v"
HOSTNAME=$(hostname)
timestamp=$(date +%Y%m%d%H%M%S)

######################
# L E R   R A N G E  #
#   O U   I P Ú N I C O
######################
# Função que retorna um array de IPs (range ou único)
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
  
  echo -e "\n${BOLD}${WHITE}[VERIFICANDO O NAT]${RESET}"
  echo -e "=============================="
  echo -e "${BOLD}[+] IP Externo: ${YELLOW}${ip_externo}${RESET}"
  echo -e "${BOLD}[+] IP Interno: ${CYAN}${ip_interno}${RESET}\n"
  
  # Obtém o IP externo real via curl
  ip_externo_mano=$(curl -s4 ifconfig.me)
  echo -e "${BOLD}IP EXTERNO VERDADEIRO: ${MAGENTA}${ip_externo_mano}${RESET}"

  # Se o IP interno estiver em faixa privada
  if [[ "$ip_interno" =~ ^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[0-1])\.) ]]; then
    echo -e "${GREEN}✓ IP INTERNO está numa faixa privada!  ${RESET}"

    # Se o NAT estiver ativo, o real IP externo deverá ser diferente do IP interno
    if [[ "$ip_externo_mano" != "$ip_interno" ]]; then
      echo -e "${GREEN}✓ NAT detectado: IP externo ≠ IP interno. ${RESET}"
    else
      echo -e "${RED}✗ NAT not detectado: IP externo é igual ao IP interno.${RESET}"
    fi
    
    # Aviso se o IP externo informado diferir do real
    if [[ "$ip_externo" != "$ip_externo_mano" ]]; then
      echo -e "${YELLOW}⚠  AVISO: IP externo enviado é diferente do IP externo real! ${RESET}"
    fi
  else
    echo -e "${YELLOW}⚠  IP interno ($ip_interno) não está numa faixa privada. ${RESET}"
  fi
}

######################
# S C A N   D O   P A R
#  I P   E X T / I P I N T
######################
scan_pair() {
  local ip_externo="$1"
  local ip_interno="$2"
  local timestamp
  timestamp=$(date +%m%d%H%M%)
  local output_file="${RESULT_DIR}/scan_${ip_interno}_${timestamp}.txt"

  { 
    echo -e "${BOLD}${WHITE}\n[INICIANDO A BUSCA]${RESET}"
    echo -e "${BOLD}Par de IP's: ${YELLOW}${ip_externo}${RESET} ↔ ${CYAN}${ip_interno}${RESET}" 

    # NSLOOKUP + Ping do IP Externo
    echo -e "[NSLOOKUP para IP Externo] ($ip_externo) (usando DNS $DNS_SERVER)"
    nslookup "$ip_externo" "$DNS_SERVER"
    echo -e "${F_BOLD}${C_SLATEBLUE1}\nPing (4 pacotes) no IP Externo: ($ip_externo)${NO_FORMAT}"
    if ping -c 4 "$ip_externo" &>/dev/null; then
        echo -e "${GREEN}${ip_externo} responde a ping.${RESET}"
    else
        echo -e "${RED}${ip_externo} não responde a ping.${RESET}"
    fi

    # NSLOOKUP + Ping do IP Interno
    echo -e "\n[NSLOOKUP para IP Interno] ($ip_interno) (usando DNS $DNS_SERVER)"
    nslookup "$ip_interno" "$DNS_SERVER"
    echo -e "${F_BOLD}${C_SLATEBLUE1}\nPing (4 pacotes) no IP Interno: ($ip_interno)${NO_FORMAT}"
    if ping -c 4 "$ip_interno" &>/dev/null; then
        echo -e "${GREEN}${ip_interno} responde a ping.${RESET}"
    else
        echo -e "${RED}${ip_interno} não responde a ping.${RESET}"
    fi 
    
    # CHECK NAT
    check_nat "$ip_externo" "$ip_interno"

    # Execução do NMAP no IP Interno
    echo -e "\n${BOLD}[CONFIGURAÇÃO DO NMAP]${RESET}"
    read -p "Passe portas do seu interesse (Padrão): ${PORTS}) " custom_ports
    if [ -n "$custom_ports" ]; then
        PORTS="$custom_ports"
    fi
    read -p "Passe outras flags para o Nmap (opcional): " extra_flags
    local flags="${NMAP_FLAGS} ${extra_flags}"
    
    echo -e "\n${BOLD}[EXECUTANDO O SCAN DO NMAP]${RESET} em ${CYAN}${ip_interno}${RESET}"
    nmap_cmd="nmap -n ${flags} -p${PORTS} ${ip_interno}"
    echo -e "${BOLD}Commando: ${MAGENTA}${nmap_cmd}${RESET}"
    nmap_output=$(eval "$nmap_cmd")
    echo "$nmap_output"


    # Mostra hostname do IP Interno
    echo -e "\n${BOLD}[HOSTNAME ENCONTRADO!]${RESET}"
    hostname_output=$(nslookup "$ip_interno" "$DNS_SERVER" | grep 'name =')
    echo -e "${BLUE}${hostname_output}${RESET}"
    
    # Se detectar CentOS, marcar MIGRAR
     if echo "$nmap_output" | grep -qi "CentOS"; then
      echo -e "\n${BOLD}${RED}[ALERTA] Sistema Operacional CentOS detectado.${RESET} Status: ${YELLOW} MIGRAR!${RESET}"
    fi

    echo -e "\n--------------------------------------------------\n"
  } | tee "$output_file"
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

# Para cada IP externo, para cada IP interno, faz a verificação
for ip_ext in "${ips_externos[@]}"; do
  for ip_int in "${ips_internos[@]}"; do
    scan_pair "$ip_ext" "$ip_int"
  done
done

echo -e "\n${BOLD}${GREEN}✅ Varredura concluída!${RESET} Resultados em: ${YELLOW}${RESULT_DIR}${RESET}."

