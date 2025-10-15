-- |
-- +-------------------------------------------------------------------------------------------+
-- | Script     : pdb.sql                                                                      |
-- | Objetivo   : Escolher um PDB por Nº ou NOME e trocar o container da sessão                |
-- | Autor      : Roberto Fernandes Sobrinho                                                   |
-- | Exemplo    : @pdb.sql                                                                      |
-- | Versão     : 1.0 - 06/09/2025                                                             |
-- | Observação : Menu simples e direto. Aceita número da lista ou nome do PDB (case-insensitive).
-- +-------------------------------------------------------------------------------------------+
-- | Dica: se já souber o nome, você pode chamar com variável:                                 |
-- |       define PDB_ALVO=PDB1 ; @pdb.sql                                                     |
-- +-------------------------------------------------------------------------------------------+

-- ===== ambiente
SET TERMOUT OFF;
ALTER SESSION SET NLS_DATE_FORMAT='DD-MON-YY HH24:MI:SS';
EXEC dbms_application_info.set_module( module_name => 's[s.sql]', action_name =>  's[s.sql]');
COLUMN current_instance NEW_VALUE current_instance NOPRINT;
SELECT rpad(sys_context('USERENV', 'INSTANCE_NAME'), 17) current_instance FROM dual;
alter session set container = CDB$ROOT;
SET TERMOUT ON;
PROMPT
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | https://github.com/dbasobrinho/g_gold/blob/main/pdb.sql                                   |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | Script   : alter session set container                           +-+-+-+-+-+-+-+-+-+-+-+  |
PROMPT | Instancia: &current_instance                                     |d|b|a|s|o|b|r|i|n|h|o|  |
PROMPT | Versao   : 1.0                                                   +-+-+-+-+-+-+-+-+-+-+-+  |
PROMPT +-------------------------------------------------------------------------------------------+

-- |
-- +-------------------------------------------------------------------------------------------+
-- | Script     : pdb.sql                                                                      |
-- | Propósito  : Escolher um PDB (por Nº ou NOME) e trocar o container da sessão              |
-- | Autor      : Roberto Fernandes Sobrinho (DBA Sobrinho)                                    |
-- | Exemplo    : @pdb.sql (interativo)                                                        |
-- |             : echo PDB1 | sqlplus -s / as sysdba @pdb.sql (não interativo)                |
-- | Versão     : 1.1 - 06/09/2025                                                             |
-- | Notas      : Sem gambiarra de variável vazia; só ACCEPT + PL/SQL                          |
-- +-------------------------------------------------------------------------------------------+

SET ECHO OFF
SET FEEDBACK off
SET HEADING ON
SET PAGESIZE 200
SET LINESIZE 240
SET TIMING OFF
SET TRIMOUT ON
SET TRIMSPOOL ON
SET VERIFY OFF
SET SERVEROUTPUT ON
SET COLSEP '|'

-- ir ao ROOT pra listar PDBs (ignora erro se já estiver no ROOT)
BEGIN
  EXECUTE IMMEDIATE 'alter session set container = CDB$ROOT';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

CLEAR COLUMNS
CLEAR BREAKS
CLEAR COMPUTES

COLUMN idx       FORMAT 99    HEADING '#'
COLUMN con_id    FORMAT 9999  HEADING 'CON_ID'
COLUMN name      FORMAT A24   HEADING 'PDB'
COLUMN status    FORMAT A10   HEADING 'STATUS'
COLUMN open_mode FORMAT A12   HEADING 'OPEN_MODE'

WITH dados AS (
  SELECT ROW_NUMBER() OVER (ORDER BY p.name) idx,
         p.con_id,
         p.name,
         (SELECT d.status FROM dba_pdbs d WHERE d.pdb_id = p.con_id) AS status,
         p.open_mode, p.dbid
    FROM v$pdbs p
)
SELECT idx, con_id, name, status, open_mode, dbid
  FROM dados
 ORDER BY idx;
PROMPT 
PROMPT +-------------------------------------------------------------------------------------------+
ACCEPT ESCOLHA CHAR PROMPT 'Digite o Nº ou o NOME do PDB (ou CDB$ROOT): '
PROMPT +-------------------------------------------------------------------------------------------+
DECLARE
  v_in       VARCHAR2(128) := TRIM('&&ESCOLHA');
  v_target   VARCHAR2(128);
  v_openmode VARCHAR2(20);
BEGIN
  IF v_in IS NULL THEN
    RAISE_APPLICATION_ERROR(-20001,'Nenhuma opção informada.');
  END IF;

  IF UPPER(v_in) = 'CDB$ROOT' THEN
    v_target   := 'CDB$ROOT';
    SELECT open_mode INTO v_openmode FROM v$database;  -- open_mode do CDB
  ELSIF REGEXP_LIKE(v_in,'^\d+$') THEN
    SELECT name INTO v_target
      FROM (SELECT ROW_NUMBER() OVER (ORDER BY name) rn, name FROM v$pdbs)
     WHERE rn = TO_NUMBER(v_in);
    SELECT open_mode INTO v_openmode FROM v$pdbs WHERE name = v_target; -- open_mode do PDB escolhido
  ELSE
    SELECT name, open_mode INTO v_target, v_openmode
      FROM v$pdbs
     WHERE UPPER(name) = UPPER(v_in);
  END IF;

  EXECUTE IMMEDIATE 'alter session set container = "'||v_target||'"';
  --DBMS_OUTPUT.PUT_LINE('OK -> container: '||v_target||' | OPEN_MODE: '||v_openmode);

EXCEPTION
  WHEN NO_DATA_FOUND THEN
    DBMS_OUTPUT.PUT_LINE('Ops: "'||v_in||'" não encontrado.');
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Falha ao trocar container: '||SQLERRM);
END;
/
SET HEADING ON
COLUMN CON_NAME FORMAT A30 HEADING "CON_NAME"
SELECT sys_context('USERENV','CON_NAME') AS CON_NAME,
       CASE
         WHEN sys_context('USERENV','CON_NAME') = 'CDB$ROOT'
         THEN (SELECT open_mode FROM v$database)
         ELSE (SELECT open_mode FROM v$pdbs WHERE name = sys_context('USERENV','CON_NAME'))
       END AS OPEN_MODE
  FROM dual;
PROMPT

UNDEFINE ESCOLHA
SET FEEDBACK ON