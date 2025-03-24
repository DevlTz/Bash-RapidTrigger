#!/bin/bash
# Script para verificar se IPs da rede estão ativos, identificar o NAT (comparando IP externo e interno),
# resolver hostname, detectar serviços e sistema operacional (flag "MIGRAR" para CentOS).
# Os resultados de cada IP interno são salvos em arquivos separados na pasta "scan_results".

#########################
#      C O R E S       #
#########################
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

#########################
#   V E R I F I C A R   #
# D E P E N D Ê N C I A S#
#########################
for cmd in nmap nslookup ping; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo -e "${RED}O comando '$cmd' não está instalado. Instale-o e tente novamente.${RESET}"
    exit 1
  }
done

DNS_SERVER="8.8.8.8"
RESULT_DIR="scan_results"
mkdir -p "$RESULT_DIR"

#########################
# F U N Ç Ã O   P A R A #
#   L E R   I P (S)     #
#########################
# fill_ips: lê se o usuário quer escanear um range ou um único IP.
# Retorna um array de IPs (via echo).
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
      # Modo único
      read -p "Digite o IP: " single_ip
      ip_list+=("$single_ip")
  fi

  # Retorna o array como string (quem chamar a função deve capturar via "mapfile -t" ou similar)
  echo "${ip_list[@]}"
}

#########################
# F U N Ç Ã O   D E     #
#  S C A N   E   N A T  #
#########################
scan_ip() {
    local ip_interno="$1"
    local ip_externo="$2"
    local timestamp
    timestamp=$(date +%Y%m%d%H%M%S)
    local output_file="${RESULT_DIR}/scan_${ip_interno}_${timestamp}.txt"

    {
      echo -e "=============================="
      echo -e "Escaneando IP Interno: ${CYAN}${ip_interno}${RESET}"
      if [[ -n "$ip_externo" ]]; then
        echo -e "IP Externo (NAT): ${YELLOW}${ip_externo}${RESET}"
      fi

      # Resolução de hostname via nslookup
      echo -e "\n[+] NSLOOKUP para ${ip_interno} usando servidor ${DNS_SERVER}:"
      nslookup "$ip_interno" "$DNS_SERVER"

      # Teste de ping
      echo -e "\n[+] Testando resposta a ping (2 pacotes) em ${ip_interno}..."
      if ping -c 2 "$ip_interno" &>/dev/null; then
          echo -e "${GREEN}${ip_interno} responde a ping.${RESET}"
      else
          echo -e "${RED}${ip_interno} não responde a ping.${RESET}"
      fi

      # Verificação de NAT
      # Se tivermos ip_externo e o ip_interno estiver em faixa privada, comparam
      if [[ -n "$ip_externo" ]]; then
          if [[ "$ip_interno" =~ ^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[0-1])\.) ]]; then
              if [[ "$ip_interno" != "$ip_externo" ]]; then
                  echo -e "[+] NAT ativo: IP externo (${ip_externo}) é diferente do IP interno (${ip_interno})."
              else
                  echo -e "[!] NAT não detectado: IP interno e externo são iguais."
              fi
          else
              echo -e "[!] ${ip_interno} não pertence à faixa privada."
          fi
      fi

      # Execução do Nmap para detectar serviços e OS
      echo -e "\n[+] Executando Nmap para verificar serviços e OS (portas comuns) em ${ip_interno}..."
      # Opção recomendada (sem -f, sem --mtu 24) e com as portas mais comuns
      nmap_output=$(nmap -n -A -Pn -sT -sC --script=vuln -g53 -D 192.168.0.1 \
             -p21,22,25,80,110,143 "$ip_interno" 2>&1)
      echo "$nmap_output"
      
      # Verifica se o OS detectado é CentOS e marca como MIGRAR
      if echo "$nmap_output" | grep -qi "CentOS"; then
          echo -e "\nSistema operacional CentOS detectado. Status: ${YELLOW}MIGRAR${RESET}."
      fi

      echo -e "\n--------------------------------------------------\n"
    } | tee "$output_file"
}

#########################
#   M A I N   L O G I C #
#########################

echo -e "${CYAN}Bem-vindo ao script de verificação de IPs Internos/Externos com NAT!${RESET}"

# Ler IPs Externos
echo -e "\n--- Configuração de IPs EXTERNOS (NAT) ---"
mapfile -t ips_externos < <(fill_ips "IP EXTERNO (NAT)")
# Ler IPs Internos
echo -e "\n--- Configuração de IPs INTERNOS ---"
mapfile -t ips_internos < <(fill_ips "IP INTERNO")

# Loop duplo: para cada IP externo, escanear cada IP interno
for ip_ext in "${ips_externos[@]}"; do
  for ip_int in "${ips_internos[@]}"; do
    scan_ip "$ip_int" "$ip_ext"
  done
done

echo -e "✅ Varredura concluída! Os resultados foram salvos na pasta '${RESULT_DIR}'."

