#!/bin/bash
###############################################################################
# Script......: monitor_cpu.sh
# Finalidade..: Verifica uso de CPU por instância via logs do Snapper
# Autor.......: Roberto Sobrinho
# Data........: 2025-07-23
# Servidores..: exapim01-bin5no1, exapim01-bin5no2, exapim01-bin5no3
# Observações.:
#   - Requer relação de confiança SSH entre os hosts
#   - Alvo: arquivos snapper em /u02/app/oracle/ADMDBA/MONI/logs_snapper
#   - Filtra DBs pimpao1, pimpao2, pimpao3 conforme número final do hostname
#   - Exibe apenas se NB_CPU > valor informado pelo usuário
#   - Alinha cabeçalho dinamicamente
###############################################################################
 
echo
echo "================================================================================="
echo "Este script verifica o uso de CPU por instância baseado nos logs do Snapper."
echo "Se o seu servidor possui, por exemplo, 60 CPUs, você pode informar esse valor"
echo "para identificar momentos em que o uso de CPU ultrapassou esse limite."
echo "O filtro será feito com base no campo NB_CPU."
echo "================================================================================="
echo
cd /u02/app/oracle/ADMDBA/MONI/logs_snapper

read -p "Informe o valor mínimo de NB_CPU para filtrar (ex: 60): " cpu_limit

# Validação simples do input
if ! [[ "$cpu_limit" =~ ^[0-9]+$ ]]; then
  echo "Valor inválido. Informe apenas números inteiros."
  exit 1
fi

indent_spaces=97
indentation=$(printf "%*s" "$indent_spaces" "")


# Lista de servidores
for srv in exapim01-bin5no1 exapim01-bin5no2 exapim01-bin5no3; do
  echo "=== $srv ==="
  echo "${indentation}DB_NAME         CPU_SEC         NB_CPU       AVG_NB_CPU        MAX_NB_CPU        MIN_NB_CPU"

  # Extrai o número do final do hostname (ex: bin5no1 → 1)
  num=$(echo "$srv" | awk -F'-' '{print $3}' | sed 's/[^0-9]//g')
  db="pimpao$num"

ssh "$srv" bash <<EOF
export cpu_limit=$cpu_limit
export db=$db
for f in /u02/app/oracle/ADMDBA/MONI/logs_snapper/*.log; do
  perl -ne '
    if (\$ENV{"db"} && /\\Q\$ENV{"db"}\\E/ && !/oracle/) {
      @f = split;
      print "\$ARGV: \$_" if \$f[3] > \$ENV{"cpu_limit"};
    }
  ' "\$f"
done
EOF
  echo ""
done


###for mes in 06 07; do
###  if [ "$mes" = "06" ]; then
###    dias=$(seq -w 26 30)
###  else
###    dias=$(seq -w 1 25)
###  fi
###
###  for dia in $dias; do
###    data="2025${mes}${dia}"
###    echo -n "$data : "
###    sh rep_monitor_cpu2.sh | grep -i "$data" | wc -l
###  done
###done