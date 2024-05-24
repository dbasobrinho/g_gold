-- |
-- +-------------------------------------------------------------------------------------------+
-- | Objetivo   : Remove SQLID da Shared Pool de Todas as Instancias                           |
-- | Criador    : Roberto Fernandes Sobrinho                                                   |
-- | Data       : 24/05/2024                                                                   |
-- | Exemplo    : @flush_sqlid_rac.sql                                                         |  
-- | Arquivo    : flush_sqlid_rac.sql                                                          |
-- | Referncia  :                                                                              |
-- | Modificacao:                                                                              |
-- +-------------------------------------------------------------------------------------------+
-- |                                                                https://dbasobrinho.com.br |
-- +-------------------------------------------------------------------------------------------+
-- |"Se você tem amor pelo que tem no peito, mantenha o respeito."
-- +-------------------------------------------------------------------------------------------+
SET TERMOUT OFF;
ALTER SESSION SET NLS_DATE_FORMAT='DD-MON-YY HH24:MI:SS';
EXEC dbms_application_info.set_module( module_name => 'f[flush_sqlid_rac.sql ]', action_name =>  'f[flush_sqlid_rac.sql ]');
COLUMN current_instance NEW_VALUE current_instance NOPRINT;
SELECT rpad(sys_context('USERENV', 'INSTANCE_NAME'), 17) current_instance FROM dual;
SET SERVEROUTPUT ON;
SET TERMOUT ON;
PROMPT
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | https://github.com/dbasobrinho/g_gold/blob/main/flush_sqlid_rac.sql                       |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | Script   : Remove SQLID da Shared Pool de Todas as Instancias    +-+-+-+-+-+-+-+-+-+-+-+  |
PROMPT | Instancia: &current_instance                                     |d|b|a|s|o|b|r|i|n|h|o|  |
PROMPT | Versao   : 1.0                                                   +-+-+-+-+-+-+-+-+-+-+-+  |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT
prompt .
prompt .
prompt -------------------------------------------------------->
ACCEPT v_sql_id CHAR PROMPT 'Informe o SQL_ID: ';
prompt -------------------------------------------------------->
prompt .
prompt .
SET ECHO        OFF
SET FEEDBACK    off
SET HEADING     ON
SET LINES       188
SET PAGES       300 
SET TERMOUT     ON
SET TIMING      OFF
SET TRIMOUT     ON
SET TRIMSPOOL   ON
SET VERIFY      OFF
BEGIN
    FOR sql_row IN (
        SELECT DISTINCT inst_id, sql_id, hash_value, address
        FROM GV$SQL
        WHERE SQL_ID = '&&v_sql_id'
        ORDER BY inst_id
    ) LOOP
        DBMS_SCHEDULER.CREATE_JOB(
            job_name      => '"PBUM_' || sql_row.sql_id || '_' || sql_row.inst_id || '"',
            job_type      => 'PLSQL_BLOCK',
            job_action    => 'BEGIN SYS.DBMS_SHARED_POOL.PURGE (''' || sql_row.address || ',' || sql_row.hash_value || ''',''C''); END;',
            start_date    => SYSDATE,
            enabled       => TRUE,
            auto_drop     => TRUE,
            comments      => 'O Guina não tinha dó e removeu o SqlID: ' || sql_row.sql_id || ' na instância ' || sql_row.inst_id
        );

        DBMS_SCHEDULER.SET_ATTRIBUTE(name => '"PBUM_' || sql_row.sql_id || '_' || sql_row.inst_id || '"', attribute => 'INSTANCE_ID', value => sql_row.inst_id);

        DBMS_OUTPUT.PUT_LINE('JOB: "PBUM_' || sql_row.sql_id || '_' || sql_row.inst_id || '" Plan Hash Value: ' || sql_row.hash_value || ' SYS.DBMS_SHARED_POOL.PURGE (''' || sql_row.address || ',' || sql_row.hash_value || ''',''C'');');
    END LOOP;
    --/
    DBMS_OUTPUT.PUT_LINE('.    ');
    DBMS_OUTPUT.PUT_LINE('.    ');
    DBMS_OUTPUT.PUT_LINE('-------------------------------------------------------->');
    DBMS_OUTPUT.PUT_LINE('Executando a Limpeza! Aguarde! . . .');
    DBMS_OUTPUT.PUT_LINE('-------------------------------------------------------->');
    DBMS_OUTPUT.PUT_LINE('.    ');
    DBMS_OUTPUT.PUT_LINE('.    ');
    --/
END;
/
exec DBMS_LOCK.SLEEP(15);
SELECT COUNT(*) FROM DBA_SCHEDULER_JOBS WHERE JOB_NAME LIKE 'PBUM%';
prompt .
prompt .
COLUMN LOG_DATE FORMAT A40
COLUMN JOB_NAME FORMAT A40
COLUMN STATUS   FORMAT A11
SELECT log_date, job_name, STATUS FROM dba_scheduler_job_log WHERE JOB_NAME LIKE 'PBUM%' and JOB_NAME  LIKE '%&&v_sql_id%' AND log_date >= TRUNC(SYSDATE) ORDER BY log_date;
prompt .
prompt .

SET FEEDBACK ON;



