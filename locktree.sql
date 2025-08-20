-- |
-- +-------------------------------------------------------------------------------------------+
-- | Objetivo   : Active Locked Tree                                                           |
-- | Criador    : Roberto Fernandes Sobrinho                                                   |
-- | Data       : 25/10/2018                                                                   |
-- | Exemplo    : @locktree.sql                                                                |
-- | Arquivo    : locktree.sql                                                                 |
-- | Referencia :                                                                              |
-- | Modificacao: 2.0 - 25/10/2018 - rfsobrinho - primeira versao                              |
-- |              2.1 - 20/08/2025 - rfsobrinho - Ajuste XID e WAIT_USN/SLOT/SEQ no report     |
-- +-------------------------------------------------------------------------------------------+
-- |                                                                https://dbasobrinho.com.br |
-- +-------------------------------------------------------------------------------------------+
-- |"O Guina não tinha dó, se ragir, BUMMM! vira pó!"
-- +-------------------------------------------------------------------------------------------+
SET TERMOUT OFF;
ALTER SESSION SET NLS_DATE_FORMAT='DD-MON-YY HH24:MI:SS';
EXEC dbms_application_info.set_module( module_name => 'locktree[locktree.sql]', action_name =>  'locktree[locktree.sql]');
COLUMN current_instance NEW_VALUE current_instance NOPRINT;
SELECT rpad(sys_context('USERENV', 'INSTANCE_NAME'), 17) current_instance FROM dual;
SET TERMOUT ON;
PROMPT
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | https://github.com/dbasobrinho/g_gold/blob/main/locktree.sql                              |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | Script   : Arvore de Locks Oracle                                +-+-+-+-+-+-+-+-+-+-+-+  |
PROMPT | Instancia: &current_instance                                     |d|b|a|s|o|b|r|i|n|h|o|  |
PROMPT | Versao   : 2.1                                                   +-+-+-+-+-+-+-+-+-+-+-+  |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT
SET ECHO        OFF
SET FEEDBACK    on
SET HEADING     ON
SET LINES       210    
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
COLUMN level              FORMAT 9999      HEADING 'LEVEL|-'           JUSTIFY CENTER
COLUMN username           FORMAT A26       HEADING 'USERNAME|-'        JUSTIFY CENTER
COLUMN osuser             FORMAT A20       HEADING 'OSUSER|-'          JUSTIFY CENTER
COLUMN SID_SERIAL         FORMAT A16       HEADING 'SID/SERIAL|-'      JUSTIFY CENTER
COLUMN block_sid          FORMAT A12       HEADING 'SID/BLOCK|-'       JUSTIFY CENTER
COLUMN status             FORMAT A8        HEADING 'STATUS|-'          JUSTIFY CENTER
COLUMN logon_time         FORMAT A15       HEADING 'LOGON TIME|-'      JUSTIFY CENTER
COLUMN SessionWait        FORMAT A30       HEADING 'EVENT WAIT|-'      JUSTIFY CENTER
COLUMN xid                FORMAT A16       HEADING 'XID|-'             JUSTIFY CENTER
--COLUMN wait_usn           FORMAT 999999    HEADING 'WAIT|USN'          JUSTIFY CENTER
--COLUMN wait_slot          FORMAT 999999    HEADING 'WAIT|SLOT'         JUSTIFY CENTER
--COLUMN wait_seq           FORMAT 999999    HEADING 'WAIT|SEQ'          JUSTIFY CENTER
COLUMN prev_sql_id        FORMAT A13       HEADING 'SQLID PREV|-'      JUSTIFY CENTER
COLUMN sql_id             FORMAT A13       HEADING 'SQLID|-'           JUSTIFY CENTER
COLUMN last_call_et       FORMAT 99999999  HEADING 'LAST|CALL_ET'      JUSTIFY CENTER
COLUMN seconds_in_wait    FORMAT 99999999  HEADING 'SECONDS|IN_WAIT'   JUSTIFY CENTER
SET COLSEP '|'
SELECT level,
       LPAD(' ', (level-1)*2, ' ') || NVL(substr(s.username,1,25), '(oracle)') AS username,
       substr(s.osuser,1,20) osuser,
       s.sid || ',' || s.serial# || CASE WHEN s.inst_id IS NOT NULL THEN ',@' || s.inst_id END AS SID_SERIAL,
       s.blocking_session || NVL2(s.blocking_session,',@',' ') || s.blocking_instance AS block_sid,
       s.status,
       TO_CHAR(s.logon_time,'DDMMYY HH24:MI:SS') AS logon_time,
       SUBSTR((SELECT TRIM(SUBSTR(w.event,1,100))
                 FROM gv$session_wait w
                WHERE w.sid = s.sid
                  AND w.inst_id = s.inst_id),1,30) AS SessionWait,
       NVL( (SELECT RAWTOHEX(t.xid)
               FROM gv$transaction t
              WHERE t.inst_id = s.inst_id
                AND t.ses_addr = s.saddr
                AND ROWNUM = 1),
            'N/A') AS xid,
--       CASE WHEN s.event LIKE 'enq: TX - row lock contention'
--            THEN TRUNC(s.p1/65536) END AS wait_usn,
--       CASE WHEN s.event LIKE 'enq: TX - row lock contention'
--            THEN MOD(s.p1,65536) END  AS wait_slot,
--       CASE WHEN s.event LIKE 'enq: TX - row lock contention'
--            THEN s.p2 END             AS wait_seq,
       s.prev_sql_id,
       s.sql_id,
       s.last_call_et,
       s.seconds_in_wait
FROM   gv$session s
WHERE  level > 1
   OR  EXISTS (SELECT 1
                 FROM gv$session x
                WHERE x.blocking_session  = s.sid
                  AND x.blocking_instance = s.inst_id)
CONNECT BY PRIOR s.sid       = s.blocking_session
       AND PRIOR s.inst_id   = s.blocking_instance
START WITH s.blocking_session IS NULL;

SET LINES       190 
SET PAGES       300 