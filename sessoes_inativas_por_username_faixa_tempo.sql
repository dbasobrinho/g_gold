-- |
-- +----------------------------------------------------------------------------------------------------+
-- | Objetivo   : Sessoes INACTIVE por USERNAME agrupadas por faixa de tempo ocioso                     |
-- | Criador    : Roberto Fernandes Sobrinho                                                            |
-- | Data       : 09/09/2026                                                                            |
-- | Exemplo    : @sessoes_inativas_por_username_faixa_tempo.sql                                        |
-- |              Usuario (ENTER = todos): PPW_INTEGRATION                                              |
-- |              Usuario (ENTER = todos): PPW%                                                         |
-- | Arquivo    : sessoes_inativas_por_username_faixa_tempo.sql                                         |
-- | Referncia  : GV$SESSION.LAST_CALL_ET                                                               |
-- | Modificacao: 1.0 - 01/05/2021 - rfsobrinho - Versao inicial                                        |
-- |              1.1 - 09/09/2026 - rfsobrinho - Usuario solicitado via ACCEPT                         |
-- +----------------------------------------------------------------------------------------------------+
-- |                                                         https://dbasobrinho.com.br                 |
-- +----------------------------------------------------------------------------------------------------+
-- |"Sessao parada tambem ocupa cadeira."
-- +----------------------------------------------------------------------------------------------------+
SET TERMOUT ON
SET VERIFY OFF
PROMPT
PROMPT +----------------------------------------------------------------------------------------------------+
PROMPT | Informe o USERNAME. Aceita curinga % . ENTER = todos os usuarios.                                  |
PROMPT +----------------------------------------------------------------------------------------------------+
ACCEPT v_user CHAR DEFAULT '%' PROMPT 'Usuario (ENTER = todos): '

SET TERMOUT OFF;
ALTER SESSION SET NLS_DATE_FORMAT='DD-MON-YY HH24:MI:SS';
EXEC dbms_application_info.set_module( module_name => 's[sess_inat_faixa]', action_name =>  's[sess_inat_faixa]');
COLUMN current_instance NEW_VALUE current_instance NOPRINT;
SELECT rpad(sys_context('USERENV', 'INSTANCE_NAME'), 17) current_instance FROM dual;
COLUMN v_user_show NEW_VALUE v_user_show NOPRINT;
SELECT rpad(upper(nvl('&v_user','%')), 45) v_user_show FROM dual;
SET TERMOUT ON;
PROMPT
PROMPT +----------------------------------------------------------------------------------------------------+
PROMPT | https://github.com/dbasobrinho/g_gold/blob/main/sessoes_inativas_por_username_faixa_tempo.sql      |
PROMPT +----------------------------------------------------------------------------------------------------+
PROMPT | Script   : Sessoes INACTIVE por USERNAME e faixa de tempo ocioso          +-+-+-+-+-+-+-+-+-+-+-+  |
PROMPT | Instancia: &current_instance                                              |d|b|a|s|o|b|r|i|n|h|o|  |
PROMPT | Versao   : 1.1                                                            +-+-+-+-+-+-+-+-+-+-+-+  |
PROMPT +----------------------------------------------------------------------------------------------------+
PROMPT | Usuario  : &v_user_show                                           |
PROMPT +----------------------------------------------------------------------------------------------------+
PROMPT

SPOOL sessoes_inativas_por_username_faixa_tempo.out

SET ECHO        ON
SET FEEDBACK    ON
SET HEADING     ON
SET LINES       200
SET PAGES       300
SET TERMOUT     ON
SET TIMING      OFF
SET TRIMOUT     ON
SET TRIMSPOOL   ON
SET VERIFY      OFF
SET COLSEP '|'
CLEAR COLUMNS
CLEAR BREAKS
CLEAR COMPUTES

COL FAIXA_OCIOSA FORMAT A15     HEADING 'FAIXA_OCIOSA'  JUSTIFY C
COL NO1          FORMAT 999990  HEADING 'NO1'           JUSTIFY C
COL NO2          FORMAT 999990  HEADING 'NO2'           JUSTIFY C
COL NO3          FORMAT 999990  HEADING 'NO3'           JUSTIFY C
COL NO4          FORMAT 999990  HEADING 'NO4'           JUSTIFY C
COL TOTAL        FORMAT 9999990 HEADING 'TOTAL'         JUSTIFY C
COL PCT          FORMAT 990.9   HEADING 'PCT'           JUSTIFY C
COL PCT_ACUM     FORMAT 990.9   HEADING 'PCT_ACUM'      JUSTIFY C

BREAK ON REPORT
COMPUTE SUM LABEL 'TOTAL' OF NO1 NO2 NO3 NO4 TOTAL ON REPORT

SELECT FAIXA_OCIOSA,
       NO1,
       NO2,
       NO3,
       NO4,
       TOTAL,
       ROUND(TOTAL * 100 / SUM(TOTAL) OVER (), 1) AS PCT,
       ROUND(SUM(TOTAL) OVER (ORDER BY ORD) * 100 / SUM(TOTAL) OVER (), 1) AS PCT_ACUM
  FROM (
        SELECT CASE
                 WHEN FLOOR(NVL(LAST_CALL_ET,0)/3600) >= 24 THEN '24h ou mais'
                 ELSE LPAD(TO_CHAR(FLOOR(NVL(LAST_CALL_ET,0)/3600)),2,'0') || ' a ' ||
                      LPAD(TO_CHAR(FLOOR(NVL(LAST_CALL_ET,0)/3600)+1),2,'0') || ' h'
               END AS FAIXA_OCIOSA,
               LEAST(FLOOR(NVL(LAST_CALL_ET,0)/3600), 24) AS ORD,
               COUNT(CASE WHEN INST_ID = 1 THEN 1 END) AS NO1,
               COUNT(CASE WHEN INST_ID = 2 THEN 1 END) AS NO2,
               COUNT(CASE WHEN INST_ID = 3 THEN 1 END) AS NO3,
               COUNT(CASE WHEN INST_ID = 4 THEN 1 END) AS NO4,
               COUNT(*) AS TOTAL
          FROM GV$SESSION
         WHERE USERNAME LIKE UPPER(NVL('&v_user','%'))
           AND STATUS   = 'INACTIVE'
           AND TYPE     = 'USER'
         GROUP BY CASE
                    WHEN FLOOR(NVL(LAST_CALL_ET,0)/3600) >= 24 THEN '24h ou mais'
                    ELSE LPAD(TO_CHAR(FLOOR(NVL(LAST_CALL_ET,0)/3600)),2,'0') || ' a ' ||
                         LPAD(TO_CHAR(FLOOR(NVL(LAST_CALL_ET,0)/3600)+1),2,'0') || ' h'
                  END,
                  LEAST(FLOOR(NVL(LAST_CALL_ET,0)/3600), 24)
       )
 ORDER BY ORD
/

CLEAR BREAKS
CLEAR COMPUTES
CLEAR COLUMNS

COL INST_ID      FORMAT 990     HEADING 'NO'                JUSTIFY C
COL QTD          FORMAT 9999990 HEADING 'QTD_INACTIVE'      JUSTIFY C
COL MIN_OCIOSA   FORMAT A12     HEADING 'MIN_OCIOSA'        JUSTIFY C
COL MAX_OCIOSA   FORMAT A12     HEADING 'MAX_OCIOSA'        JUSTIFY C
COL MAIS_ANTIGA  FORMAT A20     HEADING 'LOGON_MAIS_ANTIGO' JUSTIFY C

SELECT INST_ID,
       COUNT(*) AS QTD,
       LPAD(TO_CHAR(FLOOR(MIN(NVL(LAST_CALL_ET,0))/3600)),3,'0') || 'h' ||
       LPAD(TO_CHAR(MOD(FLOOR(MIN(NVL(LAST_CALL_ET,0))/60),60)),2,'0') || 'm' AS MIN_OCIOSA,
       LPAD(TO_CHAR(FLOOR(MAX(NVL(LAST_CALL_ET,0))/3600)),3,'0') || 'h' ||
       LPAD(TO_CHAR(MOD(FLOOR(MAX(NVL(LAST_CALL_ET,0))/60),60)),2,'0') || 'm' AS MAX_OCIOSA,
       TO_CHAR(MIN(LOGON_TIME),'DD/MM/YYYY HH24:MI:SS') AS MAIS_ANTIGA
  FROM GV$SESSION
 WHERE USERNAME LIKE UPPER(NVL('&v_user','%'))
   AND STATUS   = 'INACTIVE'
   AND TYPE     = 'USER'
 GROUP BY INST_ID
 ORDER BY INST_ID
/

SET ECHO OFF
SPOOL OFF

UNDEFINE v_user
CLEAR COLUMNS
CLEAR BREAKS
CLEAR COMPUTES
PROMPT
PROMPT +----------------------------------------------------------------------------------------------------+
PROMPT | Saida gerada em: sessoes_inativas_por_username_faixa_tempo.out                                     |
PROMPT +----------------------------------------------------------------------------------------------------+
PROMPT
