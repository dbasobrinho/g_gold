#!/bin/bash
 
#########################################################################
# Script: exec_moedor_scripts_oracle.sh
#
# Descrição:
# Automatiza a execução de scripts SQL relacionados a mudanças em um 
# ambiente Oracle, de forma segura, controlada e padronizada. Utiliza uma 
# estrutura de diretórios baseada na data da janela de execução e aplica 
# os scripts definidos no arquivo `config.md`, com suporte a rollback 
# automático em caso de erro.
#
# Finalidade:
# - Controlar a execução de scripts de mudanças Oracle por janelas de tempo.
# - Registrar logs detalhados de execução, incluindo sucesso, falhas e rollback.
# - Padronizar o processo de entrega técnica de scripts em ambientes controlados.
#
# Funcionamento:
# 1. O script acessa o diretório da data atual (formato: YYYYMMDD).
# 2. Para cada mudança detectada com `STATUS.executar`:
#    - Lê os scripts definidos em `config.md`.
#    - Executa cada script sequencialmente via `sqlplus`.
#    - Em caso de falha, aplica rollback automaticamente (se configurado).
#    - Gera relatórios claros de sucesso ou erro, com o passo a passo.
#
# Estrutura esperada de diretórios:
#
# /share/ativaGESTAO/AUTO/
# └── YYYYMMDD/                # Diretório da data da janela (ex: 20250726)
#     └── <ID_MUDANCA>/        # Diretório identificador da mudança (ex: 2025100)
#         ├── STATUS.executar        # Indica que a mudança deve ser processada
#         ├── config.md              # Lista de scripts e parâmetros de rollback
#         ├── <script>.sql           # Scripts SQL referenciados no config.md
#         ├── <script_fallback>.sql  # (Opcional) Script de rollback
#         └── log.<data_hora>/       # Diretório com logs detalhados da execução
#
# Formato do arquivo config.md:
# Cada linha (ignorando comentários com #) deve conter:
#   <script>.sql : [S/N] : <rollback>.sql
#
# Onde:
# - <script>.sql     → nome do script principal
# - [S/N]            → indica se deve aplicar rollback em caso de erro (S = sim)
# - <rollback>.sql   → script de rollback correspondente (pode ser omitido se [N])
#
# Exemplo de config.md:
# --------------------------
#  Configuração do tempo limite
#  TIMEOUT_MIN=2
#  
#  # Lista de scripts
#  1script.sql : [S] : 1script_fallback.sql
#  2script.sql : [N] :
#  3script.sql : [S] : 3script_fallback.sql
# --------------------------
#
# Geração de arquivos:
# - STATUS.sucesso   → Criado se todos os scripts forem executados com sucesso.
# - STATUS.erro      → Criado se algum script falhar, com ou sem rollback.
# - STATUS.debug     → Criado temporariamente com o passo a passo da execução.
# - _log_<script>.log → Logs individuais de cada script executado.
#
# Observação:
# O script ignora diretórios que não contêm o arquivo `STATUS.executar`.
# Ao final da execução, o STATUS.debug é renomeado para STATUS.sucesso ou STATUS.erro.
#
# Versão: 1.0
# Autor: DBA Sobrinho
# Data: 26/07/2025
#########################################################################

# =========================
# BLOCO 1 - CONFIGURAÇÃO
# =========================
DIRETORIO_BASE=/media/sf_tmp/AUTO
DATA_HOJE=$(date +%Y%m%d)
HORA_AGORA=$(date +%H%M)
DATA_HOJE_F=$(date +%d/%m/%Y)
HORA_AGORA_F=$(date +%H:%M)
DIRETORIO_DIA="$DIRETORIO_BASE/$DATA_HOJE"
ORACLE_SID=$(ps -ef | grep pmon | grep -v grep | grep shback | awk -F_ '{print $3}')
ORACLE_HOME=/opt/oracle/product/21c/dbhome_1
PATH=$ORACLE_HOME/bin:$PATH
DATA_HORA_ATUAL=$(date "+%Y-%m-%d %H:%M")
HOUVE_ERRO=99

# =========================
# BLOCO 2 - CHECA DIRETÓRIO DO DIA
# =========================
if [ ! -d "$DIRETORIO_DIA" ]; then
    echo "Diretório do dia não encontrado, criando: $DIRETORIO_DIA"
    mkdir -p "$DIRETORIO_DIA"
    echo "Nenhuma mudança marcada para execução nesta janela em $DATA_HOJE_FORMATADA às $HORA_AGORA_FORMATADA."
    exit 0
fi

echo -e "\n======================================================================================"
echo "Iniciando execução da janela em $DATA_HOJE_F às $HORA_AGORA_F"
echo -e "======================================================================================\n"


MUDANCA_ENCONTRADA=0
# =========================
# BLOCO 3 - PROCESSA CADA MUDANÇA
# =========================
for DIRETORIO_MUDANCA in "$DIRETORIO_DIA"/*; do
    [ -d "$DIRETORIO_MUDANCA" ] || continue
    DATA_HORA_ATUAL_NOME=$(date "+%d-%b-%Y_%H-%M-%S" | tr '[:upper:]' '[:lower:]')
    LOG_DIR="$DIRETORIO_MUDANCA/log.$DATA_HORA_ATUAL_NOME"
    mkdir -p "$LOG_DIR"
    ARQUIVO_STATUS="$DIRETORIO_MUDANCA/STATUS.executar"
    ARQUIVO_CONFIG="$DIRETORIO_MUDANCA/config.md"
    NOME_MUDANCA=$(basename "$DIRETORIO_MUDANCA")

    # =========================
    # BLOCO 4 - VERIFICA STATUS E CONFIG.MD
    # =========================
    if [ ! -f "$ARQUIVO_STATUS" ]; then
        continue
    fi

    MUDANCA_ENCONTRADA=1
    echo "--------------------------------------------------------------------------------------"
    echo "[$(date '+%d/%m/%Y %H:%M:%S')] >> Mudança: $NOME_MUDANCA >> Início da execução"

    if [ ! -f "$ARQUIVO_CONFIG" ]; then
        echo "ERRO NA EXECUÇÃO EM: $DATA_HORA_ATUAL - Arquivo config.md não encontrado" > "$DIRETORIO_MUDANCA/STATUS.erro"
        cp "$DIRETORIO_MUDANCA/STATUS.erro" "$LOG_DIR"
        cp "$DIRETORIO_MUDANCA/STATUS.erro" "$DIRETORIO_DIA/$NOME_MUDANCA.erro"
        rm -f "$ARQUIVO_STATUS"
        continue
    fi

	# =========================
	# BLOCO 4.1 - VALIDA EXISTÊNCIA DOS ARQUIVOS LISTADOS NO CONFIG.MD
	# =========================
	ERRO_ARQUIVO_INEXISTENTE=0
	TEMP_CONFIG_VALIDA=$(mktemp)
	grep -v '^#' "$ARQUIVO_CONFIG" | grep ':' > "$TEMP_CONFIG_VALIDA"

	while IFS=: read -r SCRIPT APLICAR_ROLLBACK ROLLBACK; do
		SCRIPT=$(echo "$SCRIPT" | xargs)
		APLICAR_ROLLBACK=$(echo "$APLICAR_ROLLBACK" | tr -d '[]' | xargs)
		ROLLBACK=$(echo "$ROLLBACK" | xargs)

		CAMINHO_SCRIPT="$DIRETORIO_MUDANCA/$SCRIPT"
		CAMINHO_ROLLBACK="$DIRETORIO_MUDANCA/$ROLLBACK"

		if [ ! -f "$CAMINHO_SCRIPT" ]; then
			echo "ERRO: Arquivo de execução não encontrado: $CAMINHO_SCRIPT" > "$DIRETORIO_MUDANCA/STATUS.erro"
			cp "$DIRETORIO_MUDANCA/STATUS.erro" "$LOG_DIR"
			cp "$DIRETORIO_MUDANCA/STATUS.erro" "$DIRETORIO_DIA/$NOME_MUDANCA.erro"
			ERRO_ARQUIVO_INEXISTENTE=1
			break
		fi

		if [ "$APLICAR_ROLLBACK" == "S" ] && [ -n "$ROLLBACK" ] && [ ! -f "$CAMINHO_ROLLBACK" ]; then
			echo "ERRO: Arquivo de rollback não encontrado: $CAMINHO_ROLLBACK" > "$DIRETORIO_MUDANCA/STATUS.erro"
			cp "$DIRETORIO_MUDANCA/STATUS.erro" "$LOG_DIR"
			cp "$DIRETORIO_MUDANCA/STATUS.erro" "$DIRETORIO_DIA/$NOME_MUDANCA.erro"
			ERRO_ARQUIVO_INEXISTENTE=1
			break
		fi
	done < "$TEMP_CONFIG_VALIDA"
	rm -f "$TEMP_CONFIG_VALIDA"

	if [ $ERRO_ARQUIVO_INEXISTENTE -eq 1 ]; then
		rm -f "$ARQUIVO_STATUS"
		continue
	fi


    # =========================
    # BLOCO 5 - EXECUTA CADA SCRIPT DO CONFIG
    # =========================
    TEMPO_LIMITE=$(grep TIMEOUT_MIN "$ARQUIVO_CONFIG" | cut -d'=' -f2 | tr -d '\r')
    HOUVE_ERRO=0
    STATUS_DEBUG="$DIRETORIO_MUDANCA/STATUS.executar"
    > "$STATUS_DEBUG"

    TEMP_CONFIG=$(mktemp)
    grep -v '^#' "$ARQUIVO_CONFIG" | grep ':' > "$TEMP_CONFIG"

    while IFS=: read -r SCRIPT APLICAR_ROLLBACK ROLLBACK; do
        SCRIPT=$(echo "$SCRIPT" | xargs)
        APLICAR_ROLLBACK=$(echo "$APLICAR_ROLLBACK" | tr -d '[]' | xargs)
        ROLLBACK=$(echo "$ROLLBACK" | xargs)

        CAMINHO_SCRIPT="$DIRETORIO_MUDANCA/$SCRIPT"
        CAMINHO_ROLLBACK="$DIRETORIO_MUDANCA/$ROLLBACK"
        ARQUIVO_LOG="$LOG_DIR/_log_${SCRIPT%.sql}.log"

        echo "Executando script: $SCRIPT" >> "$STATUS_DEBUG"

        if [ ! -f "$CAMINHO_SCRIPT" ]; then
            echo "$SCRIPT > erro: arquivo não encontrado" >> "$STATUS_DEBUG"
            HOUVE_ERRO=1
            break
        fi

         timeout "${TEMPO_LIMITE}m" sqlplus sys/oracle@pdb1 as sysdba <<EOF > "$ARQUIVO_LOG"
whenever sqlerror exit sql.sqlcode
spool $ARQUIVO_LOG
exec dbms_application_info.set_module( module_name => 'A#M#S1 MoedorScripts', action_name => 'A#M#S1 MoedorScripts');
@$CAMINHO_SCRIPT
spool off
exit
EOF

        STATUS=$?
        if [ $STATUS -eq 124 ]; then
            echo "$SCRIPT > erro (timeout)" >> "$STATUS_DEBUG"
            HOUVE_ERRO=1
        elif [ $STATUS -ne 0 ]; then
            echo "$SCRIPT > erro na execução" >> "$STATUS_DEBUG"
            HOUVE_ERRO=1
        else
            echo "$SCRIPT > sucesso na execução" >> "$STATUS_DEBUG"
        fi

        if [ $HOUVE_ERRO -eq 1 ]; then
            if [ "$APLICAR_ROLLBACK" == "S" ] && [ -n "$ROLLBACK" ] && [ -f "$CAMINHO_ROLLBACK" ]; then
                echo "Executando rollback: $ROLLBACK" >> "$STATUS_DEBUG"
                ROLLBACK_LOG="$LOG_DIR/_log_fallback_${SCRIPT%.sql}.log"

         timeout "${TEMPO_LIMITE}m" sqlplus sys/oracle@pdb1 as sysdba <<EOF > "$ROLLBACK_LOG"
whenever sqlerror exit sql.sqlcode
spool $ROLLBACK_LOG
exec dbms_application_info.set_module( module_name => 'A#M#S2 MoedorScripts', action_name => 'A#M#S2 MoedorScripts');
@$CAMINHO_ROLLBACK
spool off
exit
EOF

                echo "$ROLLBACK > Rollback do script anterior, Sucesso na execução" >> "$STATUS_DEBUG"
            fi
            break
        fi
    done < "$TEMP_CONFIG"
    rm -f "$TEMP_CONFIG"

    # =========================
    # BLOCO 6 - RENOMEIA STATUS FINAL
    # =========================
    if [ $HOUVE_ERRO -eq 1 ]; then
        mv "$STATUS_DEBUG" "$DIRETORIO_MUDANCA/STATUS.erro"
        cp "$DIRETORIO_MUDANCA/STATUS.erro" "$LOG_DIR"
        cp "$DIRETORIO_MUDANCA/STATUS.erro" "$DIRETORIO_DIA/$NOME_MUDANCA.erro"
		echo "[$(date '+%d/%m/%Y %H:%M:%S')] >> Mudança: $NOME_MUDANCA >> Erro na execução. Consulte o log."
		echo "--------------------------------------------------------------------------------------"
    else
        echo "MUDANÇA EXECUTADA COM SUCESSO EM: $DATA_HORA_ATUAL" > "$DIRETORIO_MUDANCA/STATUS.sucesso"
        cat "$STATUS_DEBUG" >> "$DIRETORIO_MUDANCA/STATUS.sucesso"
        cp "$DIRETORIO_MUDANCA/STATUS.sucesso" "$LOG_DIR"
        cp "$DIRETORIO_MUDANCA/STATUS.sucesso" "$DIRETORIO_DIA/$NOME_MUDANCA.sucesso"
		echo "[$(date '+%d/%m/%Y %H:%M:%S')] >> Mudança: $NOME_MUDANCA >> Sucesso na Execução. #TOPIN"
		echo "--------------------------------------------------------------------------------------"
        rm -f "$STATUS_DEBUG"
    fi
done

# =========================
# BLOCO 7 - FINALIZAÇÃO
# =========================
if [ $MUDANCA_ENCONTRADA -eq 0 ]; then
    echo "Nenhuma mudança marcada para execução nesta janela DIA=$DATA_HOJE HORA=$HORA_AGORA."
fi

DATA_HOJE_F=$(date +%d/%m/%Y)
HORA_AGORA_F=$(date +%H:%M)
echo -e "\n======================================================================================"
echo "Execução da janela DIA=$DATA_HOJE_F HORA=$HORA_AGORA_F concluída."
echo -e "======================================================================================\n"


