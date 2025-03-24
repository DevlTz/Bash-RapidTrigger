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
RESET='\033[0m'

######################
#  V E R I F I C A   #
# D E P E N D E N C I A S
######################
for cmd in nmap nslookup ping; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo -e "${RED}O comando '$cmd' não está instalado. Instale-o e tente novamente.${RESET}"
    exit 1
  }
done

DNS_SERVER="8.8.8.8"
RESULT_DIR="scan_results"
mkdir -p "$RESULT_DIR"

# Lista de portas que você quer checar (HTTP, HTTPS, SSH, etc.)
PORTS="21,22,25,80,110,111,143,443,465,993,995,1194,3000,3080,4422,6090"

######################
# L E R   R A N G E  #
#   O U   I P Ú N I C O
######################
# Função que retorna um array de IPs (range ou único)
fill_ips() {
  local prompt="$1"
  local ip_list=()
  read -p "Deseja escanear um range de IP para $prompt? (s/n): " use_range
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
# S C A N   D O   P A R
#  I P   E X T / I P I N T
######################
scan_pair() {
  local ip_externo="$1"
  local ip_interno="$2"
  local timestamp
  timestamp=$(date +%Y%m%d%H%M%S)
  local output_file="${RESULT_DIR}/scan_${ip_interno}_${timestamp}.txt"

  {
    echo -e "=============================="
    echo -e "[+] IP Externo: ${YELLOW}${ip_externo}${RESET}"
    echo -e "[+] IP Interno: ${CYAN}${ip_interno}${RESET}\n"

    # NSLOOKUP + Ping do IP Externo
    echo -e "NSLOOKUP para IP Externo ($ip_externo) usando DNS $DNS_SERVER:"
    nslookup "$ip_externo" "$DNS_SERVER"
    echo -e "\nPing (2 pacotes) no IP Externo ($ip_externo):"
    if ping -c 2 "$ip_externo" &>/dev/null; then
        echo -e "${GREEN}${ip_externo} responde a ping.${RESET}"
    else
        echo -e "${RED}${ip_externo} não responde a ping.${RESET}"
    fi

    # NSLOOKUP + Ping do IP Interno
    echo -e "\nNSLOOKUP para IP Interno ($ip_interno) usando DNS $DNS_SERVER:"
    nslookup "$ip_interno" "$DNS_SERVER"
    echo -e "\nPing (2 pacotes) no IP Interno ($ip_interno):"
    if ping -c 2 "$ip_interno" &>/dev/null; then
        echo -e "${GREEN}${ip_interno} responde a ping.${RESET}"
    else
        echo -e "${RED}${ip_interno} não responde a ping.${RESET}"
    fi

    # Verificação de NAT (se IP interno for privado e for diferente do externo)
    if [[ "$ip_interno" =~ ^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[0-1])\.) ]]; then
        if [[ "$ip_interno" != "$ip_externo" ]]; then
            echo -e "\n[+] NAT ativo: IP externo (${ip_externo}) ≠ IP interno (${ip_interno})."
        else
            echo -e "\n[!] NAT não detectado: IP interno e externo são iguais."
        fi
    else
        echo -e "\n[!] O IP interno ($ip_interno) não está em faixa privada."
    fi

    # Execução do Nmap no IP Interno
    echo -e "\n[+] Executando Nmap para detectar serviços e OS em $ip_interno (portas de interesse)..."
    nmap_output=$(nmap -n -A -T4 -Pn -sT -sC -O -sV -v -p"$PORTS" "$ip_interno" 2>&1)
    echo "$nmap_output"

    # Se detectar CentOS, marcar MIGRAR
    if echo "$nmap_output" | grep -qi "CentOS"; then
        echo -e "\nSistema operacional CentOS detectado. Status: ${YELLOW}MIGRAR${RESET}."
    fi

    echo -e "\n--------------------------------------------------\n"
  } | tee "$output_file"
}

######################
#   P R I N C I P A L
######################
echo -e "${CYAN}=== Script de Verificação de IP Externo/Interno e NAT ===${RESET}"

# Ler lista de IPs Externos
echo -e "\n--- CONFIGURAR IP(s) EXTERNO(s) ---"
mapfile -t ips_externos < <(fill_ips "IP EXTERNO")

# Ler lista de IPs Internos
echo -e "\n--- CONFIGURAR IP(s) INTERNO(s) ---"
mapfile -t ips_internos < <(fill_ips "IP INTERNO")

# Para cada IP externo, para cada IP interno, faz a verificação
for ip_ext in "${ips_externos[@]}"; do
  for ip_int in "${ips_internos[@]}"; do
    scan_pair "$ip_ext" "$ip_int"
  done
done

echo -e "✅ Varredura concluída! Resultados em '${RESULT_DIR}'."

