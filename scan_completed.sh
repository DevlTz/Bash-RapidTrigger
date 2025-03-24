#!/bin/bash
# Script para verificar se IPs da rede estão ativos, identificar o NAT, resolver hostname,
# detectar serviços e sistema operacional (flag "MIGRAR" para CentOS).
# Os resultados de cada IP são salvos em arquivos separados na pasta "scan_results".

DNS_SERVER="8.8.8.8"
RESULT_DIR="scan_results"
mkdir -p "$RESULT_DIR"

# Perguntar se deseja inserir um IP externo para verificação do NAT
read -p "Deseja inserir o IP externo para verificação de NAT? (s/n): " use_ext
if [[ "$use_ext" =~ ^[sS] ]]; then
    read -p "Digite o IP externo: " EXTERNAL_IP
else
    EXTERNAL_IP=""
fi

echo "Deseja escanear um range de IP? (s/n)"
read -r use_range

if [[ "$use_range" =~ ^[sS] ]]; then
    # Modo range: o usuário informa o IP base e o range do último octeto.
    read -p "Digite o IP base (ex.: 192.168.0.): " ip_base
    read -p "Digite o valor inicial do último octeto: " start_octet
    read -p "Digite o valor final do último octeto: " end_octet

    for i in $(seq "$start_octet" "$end_octet"); do
        current_ip="${ip_base}${i}"
        output_file="${RESULT_DIR}/scan_${current_ip}.txt"
        echo "==============================" | tee "$output_file"
        echo "Escaneando IP: $current_ip" | tee -a "$output_file"
        
        # nslookup
        echo "NSLOOKUP para $current_ip usando servidor $DNS_SERVER:" | tee -a "$output_file"
        nslookup "$current_ip" "$DNS_SERVER" 2>&1 | tee -a "$output_file"
        
        # Teste de Ping
        echo -e "\nTestando resposta a ping (2 pacotes)..." | tee -a "$output_file"
        if ping -c 2 "$current_ip" &> /dev/null; then
            echo "$current_ip responde a ping." | tee -a "$output_file"
        else
            echo "$current_ip não responde a ping." | tee -a "$output_file"
        fi
        
        # Verificação de NAT (apenas se o IP externo foi informado e o IP estiver em faixa privada)
        if [[ -n "$EXTERNAL_IP" ]]; then
            if [[ "$current_ip" =~ ^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[0-1])\.) ]]; then
                if [[ "$current_ip" != "$EXTERNAL_IP" ]]; then
                    echo "NAT ativo: IP externo ($EXTERNAL_IP) é diferente do IP interno ($current_ip)." | tee -a "$output_file"
                else
                    echo "NAT não detectado: IP interno e externo são iguais." | tee -a "$output_file"
                fi
            else
                echo "IP $current_ip não pertence a faixa privada." | tee -a "$output_file"
            fi
        fi
        
        # Execução do Nmap para identificar serviços e OS (portas comuns)
        echo -e "\nExecutando Nmap para verificar serviços e OS (portas comuns)..." | tee -a "$output_file"
        nmap_output=$(nmap -n -A -T4 -Pn -sT -sC -O -sV -v \
             -p21,22,25,80,110,143 \
             --script=vuln -g53 --mtu 8 -D 192.168.0.1 --open "$current_ip" 2>&1)
        echo "$nmap_output" | tee -a "$output_file"
        
        # Se o OS detectado for CentOS, marcar como MIGRAR
        if echo "$nmap_output" | grep -qi "CentOS"; then
            echo "Sistema operacional CentOS detectado. Status: MIGRAR." | tee -a "$output_file"
        fi
        
        echo -e "\n--------------------------------------------------\n" | tee -a "$output_file"
    done

else
    # Modo único: o usuário informa o IP a ser verificado.
    read -p "Digite o IP a ser verificado: " current_ip
    output_file="${RESULT_DIR}/scan_${current_ip}.txt"
    echo "==============================" | tee "$output_file"
    echo "Escaneando IP: $current_ip" | tee -a "$output_file"
    
    # nslookup
    echo "NSLOOKUP para $current_ip usando servidor $DNS_SERVER:" | tee -a "$output_file"
    nslookup "$current_ip" "$DNS_SERVER" 2>&1 | tee -a "$output_file"
    
    # Teste de Ping
    echo -e "\nTestando resposta a ping (2 pacotes)..." | tee -a "$output_file"
    if ping -c 2 "$current_ip" &> /dev/null; then
        echo "$current_ip responde a ping." | tee -a "$output_file"
    else
        echo "$current_ip não responde a ping." | tee -a "$output_file"
    fi
    
    # Verificação de NAT (se IP externo foi informado)
    if [[ -n "$EXTERNAL_IP" ]]; then
        if [[ "$current_ip" =~ ^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[0-1])\.) ]]; then
            if [[ "$current_ip" != "$EXTERNAL_IP" ]]; then
                echo "NAT ativo: IP externo ($EXTERNAL_IP) é diferente do IP interno ($current_ip)." | tee -a "$output_file"
            else
                echo "NAT não detectado: IP interno e externo são iguais." | tee -a "$output_file"
            fi
        else
            echo "IP $current_ip não pertence a faixa privada." | tee -a "$output_file"
        fi
    fi
    
    # Execução do Nmap para identificar serviços e OS (portas comuns)
    echo -e "\nExecutando Nmap para verificar serviços e OS (portas comuns)..." | tee -a "$output_file"
    nmap_output=$(nmap -n -A -T4 -Pn -sT -sC -O -sV -v \
         -p21,22,25,80,110,143 \
         --script=vuln -g53 --mtu 8 -D 192.168.0.1 --open "$current_ip" 2>&1)
    echo "$nmap_output" | tee -a "$output_file"
    
    # Se o OS detectado for CentOS, marcar como MIGRAR
    if echo "$nmap_output" | grep -qi "CentOS"; then
        echo "Sistema operacional CentOS detectado. Status: MIGRAR." | tee -a "$output_file"
    fi

fi

echo "✅ Varredura concluída! Os resultados foram salvos na pasta '$RESULT_DIR'."

