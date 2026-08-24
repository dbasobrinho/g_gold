#!/bin/bash
##############################################################################
# Nome: identifica_disks_oracleasm.sh
# Descrição: Identifica os discos do ASM, seus dispositivos no sistema operacional,
#            tamanhos e status no ASM. Permite filtrar os discos com um parâmetro de entrada.
# Autor: DBA Sobrinho
# Versão: 2.9
# Data: 2025-01-30
# Uso: Execute como root -> sh identifica_disks_oracleasm.sh [parametro]
#
# 📌 PRÉ-REQUISITOS:
# - O Grid Infrastructure deve estar instalado e configurado.
# - O comando oracleasm deve estar disponível no PATH.
# - O comando lsblk deve estar disponível para mapear os discos.
# - Executar com root ou sudo
#
# 📌 PARÂMETRO:
# - O script aceita um parâmetro opcional de entrada para filtrar os discos do ASM.
#   Se nenhum parâmetro for fornecido, todos os discos serão listados.
#   Exemplo de uso:
#   - Para listar todos os discos: 
#     sh identifica_disks_oracleasm.sh
#   - Para filtrar discos com um nome específico: 
#     sh identifica_disks_oracleasm.sh DISK1
##############################################################################
echo ". . ."
echo "========================================================================"
echo "=== Identificando discos ASM, tamanhos, dispositivos e status no ASM ==="
echo "========================================================================"
echo ". . ."
echo " "

if ! command -v oracleasm &> /dev/null; then
    echo "Erro: oracleasm não encontrado."
    exit 1
fi

##discos_asm=$(oracleasm listdisks | sort)
discos_asm=$(oracleasm listdisks | grep -E "${1:-.}" | sort)
if [ -z "$discos_asm" ]; then
    echo "Nenhum disco ASM encontrado."
    exit 1
fi 

asm_user=$(ps -ef | grep -iw "asm_pmon_" | grep -v grep | awk '{print $1}' | sort -u | head -n 1)
if [ -z "$asm_user" ]; then
    echo "Erro: Não foi possível identificar o usuário do ASM."
    exit 1
fi

asm_pmon_pid=$(ps -ef | grep -iw "asm_pmon_" | grep -v grep | awk '{print $2}' | head -n 1)
if [ -z "$asm_pmon_pid" ]; then
    echo "Erro: Não foi possível identificar o processo PMON do ASM."
    exit 1
fi

export ORACLE_HOME=$(tr '\0' '\n' < /proc/$asm_pmon_pid/environ | grep '^ORACLE_HOME=' | cut -d'=' -f2)
export ORACLE_BASE=$(tr '\0' '\n' < /proc/$asm_pmon_pid/environ | grep '^ORACLE_BASE=' | cut -d'=' -f2)
export ORACLE_SID=$(ps -ef | grep -iw "asm_pmon_" | grep -v grep | awk -F'_' '{print $NF}' | head -n 1)
export LD_LIBRARY_PATH=$ORACLE_HOME/lib
export PATH=$ORACLE_HOME/bin:$PATH

asm_disks_info=$(su - "$asm_user" -c "export ORACLE_HOME=$ORACLE_HOME; export PATH=\$ORACLE_HOME/bin:\$PATH; asmcmd lsdsk -p" 2>/dev/null)
if [ -z "$asm_disks_info" ]; then
    echo "Erro: Não foi possível obter informações dos discos ASM."
    exit 1
fi

scan_order=$(grep "^ORACLEASM_SCANORDER=" /etc/sysconfig/oracleasm | cut -d'=' -f2 | tr -d '"' | awk '{print $1}')

printf "%-30s %8s %-40s %-40s %-10s %-10s %-10s\n" "ASM_DISK" "SIZE" "OS_DEVICE" "PATH_DISK" "GROUP_NUM" "DISK_NUM" "STATUS"
printf "%-30s %8s %-40s %-40s %-10s %-10s %-10s\n" "------------------------------" "--------" "----------------------------------------" "----------------------------------------" "----------" "----------" "----------"

for disco in $discos_asm; do
    info_dispositivo=$(oracleasm querydisk -d "$disco" | awk -F'[][]' '{print $2}')
    major=$(echo "$info_dispositivo" | awk -F',' '{print $1}')
    minor=$(echo "$info_dispositivo" | awk -F',' '{print $2}')
    
	dispositivo=$(lsblk -o MAJ:MIN,NAME --noheadings | grep "^ *$major:$minor" | awk '{print $2}' | head -n 1 | tr -d '└─')

	if [ -z "$dispositivo" ]; then
		dispositivo="Desconhecido"
		tamanho="N/A"
	else
		dispositivo_base=$(oracleasm querydisk -p "$disco" | grep "$scan_order" | awk '{print $1}' | head -n 1)
		dispositivo_base=$(echo "$dispositivo_base" | sed 's/[[:space:]:]//g')


        ##echo $dispositivo_base
		if [ -n "$dispositivo_base" ] && [ -b "$dispositivo_base" ]; then
			tamanho=$(lsblk -no SIZE "$dispositivo_base" 2>/dev/null | awk '{print $NF}')
			##echo $tamanho
		else
			tamanho="Erro"
		fi
	fi

	diskgroup=$(echo "$asm_disks_info" | grep -w "$disco" | awk '{print $NF}')

    
    if [ -n "$diskgroup" ]; then
        group_num=$(echo "$asm_disks_info" | grep -w "$disco" | awk '{print $1}')
        disk_num=$(echo "$asm_disks_info" | grep -w "$disco" | awk '{print $2}')
        state=$(echo "$asm_disks_info" | grep -w "$disco" | awk '{print $6}')
    else
        state=$(echo "$asm_disks_info" | grep -w "$disco" | awk '{print $6}')
        [ -z "$state" ] && state="DESCONHECIDO"
        diskgroup="Nenhum"
        group_num="N/A"
        disk_num="N/A"
    fi

    printf "%-30s %8s %-40s %-40s %-10s %-10s %-10s\n" "$disco" "$tamanho" "$dispositivo_base" "$diskgroup" "$group_num" "$disk_num" "$state"
done

echo ". . ."
echo "========================================================================"
echo "===      O Guina Não Tinha Dó! Se Reagir, BUMMM... Vira Pó! 😎 🔥     ==="
echo "========================================================================"
echo ". . ."
