-- |
-- +-------------------------------------------------------------------------------------------+
-- | Objetivo   : Lista quantidade de sessoes executando o mesmo SQLID                         |
-- | Criador    : Roberto Fernandes Sobrinho                                                   |
-- | Data       : 15/12/2015                                                                   |
-- | Exemplo    : @s_count_sqlid_ativo.sql                                                     |  
-- | Arquivo    : s_count_sqlid_ativo.sql                                                      |
-- | Referncia  :                                                                              |
-- | Modificacao: 1.0 - 17/12/2024 - rfsobrinho - Versao Inicial                               |
-- +-------------------------------------------------------------------------------------------+
-- |                                                                https://dbasobrinho.com.br |
-- +-------------------------------------------------------------------------------------------+
-- |"O Guina não tinha dó, se ragir, BUMMM! vira pó!"
-- +-------------------------------------------------------------------------------------------+
SET TERMOUT OFF;
ALTER SESSION SET NLS_DATE_FORMAT='DD-MON-YY HH24:MI:SS';
EXEC dbms_application_info.set_module( module_name => 's[s.sql]', action_name =>  's[s.sql]');
COLUMN current_instance NEW_VALUE current_instance NOPRINT;
SELECT rpad(sys_context('USERENV', 'INSTANCE_NAME'), 17) current_instance FROM dual;
SET TERMOUT ON;
PROMPT
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | https://github.com/dbasobrinho/g_gold/blob/main/s_count_sqlid_ativo.sql                   |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | Script   : Quantidade de Sessoes Executando o Mesmo SQLID        +-+-+-+-+-+-+-+-+-+-+-+  |
PROMPT | Instancia: &current_instance                                     |d|b|a|s|o|b|r|i|n|h|o|  |
PROMPT | Versao   : 1.0                                                   +-+-+-+-+-+-+-+-+-+-+-+  |
PROMPT +-------------------------------------------------------------------------------------------+
SET ECHO        OFF
SET FEEDBACK    10
SET HEADING     ON
SET LINES       188
SET PAGES       300 
SET TERMOUT     ON
SET TIMING      OFF
SET TRIMOUT     ON
SET TRIMSPOOL   ON
SET VERIFY      OFF
CLEAR COLUMNS 
CLEAR BREAKS
CLEAR COMPUTES
col SQL_ID       format a20 HEADING 'SQL_ID/CHILD'
SET COLSEP '|'  
    SELECT COUNT(1) AS qtd, sql_id
    FROM (
        SELECT s.sql_id || '[' || s.sql_child_number||']' AS sql_id
        FROM gv$session s, gv$process p, gv$px_session e
        WHERE s.paddr = p.addr (+)
          AND s.inst_id = p.inst_id (+)
          AND s.status = 'ACTIVE'
          AND s.inst_id = e.inst_id (+)
          AND s.sid = e.sid (+)
          AND s.serial# = e.serial# (+)
          AND NVL(
              CASE WHEN e.qcsid IS NOT NULL THEN e.qcsid || ',' || e.qcserial# END, 
              SUBSTR(TRIM(s.WAIT_CLASS), 1, 13)
          ) != 'Idle'
          AND s.username IS NOT NULL
		  and s.sql_id is not null
    )
    GROUP BY sql_id
    HAVING COUNT(1) > 1
	order by 1 desc
/
SET FEEDBACK on
PROMPT
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | @sess_kill_ACT_sqlid_instance_no_stop.sql                                                 |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT

--SET COLSEP ' '