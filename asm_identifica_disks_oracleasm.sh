#!/bin/bash
################################################################################
# 📌 Nome      : asm_identifica_disks_oracleasm.sh
# 📌 Script    : https://github.com/dbasobrinho/g_gold/blob/master/asm_identifica_disks_oracleasm.sh
# 📌 Autor     : Roberto Sobrinho >> https://dbasobrinho.com.br/
# 📌 Versão    : 2.7
# 📌 Data      : 2025-02-04
# 📌 Licença   : MIT (ou outra, se aplicável)
#
# 📌 Descrição :
#   → Identifica os discos do ASM, seus dispositivos no sistema operacional, 
#     tamanhos e status no ASM.
#
# 📌 Uso       :
#   → Execute como root: 
#       sudo ./asm_identifica_disks_oracleasm.sh
#
# 📌 Pré-requisitos :
#   ✔️ Grid Infrastructure instalado e configurado.
#   ✔️ O comando 'oracleasm' deve estar disponível no PATH.
#   ✔️ O comando 'lsblk' deve estar disponível para mapear os discos.
#
# 📌 Exemplo de Saída:
#
#   ASM_DISK                           SIZE OS_DEVICE                                PATH_DISK                                GROUP_NUM  DISK_NUM   STATUS
#   ------------------------------ -------- ---------------------------------------- ---------------------------------------- ---------- ---------- ----------
#   DISKRQ_DATA_01                      20G /dev/mapper/mpath_DISKRQ_DATA_00         /dev/oracleasm/disks/DISKRQ_DATA_01      1          0          ONLINE
#   DISKRQ_REDO1                         5G /dev/mapper/mpath_DISKRQ_REDO1_00        /dev/oracleasm/disks/DISKRQ_REDO1        2          0          ONLINE
#   DISKRQ_REDO2                         5G /dev/mapper/mpath_DISKRQ_REDO2_00        /dev/oracleasm/disks/DISKRQ_REDO2        3          0          ONLINE
#   DISKPIP1_DATA_00                   100G /dev/mapper/mpath_DISKPIP1_DATA_00       /dev/oracleasm/disks/DISKPIP1_DATA_00    4          0          ONLINE
#   DISKPIP1_DATA_01                   100G /dev/mapper/mpath_DISKPIP1_DATA_01       /dev/oracleasm/disks/DISKPIP1_DATA_01    4          1          ONLINE
#   DISKPIP1_DATA_02                   100G /dev/mapper/mpath_DISKPIP1_DATA_02       /dev/oracleasm/disks/DISKPIP1_DATA_02    4          2          ONLINE
#   DISKPIP1_DATA_03                   100G /dev/mapper/mpath_DISKPIP1_DATA_03       /dev/oracleasm/disks/DISKPIP1_DATA_03    4          3          ONLINE
#   DISKPIP1_DATA_04                   100G /dev/mapper/mpath_DISKPIP1_DATA_04       /dev/oracleasm/disks/DISKPIP1_DATA_04    4          4          ONLINE
#
################################################################################


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

if ! command -v oracleasm &> /dev/null; then
    oracleasm_bin=$(find /usr /bin /sbin /usr/sbin /usr/local/bin -name oracleasm 2>/dev/null | head -n 1)

    if [ -z "$oracleasm_bin" ]; then
        echo "Erro: oracleasm não encontrado no sistema."
        exit 1
    fi
    export PATH=$(dirname "$oracleasm_bin"):$PATH
    echo "Aviso: oracleasm não estava no PATH. Adicionado temporariamente de $(dirname "$oracleasm_bin")"
fi

discos_asm=$(oracleasm listdisks | sort)
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

##  echo "ORACLE_HOME=$ORACLE_HOME"
##  echo "ORACLE_BASE=$ORACLE_BASE"
##  echo "ORACLE_SID=$ORACLE_SID"
##  echo "LD_LIBRARY_PATH=$LD_LIBRARY_PATH"
##  echo "PATH=$PATH"

asm_disks_info=$(su - "$asm_user" -c "export ORACLE_HOME=$ORACLE_HOME; export PATH=\$ORACLE_HOME/bin:\$PATH; asmcmd lsdsk -p" 2>/dev/null | sort -k1,1n -k2,2n)
if [ -z "$asm_disks_info" ]; then
    echo "Erro: Não foi possível obter informações dos discos ASM."
    exit 1
fi

printf "%-30s %8s %-40s %-40s %-10s %-10s %-10s\n" "ASM_DISK" "SIZE" "OS_DEVICE" "PATH_DISK" "GROUP_NUM" "DISK_NUM" "STATUS"
printf "%-30s %8s %-40s %-40s %-10s %-10s %-10s\n" "------------------------------" "--------" "----------------------------------------" "----------------------------------------" "----------" "----------" "----------"

for disco in $discos_asm; do
    info_dispositivo=$(oracleasm querydisk -d "$disco" | awk -F'[][]' '{print $2}')
    major=$(echo "$info_dispositivo" | awk -F',' '{print $1}')
    minor=$(echo "$info_dispositivo" | awk -F',' '{print $2}')
    
    dispositivo=$(lsblk -o MAJ:MIN,NAME --noheadings | grep "^ *$major:$minor" | awk '{print $2}' | head -n 1)

    if [ -z "$dispositivo" ]; then
        dispositivo="Desconhecido"
        tamanho="N/A"
    else
        dispositivo=$(echo "$dispositivo" | sed 's/└─//')

        if [[ "$dispositivo" =~ ^mpath ]]; then
            dispositivo_base="/dev/mapper/${dispositivo//p[0-9]/}"
        else
            dispositivo_base="/dev/${dispositivo//p[0-9]/}"
        fi

        tamanho=$(lsblk -no SIZE "$dispositivo_base" 2>/dev/null | head -n 1)

        if [ -z "$tamanho" ]; then
            tamanho="Erro"
        fi
    fi

    diskgroup=$(echo "$asm_disks_info" | grep -w "$disco" | awk '{print $NF}')
    
    if [ -n "$diskgroup" ]; then
        group_num=$(echo "$asm_disks_info" | grep -w "$disco" | awk '{print $1}')
        disk_num=$(echo "$asm_disks_info" | grep -w "$disco" | awk '{print $2}')
        state=$(echo "$asm_disks_info" | grep -w "$disco" | awk '{print $6}')
    else
        diskgroup="Nenhum"
        group_num="N/A"
        disk_num="N/A"
        state="DESCONHECIDO"
    fi

    printf "%-30s %8s %-40s %-40s %-10s %-10s %-10s\n" "$disco" "$tamanho" "$dispositivo_base" "$diskgroup" "$group_num" "$disk_num" "$state"
done

echo ". . ."
echo "========================================================================"
echo "===     O Guina Não Tinha Dó! Se Reagir, BUMMM... Vira Pó! 😎🔥      ==="
echo "========================================================================"
echo ". . ."
