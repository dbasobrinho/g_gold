-- |
-- +-------------------------------------------------------------------------------------------+
-- | Objetivo   : Exibir informações detalhadas dos tablespaces de UNDO                       |
-- | Criador    : Roberto Fernandes Sobrinho                                                  |
-- | Data       : 22/05/2020                                                                  |
-- | Exemplo    : @undo.sql                                                                   |
-- | Arquivo    : undo.sql                                                                    |
-- | Referência : https://dbasobrinho.com.br                                                  |
-- | Modificação: 1.0 - 22/05/2020 - rfsobrinho - Versão inicial com FORMAT_SIZE e % usado    |
-- +-------------------------------------------------------------------------------------------+
-- |                                                                https://dbasobrinho.com.br |
-- +-------------------------------------------------------------------------------------------+
-- | "O Guina não tinha dó. Se reagir... BUMMM! Vira pó!"                                      |
-- +-------------------------------------------------------------------------------------------+
--> while true; do
-->   echo ===================================================
-->   date '+%Y-%m-%d %H:%M:%S'
-->   echo "@s.sql" | sqlplus -s / as sysdba | tail -n +12 | egrep -i 'f2xb0s01bh9cy|SESSIONWAIT'
-->   sleep 10
-->   echo . . . 
--> done
-- +-------------------------------------------------------------------------------------------+
SET TERMOUT OFF;
ALTER SESSION SET NLS_DATE_FORMAT='DD-MON-YY HH24:MI:SS';
EXEC dbms_application_info.set_module(module_name => '[u]ndo.sql', action_name => '[u]ndo.sql');
COLUMN current_instance NEW_VALUE current_instance NOPRINT;
SELECT rpad(sys_context('USERENV', 'INSTANCE_NAME'), 17) current_instance FROM dual;
SET TERMOUT ON;

PROMPT
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | https://github.com/dbasobrinho/g_gold/blob/main/undo.sql                                  |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | Script   : Informacoes de UNDO                                    +-+-+-+-+-+-+-+-+-+-+-+ |
PROMPT | Instância: &current_instance                                     |d|b|a|s|o|b|r|i|n|h|o| |
PROMPT | Versão   : 1.0                                                   +-+-+-+-+-+-+-+-+-+-+-+ |
PROMPT +-------------------------------------------------------------------------------------------+


SET TERMOUT OFF;
COLUMN X1 NEW_VALUE X1 NOPRINT;
COLUMN X2 NEW_VALUE X2 NOPRINT;
SELECT 'ALTER TABLESPACE '''||'<UNDO_NAME>'||''' RETENTION GUARANTEE;' X1 FROM DUAL;
SELECT 'ALTER TABLESPACE '''||'<UNDO_NAME>'||''' RETENTION NOGUARANTEE;' X2 FROM DUAL;


SET TERMOUT ON;

PROMPT 
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | &X1      
PROMPT | &X2                                        
PROMPT +-------------------------------------------------------------------------------------------+


SET ECHO        OFF
SET FEEDBACK    10
SET HEADING     ON
SET LINES       190 
SET PAGES       300 
SET TERMOUT     ON
SET TIMING      OFF
SET TRIMOUT     ON
SET TRIMSPOOL   ON
SET VERIFY      OFF

CLEAR COLUMNS
CLEAR BREAKS
CLEAR COMPUTES

SET COLSEP '|'

COLUMN nome_tablespace     HEADING 'NOME|TABLESPACE'     FORMAT A25 JUSTIFY CENTER
COLUMN tipo_retencao       HEADING 'TIPO|RETENCAO'       FORMAT A15 JUSTIFY CENTER
COLUMN tamanho_total_fmt   HEADING 'ESPACO|TOTAL'        FORMAT A15 JUSTIFY CENTER
COLUMN tamanho_usado_fmt   HEADING 'ESPACO|USADO'        FORMAT A15 JUSTIFY CENTER
COLUMN tamanho_livre_fmt   HEADING 'ESPACO|LIVRE'        FORMAT A15 JUSTIFY CENTER
COLUMN percentual_usado    HEADING '%|USADO'             FORMAT A7 JUSTIFY CENTER
COLUMN status              HEADING 'STATUS|TABLESPACE'   FORMAT A15 JUSTIFY CENTER

PROMPT
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | Utilizacao dos tablespaces de UNDO 
PROMPT +-------------------------------------------------------------------------------------------+

SELECT 
  a.tablespace_name AS nome_tablespace,
  a.retention       AS tipo_retencao,
  LPAD(DBMS_XPLAN.FORMAT_SIZE(a.total_bytes), 15, ' ')                    AS tamanho_total_fmt,
  LPAD(DBMS_XPLAN.FORMAT_SIZE(NVL(b.usado_bytes, 0)), 15, ' ')            AS tamanho_usado_fmt,
  LPAD(DBMS_XPLAN.FORMAT_SIZE(a.total_bytes - NVL(b.usado_bytes, 0)), 15, ' ') AS tamanho_livre_fmt,
  TO_CHAR(100 - (100 * ((a.total_bytes - NVL(b.usado_bytes, 0)) / a.total_bytes)), '990.00') AS percentual_usado,
  a.status AS status
FROM
  (SELECT 
     SUM(df.bytes) AS total_bytes,
     dt.tablespace_name,
     dt.retention,
     dt.status
   FROM dba_data_files df
   JOIN dba_tablespaces dt 
     ON df.tablespace_name = dt.tablespace_name
   WHERE dt.contents = 'UNDO'
   GROUP BY dt.tablespace_name, dt.status, dt.retention
  ) a
LEFT JOIN
  (SELECT 
     ue.tablespace_name,
     SUM(
       CASE
         WHEN ue.status IN ('ACTIVE', 'UNEXPIRED') THEN ue.bytes
         ELSE 0
       END
     ) AS usado_bytes
   FROM dba_undo_extents ue
   GROUP BY ue.tablespace_name
  ) b 
  ON a.tablespace_name = b.tablespace_name
ORDER BY 1;

PROMPT
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | Arquivos físicos dos tablespaces de UNDO 
PROMPT +-------------------------------------------------------------------------------------------+

SET LINESIZE 300
SET PAGESIZE 100
SET COLSEP '|'

COLUMN tablespace_name    HEADING 'NOME TABLESPACE'        FORMAT A25
COLUMN file_id            HEADING 'ARQUIVO ID'             FORMAT 99999
COLUMN file_name          HEADING 'NOME ARQUIVO PATH'      FORMAT A100
COLUMN size_formatado     HEADING 'TAMANHO'                FORMAT A15

SELECT 
  dt.tablespace_name,
  ddf.file_id,
  ddf.file_name,
  LPAD(DBMS_XPLAN.FORMAT_SIZE(SUM(ddf.bytes)), 15, ' ') AS size_formatado
FROM 
  dba_tablespaces dt,
  dba_data_files ddf
WHERE 
  dt.tablespace_name = ddf.tablespace_name
  AND dt.contents = 'UNDO'
GROUP BY 
  dt.tablespace_name,
  ddf.file_name,
  ddf.file_id
ORDER BY 
  dt.tablespace_name,
  ddf.file_id;


PROMPT
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | Sessoes que estao utilizando UNDO                                                      
PROMPT +-------------------------------------------------------------------------------------------+

COLUMN sid_serial FORMAT A22 HEADING 'SID/SERIAL@|INSTANCIA'
COLUMN username   FORMAT A35 HEADING 'USUARIO|ORACLE'
COLUMN program    FORMAT A50 HEADING 'PROGRAMA|CLIENTE'
COLUMN undoseg    FORMAT A20 HEADING 'SEGMENTO|UNDO'
COLUMN undo       FORMAT A10 HEADING 'TAMANHO|UNDO'
COLUMN used_urec  FORMAT 99999 HEADING 'UNDO|RECORDS'
COLUMN rssize_fmt FORMAT A10 HEADING 'TAMANHO|RSSIZE'
COLUMN status     FORMAT A8 HEADING 'STATUS|SEGMENTO'
COLUMN xid        FORMAT A16 HEADING 'XID|TRANSACAO'
COLUMN sql_id     FORMAT A13 HEADING 'SQL_ID|ATUAL'

SELECT 
  s.sid || ',' || s.serial# || '@' || s.inst_id         AS sid_serial,
  NVL(s.username, '(oracle)')                           AS username,
  SUBSTR(s.program, 1, 50)                              AS program,
  '_SYSSMU' || TO_CHAR(t.xidusn) || '$'                 AS undoseg,
  LPAD(ROUND(t.used_ublk * TO_NUMBER(p.value)/1024) || 'K', 10) AS undo,
  t.used_urec                                           AS used_urec,
  LPAD(DBMS_XPLAN.FORMAT_SIZE(r.rssize), 10)            AS rssize_fmt,
  r.status                                              AS status,
  RAWTOHEX(t.xid)                                       AS xid,
  s.sql_id                                              AS sql_id
FROM   
  gv$session     s
JOIN 
  gv$transaction t ON s.taddr = t.addr AND s.inst_id = t.inst_id
JOIN 
  gv$rollstat    r ON t.xidusn = r.usn AND t.inst_id = r.inst_id
JOIN 
  gv$parameter   p ON p.name = 'db_block_size' AND p.inst_id = s.inst_id
WHERE 
  t.used_ublk > 0
ORDER BY 
  t.used_ublk DESC;
  
PROMPT
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | Uso atual de UNDO por instância (MB por status e percentual frente ao total e retenção)
PROMPT +-------------------------------------------------------------------------------------------+

COLUMN inst_id         FORMAT 999  HEADING 'ID|INST'
COLUMN tbs             FORMAT A25  HEADING 'TABLESPACE|UNDO'
COLUMN status          FORMAT A10  HEADING 'STATUS|EXTENT'
COLUMN tamanho         FORMAT A12  HEADING 'TAMANHO|TOTAL'
COLUMN PERC        FORMAT 999999  HEADING '% USO|TOTAL'
COLUMN FULL   FORMAT 999999  HEADING '% USO|RETENCAO'
  
BREAK ON REPORT
COMPUTE SUM OF TAMNHO ON REPORT
COMPUTE SUM OF PERC ON REPORT
COMPUTE SUM OF FULL ON REPORT
BREAK ON report ON TBS SKIP 1

select --A.TBS,B.TBS,C.TBS, 
       C.INST_ID, A.TBS, status,
 LPAD(DBMS_XPLAN.FORMAT_SIZE(sum_bytes), 10) as tamanho,
 round((sum_bytes / undo_size) * 100, 0) as PERC,
 decode(status, 'UNEXPIRED', round((sum_bytes / undo_size * factor) * 100, 0),
                'EXPIRED',   0, round((sum_bytes / undo_size) * 100, 0)) FULL
from
(
 select TABLESPACE_NAME TBS, status, sum(bytes) sum_bytes
 from dba_undo_extents
 --where TABLESPACE_NAME = 'APPS_UNDOTS1'
 group by status, TABLESPACE_NAME
 order by TABLESPACE_NAME, status
) a,
(
 select sum(a.bytes) undo_size, c.tablespace_name TBS
 from dba_tablespaces c
 join v$tablespace b on b.name = c.tablespace_name
 join v$datafile a on a.ts# = b.ts#
 where c.contents = 'UNDO' --and c.tablespace_name = 'APPS_UNDOTS1'
 and c.status = 'ONLINE'
 group by c.tablespace_name
) b,
(
select z.* from (
 select us.INST_ID, tuned_undoretention, u.value, u.value/tuned_undoretention factor
 ,(select x.value from gv$parameter x where x.name = 'undo_tablespace' and x.INST_ID = us.INST_ID) tbs 
 from gv$undostat us
 join (select INST_ID, max(end_time) end_time from gv$undostat group by INST_ID) usm on usm.end_time = us.end_time 
 and usm.INST_ID = us.INST_ID
 join (select y.INST_ID, y.name, y.value, (select x.value from gv$parameter x where x.name = 'undo_tablespace' and x.INST_ID = y.INST_ID ) tbs
 from gv$parameter y where y.name = 'undo_retention') u on u.INST_ID = us.INST_ID) z where z.tbs =  z.tbs --'APPS_UNDOTS1'
) c
where A.TBS = B.TBS 
AND B.TBS = C.TBS
ORDER BY 1,2,3
/

--tbs_undo_tbs_size.sql
--tbs_undo_tbs_file.sql
--tbs_undo_user_size.sql
--tbs_undo_session_rac.sql
--undo_status2.sql