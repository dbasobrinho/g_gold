-- |----------------------------------------------------------------------------|
-- | Objetivo   : Monitorar as MViews do backoffice: ambiente, MViews          |
-- |              atrasadas, ultimo refresh, checkpoint da MVIEW_REFRESH_LOG,   |
-- |              fila da MLOG no autorizador e progresso do refresh em curso   |
-- | Criador    : Roberto Fernandes Sobrinho                                    |
-- | Data       : 24/09/2026                                                    |
-- | Exemplo    : @mview.sql                                                    |
-- | Arquivo    : mview.sql                                                     |
-- | Referncia  : scripts/mv_gaps.sql (logica dos episodios da secao 7)         |
-- | Modificacao: 1.0 - 11/04/2026 - rfsobrinho - versao original (mview.sql)   |
-- |              2.0 - 24/09/2026 - rfsobrinho - saida formatada, sem quebra   |
-- |                    de linha, colunas limitadas, progresso sempre retorna   |
-- |                    1 linha, estimativa corrigida                           |
-- |              3.0 - 24/09/2026 - rfsobrinho - secao 7: episodios CRITICO e  |
-- |                    MEDIO dos ultimos 7 dias + legenda; SPOOL em .out;      |
-- |                    secao 6a com GV$SESSION (RAC: mostra em qual no o       |
-- |                    refresh esta rodando)                                   |
-- +----------------------------------------------------------------------------+ 
-- |                                                https://dbasobrinho.com.br  |
-- +----------------------------------------------------------------------------+
-- | Executar em: PBACK_SP, sqlplus como SYS (usa x$knstmvr).                   |
-- | RAC: x$knstmvr e LOCAL da instancia e nao existe versao GV$. A secao 6a    |
-- | usa GV$SESSION e mostra em qual no o refresh roda; o progresso (secao 5    |
-- | e 6b) so aparece conectado nesse no (hoje o grupo02.sh roda no no 1).      |
-- +----------------------------------------------------------------------------+
-- | Refresh atrasado e painel zerado: olhe a fila antes de olhar o grafico.    |
-- +----------------------------------------------------------------------------+
SET ECHO OFF
SET VERIFY OFF
SET FEEDBACK OFF
SET TIMING OFF
SET TIME ON
SET LINESIZE 220
SET PAGESIZE 1000
SET TRIMOUT ON
SET WRAP OFF
SET TRIMSPOOL ON
SET TAB OFF
SET COLSEP ' | '
SET HEADSEP '|'
SET NULL '-'
SET LONG 80
DEFINE ep_mv        = 'AU_OPEN_TRANSACTION'
DEFINE ep_dias      = 7
DEFINE ep_lim_s     = 60
DEFINE ep_junta_min = 5
DEFINE ep_classes   = "'CRITICO','MEDIO'"
SET SQLPROMPT "_USER'@'_CONNECT_IDENTIFIER _PRIVILEGE> "
ALTER SESSION SET NLS_DATE_FORMAT = 'DD/MM/YYYY HH24:MI:SS';

-- ============================================================================
-- Formatos de coluna (todos com largura fixa para nao quebrar a linha)
-- ============================================================================
COL inst_id            FORMAT 99            HEAD 'INST|ID'
COL instance_name      FORMAT a12           HEAD 'INSTANCE|-'
COL host_name          FORMAT a20           HEAD 'HOST|-'
COL version            FORMAT a10           HEAD 'VERSAO|-'
COL db_name            FORMAT a10           HEAD 'DATABASE|-'
COL startup_time       FORMAT a19           HEAD 'STARTUP|-'
COL status             FORMAT a8            HEAD 'STATUS|-'
COL open_mode          FORMAT a10           HEAD 'OPEN|MODE'
COL database_role      FORMAT a16           HEAD 'ROLE|-'
COL logins             FORMAT a8            HEAD 'LOGINS|-'
COL agora              FORMAT a19           HEAD 'SYSDATE|-'

COL owner              FORMAT a12           HEAD 'OWNER|-'
COL mview_name         FORMAT a32           HEAD 'MVIEW|-'
COL refresh_method     FORMAT a8            HEAD 'METODO|-'
COL refresh_mode       FORMAT a7            HEAD 'MODO|-'
COL last_refresh_type  FORMAT a8            HEAD 'ULTIMO|TIPO'
COL last_refresh_date  FORMAT a19           HEAD 'ULTIMO|REFRESH'
COL atraso             FORMAT a15           HEAD 'ATRASO|(d) HH:MI:SS'
COL staleness          FORMAT a14           HEAD 'STALENESS|-'
COL compile_state      FORMAT a17           HEAD 'COMPILE|-'
COL master_link        FORMAT a14           HEAD 'DBLINK|-'

COL rlog_status        FORMAT a8            HEAD 'STATUS|-'
COL ult_checkpoint     FORMAT a19           HEAD 'ULTIMO|CHECKPOINT'
COL qtd_hoje           FORMAT 999,999       HEAD 'QTD|HOJE'

COL dmltype            FORMAT a10           HEAD 'DML|-'
COL registros_mlog     FORMAT 999,999,999   HEAD 'REGISTROS|MLOG'

COL dt_inicio          FORMAT a19           HEAD 'INICIO LOTE|-'
COL dt_atual           FORMAT a19           HEAD 'AGORA|-'
COL tempo              FORMAT a10           HEAD 'TEMPO|HH:MI:SS'
COL registros_pend     FORMAT 999,999,999   HEAD 'PENDENTE|MLOG'
COL feito              FORMAT 999,999,999   HEAD 'FEITO|-'
COL pct                FORMAT 990.00        HEAD '%|-'
COL estimativa         FORMAT a19           HEAD 'ESTIMATIVA|FIM'

COL sid                FORMAT 99999         HEAD 'SID|-'
COL materialized_view  FORMAT a45           HEAD 'MATERIALIZED VIEW|-'
COL refresh_type       FORMAT a10           HEAD 'TIPO|-'
COL fase               FORMAT a28           HEAD 'FASE|-'
COL inserts            FORMAT 999,999,999   HEAD 'INSERTS|-'
COL updates            FORMAT 999,999,999   HEAD 'UPDATES|-'
COL deletes            FORMAT 999,999,999   HEAD 'DELETES|-'

SET TERMOUT OFF;
EXEC dbms_application_info.set_module( module_name => 'mview[mview.sql]', action_name =>  'mview[mview.sql]');
COLUMN current_instance NEW_VALUE current_instance NOPRINT;
COLUMN inst_nome        NEW_VALUE inst_nome        NOPRINT;
COLUMN dt_spool         NEW_VALUE dt_spool         NOPRINT;
SELECT rpad(sys_context('USERENV', 'INSTANCE_NAME'), 17) current_instance,
       sys_context('USERENV', 'INSTANCE_NAME')           inst_nome,
       TO_CHAR(SYSDATE, 'YYYYMMDD_HH24MISS')              dt_spool
  FROM dual;
SET TERMOUT ON;
SPOOL mview_&inst_nome._&dt_spool..out
PROMPT
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | https://github.com/dbasobrinho/g_gold/blob/main/mview.sql                                 |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | Script   : Monitora MViews                                       +-+-+-+-+-+-+-+-+-+-+-+  |
PROMPT | Instancia: &current_instance                                     |d|b|a|s|o|b|r|i|n|h|o|  |
PROMPT | Versao   : 3.0                                                   +-+-+-+-+-+-+-+-+-+-+-+  |
PROMPT +-------------------------------------------------------------------------------------------+

PROMPT
PROMPT +------------------------------------------------------------------------+
PROMPT | 1. AMBIENTE                                                            |
PROMPT +------------------------------------------------------------------------+
SELECT a.inst_id,
       a.instance_name,
       a.host_name,
       a.version,
       b.name                                   db_name,
       TO_CHAR(a.startup_time)                  startup_time,
       a.status,
       b.open_mode,
       b.database_role,
       a.logins,
       TO_CHAR(SYSDATE)                         agora
  FROM gv$instance a
  JOIN gv$database b ON b.inst_id = a.inst_id
 ORDER BY a.inst_id;

PROMPT
PROMPT +------------------------------------------------------------------------+
PROMPT | 2. MVIEW COM PROBLEMA                                                  |
PROMPT |    FAST  sem refresh ha mais de 7,2 min (2/400 dia)                    |
PROMPT |    FORCE sem refresh ha mais de 2 h  (so avalia apos 04:00)            |
PROMPT +------------------------------------------------------------------------+
SELECT m.owner,
       m.mview_name,
       m.refresh_method,
       m.refresh_mode,
       m.last_refresh_type,
       TO_CHAR(m.last_refresh_date)                                   last_refresh_date,
       LPAD(CASE WHEN SYSDATE - m.last_refresh_date >= 1
                 THEN TRUNC(SYSDATE - m.last_refresh_date) || 'd '
            END
            || TO_CHAR(TRUNC(SYSDATE) + (SYSDATE - m.last_refresh_date),
                       'HH24:MI:SS'), 15)                            atraso,
       m.staleness,
       m.compile_state,
       SUBSTR(m.master_link, 2, 14)                                   master_link
  FROM dba_mviews m
 WHERE m.owner NOT IN ('SYS','SYSMAN','SYSTEM','DBSNMP')
   AND m.mview_name NOT IN ('MVIEW_C01VW1535',
                            'MVIEW_FL_DRIVER_VEHICLE_GROUP',
                            'AU_OPEN_TRANSACTION_TED',
                            'AD_CALL_ORIGIN_WEBSERVICE_MV')
   AND (   (m.refresh_method = 'FAST'  AND m.last_refresh_date <= SYSDATE - 2/400)
        OR (m.refresh_method = 'FORCE' AND m.last_refresh_date <= SYSDATE - 2/24))
   AND SYSDATE >= TRUNC(SYSDATE) + 4/24
 ORDER BY m.last_refresh_date;

PROMPT
PROMPT +------------------------------------------------------------------------+
PROMPT | 3. LAST REFRESH MVIEWS (mais antiga primeiro)                          |
PROMPT +------------------------------------------------------------------------+
SELECT m.owner,
       m.mview_name,
       m.refresh_method,
       m.last_refresh_type,
       TO_CHAR(m.last_refresh_date)                                   last_refresh_date,
       LPAD(CASE WHEN SYSDATE - m.last_refresh_date >= 1
                 THEN TRUNC(SYSDATE - m.last_refresh_date) || 'd '
            END
            || TO_CHAR(TRUNC(SYSDATE) + (SYSDATE - m.last_refresh_date),
                       'HH24:MI:SS'), 15)                            atraso,
       m.staleness
  FROM dba_mviews m
 ORDER BY m.last_refresh_date NULLS FIRST;

PROMPT
PROMPT +------------------------------------------------------------------------+
PROMPT | 4. MAX CHECKPOINT MVIEW_REFRESH_LOG (hoje)                             |
PROMPT |    INICIO mais recente que FIM = lote em andamento                     |
PROMPT +------------------------------------------------------------------------+
SELECT l.status                                                       rlog_status,
       TO_CHAR(MAX(l.data_checkpoint))                                ult_checkpoint,
       TO_CHAR(TRUNC(SYSDATE) + (SYSDATE - MAX(l.data_checkpoint)),
               'HH24:MI:SS')                                          atraso,
       COUNT(*)                                                       qtd_hoje
  FROM sys.mview_refresh_log l
 WHERE l.data_checkpoint > TRUNC(SYSDATE)
 GROUP BY l.status
 ORDER BY MAX(l.data_checkpoint);

PROMPT
PROMPT +------------------------------------------------------------------------+
PROMPT | 5. MONITORA PROGRESSO MVIEW FAST                                       |
PROMPT |    Fila: SYSAU.MLOG$_AU_OPEN_TRANSACTION@AUTORIZADOR                   |
PROMPT +------------------------------------------------------------------------+
SELECT NVL(DECODE(dmltype$$, 'I', 'I-INSERT',
                             'U', 'U-UPDATE',
                             'D', 'D-DELETE', dmltype$$),
           'TOTAL')                                                   dmltype,
       COUNT(*)                                                       registros_mlog
  FROM sysau.mlog$_au_open_transaction@autorizador
 GROUP BY ROLLUP(dmltype$$)
 ORDER BY GROUPING(dmltype$$), dmltype$$;

PROMPT
PROMPT Progresso do lote atual (FEITO = I+U+D da sessao de refresh NESTE no, ver 6a)
WITH ini AS (SELECT MAX(data_checkpoint) inicio
               FROM sys.mview_refresh_log
              WHERE data_checkpoint > TRUNC(SYSDATE)
                AND status = 'INICIO'),
     pend AS (SELECT COUNT(*) registros
                FROM sysau.mlog$_au_open_transaction@autorizador),
     feito AS (SELECT SUM(x.total_inserts_knstmvr
                        + x.total_updates_knstmvr
                        + x.total_deletes_knstmvr) feito
                 FROM x$knstmvr x
                WHERE x.type_knst = 6
                  AND x.currmvname_knstmvr LIKE '%AU_OPEN_TRANSACTION%'
                  AND EXISTS (SELECT 1
                                FROM v$session s
                               WHERE s.sid     = x.sid_knst
                                 AND s.serial# = x.serial_knst))
SELECT TO_CHAR(i.inicio)                                              dt_inicio,
       TO_CHAR(SYSDATE)                                               dt_atual,
       TO_CHAR(TRUNC(SYSDATE) + (SYSDATE - i.inicio), 'HH24:MI:SS')   tempo,
       NVL(p.registros, 0)                                            registros_pend,
       NVL(f.feito, 0)                                                feito,
       ROUND(NVL(f.feito, 0) / NULLIF(p.registros, 0) * 100, 2)       pct,
       TO_CHAR(SYSDATE + (p.registros - f.feito)
                       * (SYSDATE - i.inicio)
                       / NULLIF(f.feito, 0))                          estimativa
  FROM ini i CROSS JOIN pend p CROSS JOIN feito f;

PROMPT
PROMPT +------------------------------------------------------------------------+
PROMPT | 6a. SESSOES DE REFRESH NO CLUSTER (GV$SESSION, todos os nos)           |
PROMPT |     Se INST_ID for diferente da instancia atual, conecte nesse no      |
PROMPT |     para ver o progresso das secoes 5 e 6b.                            |
PROMPT +------------------------------------------------------------------------+
COL rs_inst    FORMAT 99        HEAD 'INST|ID'
COL rs_local   FORMAT a5        HEAD 'ESTE|NO'
COL rs_sid     FORMAT 99999     HEAD 'SID|-'
COL rs_serial  FORMAT 99999     HEAD 'SERIAL|-'
COL rs_module  FORMAT a12       HEAD 'MODULE|-'
COL rs_status  FORMAT a8        HEAD 'STATUS|-'
COL rs_sqlid   FORMAT a13       HEAD 'SQL_ID|-'
COL rs_event   FORMAT a40       HEAD 'EVENTO|-'
COL rs_wait    FORMAT 999990    HEAD 'WAIT|(s)'
COL rs_call    FORMAT 9999990   HEAD 'LAST CALL|(s)'
SELECT s.inst_id                                                      rs_inst,
       CASE WHEN s.inst_id = SYS_CONTEXT('USERENV', 'INSTANCE')
            THEN 'SIM' ELSE 'NAO' END                                 rs_local,
       s.sid                                                          rs_sid,
       s.serial#                                                      rs_serial,
       SUBSTR(s.module, 1, 12)                                        rs_module,
       s.status                                                       rs_status,
       s.sql_id                                                       rs_sqlid,
       SUBSTR(s.event, 1, 40)                                         rs_event,
       s.seconds_in_wait                                              rs_wait,
       s.last_call_et                                                 rs_call
  FROM gv$session s
 WHERE s.module LIKE 'MVG%'
    OR (    s.inst_id = SYS_CONTEXT('USERENV', 'INSTANCE')
        AND s.sid IN (SELECT x.sid_knst FROM x$knstmvr x WHERE x.type_knst = 6))
 ORDER BY s.inst_id, s.sid;

PROMPT
PROMPT +------------------------------------------------------------------------+
PROMPT | 6b. MONITORA PROGRESSO MVIEWS (refresh em execucao NESTE no)           |
PROMPT +------------------------------------------------------------------------+
SELECT x.sid_knst                                                     sid,
       x.currmvowner_knstmvr || '.' || x.currmvname_knstmvr           materialized_view,
       DECODE(x.reftype_knstmvr, 1, 'FAST',
                                 2, 'COMPLETE',
                                    'UNKNOWN')                        refresh_type,
       DECODE(x.groupstate_knstmvr, 1, 'SETUP - Iniciando',
                                    2, 'INSTANTIATE - Carregando',
                                    3, 'WRAPUP - Finalizando',
                                       'UNKNOWN')                     fase,
       x.total_inserts_knstmvr                                        inserts,
       x.total_updates_knstmvr                                        updates,
       x.total_deletes_knstmvr                                        deletes
  FROM x$knstmvr x
 WHERE x.type_knst = 6
   AND EXISTS (SELECT 1
                 FROM v$session s
                WHERE s.sid     = x.sid_knst
                  AND s.serial# = x.serial_knst)
 ORDER BY materialized_view;

PROMPT
PROMPT +------------------------------------------------------------------------+
PROMPT | 7. EPISODIOS DE ATRASO DO REFRESH (janela = ep_dias, padrao 7 dias)    |
PROMPT |    MView: AU_OPEN_TRANSACTION (ep_mv)  Classes: CRITICO e MEDIO        |
PROMPT +------------------------------------------------------------------------+
PROMPT +------------------------------------------------------------------------+
PROMPT | Como ler as colunas de parada e lote                                   |
PROMPT +------------------------------------------------------------------------+
PROMPT | PARADAS SEM LOTE : quantas vezes o refresh parou: terminou um lote e o |
PROMPT |                    proximo demorou mais de 60 s para comecar           |
PROMPT |                    Ex.: 1 no reinicio do cron, 00:02                   |
PROMPT | MAIOR PARADA     : quanto tempo durou a parada mais longa              |
PROMPT |                    Ex.: 124s (2min) = 2 min sem refresh nenhum         |
PROMPT | MAIOR LOTE       : quanto tempo levou o lote mais lento, com o refresh |
PROMPT |                    rodando                                             |
PROMPT |                    Ex.: 1648s (27min) = um lote de 27 min              |
PROMPT | OBS              : LOOP CRON = episodio que comeca no reinicio      |
PROMPT |                    diario do grupo02.sh pelo cron (23:55 a 00:03)      |
PROMPT +------------------------------------------------------------------------+
PROMPT
COL ep_seq     FORMAT 999        HEAD 'SEQ|-'
COL ep_inicio  FORMAT a23        HEAD 'INICIO|-'
COL ep_fim     FORMAT a23        HEAD 'FIM|-'
COL ep_dur     FORMAT 99990.0    HEAD 'ATRASO|PAINEL'
COL ep_periodo FORMAT a9         HEAD 'PERIODO|-'
COL ep_lote    FORMAT 9999       HEAD 'LOTES|LENTOS'
COL ep_gap     FORMAT 9999       HEAD 'PARADAS|SEM LOTE'
COL ep_orfao   FORMAT 9999       HEAD 'ORFAOS|-'
COL ep_maxlote FORMAT a14        HEAD 'MAIOR|LOTE'   JUSTIFY RIGHT
COL ep_maxgap  FORMAT a14        HEAD 'MAIOR|PARADA' JUSTIFY RIGHT
COL ep_classe  FORMAT a8         HEAD 'CLASSE|-'
COL ep_obs     FORMAT a10        HEAD 'OBS|-'
WITH b AS (
  SELECT status,
         data_checkpoint                                                      dt,
         LEAD(status)          OVER (ORDER BY data_checkpoint,
                                     DECODE(status, 'INICIO', 1, 2))          nx_status,
         LEAD(data_checkpoint) OVER (ORDER BY data_checkpoint,
                                     DECODE(status, 'INICIO', 1, 2))          nx_dt
    FROM sys.mview_refresh_log
   WHERE materialized_view = '&ep_mv'
     AND data_checkpoint  >= TRUNC(SYSDATE) - &ep_dias
), ev AS (
  SELECT dt                                                                   ini,
         nx_dt                                                                fim,
         (nx_dt - dt) * 86400                                                 secs,
         CASE WHEN status = 'INICIO' AND nx_status = 'FIM'    THEN 'LOTE'
              WHEN status = 'INICIO' AND nx_status = 'INICIO' THEN 'ORFAO'
              WHEN status = 'FIM'    AND nx_status = 'INICIO' THEN 'GAP'
         END                                                                  tipo
    FROM b
   WHERE nx_dt IS NOT NULL
     AND (   (status = 'INICIO' AND nx_status = 'INICIO')
          OR ((nx_dt - dt) * 86400 > &ep_lim_s AND status <> nx_status))
), ep AS (
  SELECT ev.*,
         CASE WHEN LAG(fim) OVER (ORDER BY ini) IS NULL
                OR ini > LAG(fim) OVER (ORDER BY ini) + &ep_junta_min / 1440
              THEN 1 ELSE 0
         END                                                                  novo
    FROM ev
), g AS (
  SELECT ep.*,
         SUM(novo) OVER (ORDER BY ini ROWS UNBOUNDED PRECEDING)               grp
    FROM ep
), e AS (
  SELECT MIN(ini)                                                             ini,
         MAX(fim)                                                             fim,
         (MAX(fim) - MIN(ini)) * 1440                                         dmin,
         SUM(CASE WHEN tipo = 'LOTE'  THEN 1 ELSE 0 END)                      qtd_lote,
         SUM(CASE WHEN tipo = 'GAP'   THEN 1 ELSE 0 END)                      qtd_gap,
         SUM(CASE WHEN tipo = 'ORFAO' THEN 1 ELSE 0 END)                      qtd_orfao,
         MAX(CASE WHEN tipo IN ('LOTE', 'ORFAO') THEN secs END)               max_lote,
         MAX(CASE WHEN tipo = 'GAP' THEN secs END)                            max_gap
    FROM g
   GROUP BY grp
), c AS (
  SELECT e.*,
         CASE WHEN dmin >= 15 OR qtd_orfao > 0 THEN 'CRITICO'
              WHEN dmin >= 5                   THEN 'ALTO'
              ELSE 'MEDIO'
         END                                                                  classe,
         CASE WHEN TO_CHAR(ini, 'HH24MI') >= '2355'
                OR TO_CHAR(ini, 'HH24MI') <= '0003'
              THEN 'LOOP CRON'
         END                                                                  obs
    FROM e
)
SELECT ROW_NUMBER() OVER (ORDER BY ini)                                       ep_seq,
       DECODE(TO_CHAR(ini, 'DY', 'NLS_DATE_LANGUAGE=AMERICAN'),
              'SUN', 'DOM', 'MON', 'SEG', 'TUE', 'TER', 'WED', 'QUA',
              'THU', 'QUI', 'FRI', 'SEX', 'SAT', 'SAB')
       || ' ' || TO_CHAR(ini, 'DD/MM/YYYY HH24:MI:SS')                  ep_inicio,
       DECODE(TO_CHAR(fim, 'DY', 'NLS_DATE_LANGUAGE=AMERICAN'),
              'SUN', 'DOM', 'MON', 'SEG', 'TUE', 'TER', 'WED', 'QUA',
              'THU', 'QUI', 'FRI', 'SEX', 'SAT', 'SAB')
       || ' ' || TO_CHAR(fim, 'DD/MM/YYYY HH24:MI:SS')                  ep_fim,
       ROUND(dmin, 1)                                                         ep_dur,
       CASE WHEN TO_NUMBER(TO_CHAR(ini, 'HH24')) IN (23, 0, 1, 2, 3, 4, 5)
            THEN 'MADRUGADA' ELSE 'DIURNO'
       END                                                                    ep_periodo,
       qtd_lote                                                               ep_lote,
       qtd_gap                                                                ep_gap,
       qtd_orfao                                                              ep_orfao,
       LPAD(CASE WHEN NVL(ROUND(max_lote), 0) = 0 THEN '0'
                 WHEN ROUND(max_lote) < 60 THEN ROUND(max_lote) || 's'
                 ELSE ROUND(max_lote) || 's (' || ROUND(max_lote / 60) || 'min)'
            END, 14)                                                          ep_maxlote,
       LPAD(CASE WHEN NVL(ROUND(max_gap), 0) = 0 THEN '0'
                 WHEN ROUND(max_gap) < 60 THEN ROUND(max_gap) || 's'
                 ELSE ROUND(max_gap) || 's (' || ROUND(max_gap / 60) || 'min)'
            END, 14)                                                          ep_maxgap,
       classe                                                                 ep_classe,
       NVL(obs, ' ')                                                          ep_obs
  FROM c
 WHERE classe IN (&ep_classes)
 ORDER BY ini;

PROMPT
PROMPT +------------------------------------------------------------------------+
PROMPT | Legenda da secao 7                                                     |
PROMPT +------------------------------------------------------------------------+
PROMPT | SEQ        : numero do episodio na janela (mais antigo primeiro)       |
PROMPT | INICIO/FIM : dia da semana + primeiro e ultimo registro do episodio na |
PROMPT |              MVIEW_REFRESH_LOG (periodo em que o painel ficou parado   |
PROMPT |              ou com dado atrasado)                                     |
PROMPT | ATRASO PAINEL: tempo em que o painel ficou com dado atrasado (FIM     |
PROMPT |              menos INICIO), em minutos                                 |
PROMPT | PERIODO    : MADRUGADA se comecou entre 23h e 05h59, senao DIURNO      |
PROMPT | LOTES LENT.: lotes (INICIO ate FIM) acima de ep_lim_s (padrao 60 s)    |
PROMPT | PARADAS    : vezes em que o refresh ficou parado, sem lote rodando     |
PROMPT |              acima de ep_lim_s (padrao 60 s)                           |
PROMPT | ORFAOS     : lote com INICIO sem FIM (abortou com erro)                |
PROMPT | MAIOR LOTE : tempo do lote mais lento (ou orfao), em s (0 = nenhum)    |
PROMPT | MAIOR PARADA: tempo da parada mais longa, em s (0 = nenhuma)           |
PROMPT | CLASSE     : CRITICO = 15 min ou mais, ou teve orfao                   |
PROMPT |              ALTO    = de 5 a 15 min (fora do filtro)                  |
PROMPT |              MEDIO   = menos de 5 min                                  |
PROMPT | Eventos a menos de ep_junta_min (padrao 5 min) viram um so episodio.   |
PROMPT | MEDIO com PARADAS=1 perto de 00:02 e o reinicio diario do grupo02.sh   |
PROMPT | pelo cron (esperado, nao e problema).                                  |
PROMPT +------------------------------------------------------------------------+

SPOOL OFF
SET ECHO OFF
SET TERMOUT OFF;
EXEC dbms_application_info.set_module( module_name => NULL, action_name => NULL);
SET TERMOUT ON;
UNDEFINE ep_mv ep_dias ep_lim_s ep_junta_min ep_classes inst_nome dt_spool current_instance
PROMPT
PROMPT +------------------------------------------------------------------------+
PROMPT | Fim - mview.sql                                                        |
PROMPT +------------------------------------------------------------------------+
SET TIMING ON
SET FEEDBACK ON
