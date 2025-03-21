#!/bin/bash

# Uso: ./scan.sh <domínio ou IP> [IP_externo_para_nslookup]

# Definições iniciais
DNS_SERVER="8.8.8.8"
ALVO=$1           # Alvo (IP ou domínio) a ser escaneado
EXTERNO=$2        # IP externo a ser verificado, se informado

# Verifica se o alvo foi informado
if [ -z "$ALVO" ]; then
    echo "Uso: $0 <domínio ou IP> [IP_externo_para_nslookup]"
    exit 1
fi

echo "🔍 Fazendo NSLOOKUP para $ALVO no servidor $DNS_SERVER..."
nslookup "$ALVO" "$DNS_SERVER"

# Se o IP externo não foi passado como argumento, pede ao usuário
if [ -z "$EXTERNO" ]; then
    read -p "Nenhum IP externo informado. Digite o IP externo a ser verificado: " EXTERNO
fi

echo "🔍 Fazendo NSLOOKUP para o IP externo $EXTERNO no servidor $DNS_SERVER..."
nslookup "$EXTERNO" "$DNS_SERVER"

echo "🔎 Executando Nmap no alvo..."
# Remove a flag -f para evitar erro fragscan; ajusta --mtu para 8 se necessário
nmap -n -A -T4 -Pn -sT -sC -O -sV -v -p25 --script=vuln -g53 --mtu 8 -D 192.168.0.1 --open "$ALVO"

echo "🔎 Executando Nmap no alvo com verificação nas portas SMTP, POP3 & IMAP..."
nmap -n -A -T4 -Pn -sT -sC -O -sV -v -p25,110,143 --script=vuln -g53 --mtu 8 -D 192.168.0.1 --open "$ALVO"

echo "✅ Varredura concluída!"
