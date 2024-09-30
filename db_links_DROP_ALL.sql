-- |
-- +-------------------------------------------------------------------------------------------+
-- | Objetivo   : Sessoes Ativas                                                               |
-- | Criador    : Roberto Fernandes Sobrinho                                                   |
-- | Data       : 10/08/2022                                                                   |
-- | Exemplo    : @db_links_DROP_ALL.sql                                                       |  
-- | Arquivo    : db_links_DROP_ALL.sql                                                        |
-- | Referencia :                                                                              |
-- | Modificacao: 1.0 - 10/08/2022 - rfsobrinho -  Versão Inicial                              |
-- +-------------------------------------------------------------------------------------------+
-- |                                                                https://dbasobrinho.com.br |
-- +-------------------------------------------------------------------------------------------+
-- |"Não espere o futuro mudar tua vida, porque o futuro é a consequência do presente."        |
-- | Racionais MC's (Música: A Vida É Desafio)                                                 |
-- +-------------------------------------------------------------------------------------------+
SET TERMOUT OFF;
ALTER SESSION SET NLS_DATE_FORMAT='DD-MON-YY HH24:MI:SS';
EXEC dbms_application_info.set_module(module_name => 'd[db_links_DROP_ALL.sql]', action_name => 'd[db_links_DROP_ALL.sql]');
COLUMN current_instance NEW_VALUE current_instance NOPRINT;
SELECT rpad(sys_context('USERENV', 'INSTANCE_NAME'), 17) current_instance FROM dual;
SET TERMOUT ON;
PROMPT
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | https://github.com/dbasobrinho/g_gold/blob/main/db_links_DROP_ALL.sql                     |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | Script   : Remover Todos os DBLinks                              +-+-+-+-+-+-+-+-+-+-+-+  |
PROMPT | Instancia: &current_instance                                     |d|b|a|s|o|b|r|i|n|h|o|  |
PROMPT | Versao   : 1.0                                                   +-+-+-+-+-+-+-+-+-+-+-+  |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT

COLUMN db_name NEW_VALUE db_name NOPRINT;
SELECT name AS db_name FROM v$database;
PROMPT Nome do Banco de Dados: &db_name
ACCEPT proceed CHAR PROMPT 'Tem certeza que deseja continuar com a exclusão de TODOS os DBLinks neste banco de dados (&db_name)? (S/N): ';
BEGIN
  IF UPPER('&proceed') <> 'S' THEN
    dbms_output.put_line('Operação cancelada pelo usuário. Nenhuma ação foi realizada.');
    RAISE_APPLICATION_ERROR(-20001, 'Script abortado pelo usuário.');
  END IF;
END;
/

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
COLUMN db_link FORMAT A30
COLUMN host FORMAT A60
COLUMN owner FORMAT A12
COLUMN username FORMAT A22

PROMPT
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | Exibindo todos os DBLinks antes da exclusão                                               |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT

SELECT owner, db_link, username, host
FROM   dba_db_links
ORDER BY owner, db_link;

PROMPT
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | Realizando exclusão de TODOS os DBLinks                                                   |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT

SET SERVEROUTPUT ON
DECLARE
  vv_sql CLOB :=
   'CREATE PROCEDURE ##USU##.prc_auto_drop_db_links
    IS
    BEGIN
      FOR i IN (SELECT * FROM user_db_links)
      LOOP
        EXECUTE IMMEDIATE ''DROP DATABASE LINK ''||i.db_link;
      END LOOP;
    END;';
  vv_sql1 clob;  
BEGIN
  FOR i IN (SELECT db_link FROM dba_db_links WHERE owner = 'PUBLIC') LOOP
     EXECUTE IMMEDIATE 'DROP PUBLIC DATABASE LINK ' || i.db_link;
  END LOOP;

  FOR i in (SELECT DISTINCT owner 
             FROM dba_objects
            WHERE object_type='DATABASE LINK'
              AND owner IN (SELECT USERNAME FROM DBA_USERS))
  LOOP
    vv_sql1 := REPLACE(vv_sql, '##USU##', i.owner);
    dbms_output.put_line('Excluindo DBLinks do usuario: ' || i.owner);
    EXECUTE IMMEDIATE vv_sql1;
    vv_sql1 := 'BEGIN ' || i.owner || '.prc_auto_drop_db_links; END;';
    EXECUTE IMMEDIATE vv_sql1;
    vv_sql1 := 'DROP PROCEDURE ' || i.owner || '.prc_auto_drop_db_links';
    EXECUTE IMMEDIATE vv_sql1;
  END LOOP;
END;
/

PROMPT
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | Exibindo todos os DBLinks após a exclusão                                                 |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT

SELECT owner, db_link, username, host
FROM   dba_db_links
ORDER BY owner, db_link;
