-- |
-- +-------------------------------------------------------------------------------------------+
-- | Objetivo   : Gera o SQL Patch de um SQL_ID (Oracle 12.2 em diante)                        |
-- |              API publica DBMS_SQLDIAG.CREATE_SQL_PATCH (sql_id)                           |
-- |              Uso tipico: hint GATHER_PLAN_STATISTICS sem mexer no codigo                  |
-- |              Para 11g e 12.1 use coe_sql_patch_11g.sql                                    |
-- | Criador    : Roberto Fernandes Sobrinho                                                   |
-- | Data       : 26/05/2020                                                                   |
-- | Exemplo    : @coe_sql_patch_12c.sql                                                       |
-- | Arquivo    : coe_sql_patch_12c.sql                                                        |
-- | Referencia : Oracle Docs DBMS_SQLDIAG 19c (links completos abaixo)                        |
-- | Modificacao: 1.0 - 26/05/2020 - rfsobrinho - Versao inicial (tun_..._12_maior)            |
-- |              2.0 - 26/09/2026 - rfsobrinho - Padrao dbasobrinho, renomeado para coe_      |
-- |              2.1 - 26/09/2026 - rfsobrinho - Nao cria mais o patch: gera _create e _drop  |
-- |              2.2 - 02/10/2026 - rfsobrinho - Corrige _create/_drop: PROMPT tirava o ';'   |
-- +-------------------------------------------------------------------------------------------+
-- |                                                                https://dbasobrinho.com.br |
-- +-------------------------------------------------------------------------------------------+
-- |"O Guina nao tinha do, se ragir, BUMMM! vira po!"
-- +-------------------------------------------------------------------------------------------+
-- | Ref: https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/DBMS_SQLDIAG.html
-- | Ref: https://blogs.oracle.com/optimizer/using-sql-patch-to-add-hints-to-a-packaged-application
-- +-------------------------------------------------------------------------------------------+

SET TERMOUT OFF;
ALTER SESSION SET NLS_DATE_FORMAT='DD-MON-YY HH24:MI:SS';
EXEC dbms_application_info.set_module( module_name => 'patch[coe_sql_patch_12c.sql]', action_name => 'patch[coe_sql_patch_12c.sql]');
COLUMN current_instance NEW_VALUE current_instance NOPRINT;
SELECT rpad(sys_context('USERENV', 'INSTANCE_NAME'), 17) current_instance FROM dual;
COLUMN db_version NEW_VALUE db_version NOPRINT;
SELECT rpad(version, 10) db_version FROM v$instance;
SET TERMOUT ON;

PROMPT
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | https://github.com/dbasobrinho/g_gold/blob/master/coe_sql_patch_12c.sql                   |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | Script   : SQL Patch por SQL_ID (12.2+)                          +-+-+-+-+-+-+-+-+-+-+-+  |
PROMPT | Instancia: &current_instance                                     |d|b|a|s|o|b|r|i|n|h|o|  |
PROMPT | Versao   : 2.2                                                   +-+-+-+-+-+-+-+-+-+-+-+  |
PROMPT | Banco    : &db_version (requer 12.2 ou superior)                                           |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | Este script NAO cria o patch. Ele gera dois arquivos para voce revisar e executar:        |
PROMPT |   coe_sql_patch_<sql_id>_<data>_create.sql  (cria o patch e valida)                       |
PROMPT |   coe_sql_patch_<sql_id>_<data>_drop.sql    (remove o patch, NAO ESQUECE)                 |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT
ACCEPT sql_id    CHAR PROMPT 'SQL_ID                              = '
PROMPT
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | Sugestoes de hint:                                                                        |
PROMPT |   GATHER_PLAN_STATISTICS      (padrao: coleta A-Rows, A-Time, Buffers)                    |
PROMPT |   PARALLEL(<alias>,<grau>)    (paralelismo na tabela)                                     |
PROMPT | Nao use aspas simples no hint: o texto vai entre aspas no bloco gerado.                   |
PROMPT +-------------------------------------------------------------------------------------------+
ACCEPT hint_text CHAR PROMPT 'HINT [GATHER_PLAN_STATISTICS]        = ' DEFAULT 'GATHER_PLAN_STATISTICS'
PROMPT

SET TERMOUT OFF;
COLUMN arq_base NEW_VALUE arq_base NOPRINT;
SELECT 'coe_sql_patch_' || '&&sql_id' || '_' || TO_CHAR(SYSDATE, 'YYYYMMDD_HH24MISS') arq_base FROM dual;
SET TERMOUT ON;

SET ECHO        OFF
SET FEEDBACK    ON
SET HEADING     ON
SET LINES       250
SET PAGES       300
SET LONG        4000
SET TIMING      OFF
SET TRIMOUT     ON
SET TRIMSPOOL   ON
SET VERIFY      OFF
SET HEADSEP     '|'
SET COLSEP      '|'

CLEAR COLUMNS
CLEAR BREAKS
CLEAR COMPUTES

COL inst_id           FORMAT 99            HEADING 'INST|-'            JUSTIFY CENTER
COL child_number      FORMAT 999           HEADING 'CHILD|-'           JUSTIFY CENTER
COL plan_hash_value   FORMAT 9999999999    HEADING 'PLAN|HASH'         JUSTIFY CENTER
COL executions        FORMAT 999999999     HEADING 'EXEC|-'            JUSTIFY CENTER
COL last_active       FORMAT a18           HEADING 'ULTIMA|ATIVIDADE'  JUSTIFY CENTER
COL parsing_schema    FORMAT a20           HEADING 'SCHEMA|-'          JUSTIFY CENTER
COL sql_patch         FORMAT a30           HEADING 'SQL|PATCH'         JUSTIFY CENTER
COL sql_profile       FORMAT a30           HEADING 'SQL|PROFILE'       JUSTIFY CENTER
COL sql_plan_baseline FORMAT a30           HEADING 'SQL PLAN|BASELINE' JUSTIFY CENTER
COL sql_text          FORMAT a200          HEADING 'SQL_TEXT|(200)'    JUSTIFY CENTER WORD_WRAPPED
COL name              FORMAT a35           HEADING 'PATCH|-'           JUSTIFY CENTER
COL status            FORMAT a10           HEADING 'STATUS|-'          JUSTIFY CENTER
COL category          FORMAT a12           HEADING 'CATEGORY|-'        JUSTIFY CENTER
COL created           FORMAT a20           HEADING 'CRIADO|EM'         JUSTIFY CENTER

SPOOL &&arq_base..out

PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | 1) Texto do SQL_ID &&sql_id (primeiros 200 caracteres)                               |
PROMPT +-------------------------------------------------------------------------------------------+
SELECT SUBSTR(sql_text, 1, 200) sql_text
  FROM gv$sqlarea
 WHERE sql_id = '&&sql_id'
   AND ROWNUM = 1;

PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | 2) Cursores do SQL_ID em memoria (todas as instancias)                                    |
PROMPT +-------------------------------------------------------------------------------------------+
SELECT inst_id,
       child_number,
       plan_hash_value,
       executions,
       TO_CHAR(last_active_time, 'DD/MM/YY HH24:MI:SS') last_active,
       parsing_schema_name parsing_schema,
       sql_patch,
       sql_profile,
       sql_plan_baseline
  FROM gv$sql
 WHERE sql_id = '&&sql_id'
 ORDER BY inst_id, child_number;

PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | 3) Patch com o mesmo nome ja existente (se aparecer, drope antes de criar de novo)        |
PROMPT +-------------------------------------------------------------------------------------------+
SELECT name,
       status,
       category,
       TO_CHAR(created, 'DD/MM/YY HH24:MI:SS') created
  FROM dba_sql_patches
 WHERE name = 'GUINA_PATCH_&&sql_id';

SPOOL OFF

SET FEEDBACK    OFF
SET HEADING     OFF
SET PAGES       0
SET TAB         OFF
SET LINES       400
COL txt FORMAT a400
SET TERMOUT     OFF

SPOOL &&arq_base._create.sql
SELECT txt
  FROM (
        SELECT   1 n, q'[-- +--- gerado por coe_sql_patch_12c.sql em &db_version / &current_instance]' txt FROM dual UNION ALL
        SELECT   2 n, q'[-- +--- revise antes de executar. Rodar como DBA no container onde o SQL executa.]' txt FROM dual UNION ALL
        SELECT   3 n, q'[SET ECHO ON]' txt FROM dual UNION ALL
        SELECT   4 n, q'[SET SERVEROUTPUT ON]' txt FROM dual UNION ALL
        SELECT   5 n, q'[SET LINES 250]' txt FROM dual UNION ALL
        SELECT   6 n, q'[SET PAGES 100]' txt FROM dual UNION ALL
        SELECT   7 n, q'[SET HEADSEP '|']' txt FROM dual UNION ALL
        SELECT   8 n, q'[SET COLSEP '|']' txt FROM dual UNION ALL
        SELECT   9 n, q'[SPOOL &&arq_base._create.out]' txt FROM dual UNION ALL
        SELECT  10 n, q'[DECLARE]' txt FROM dual UNION ALL
        SELECT  11 n, q'[  l_patch VARCHAR2(128);]' txt FROM dual UNION ALL
        SELECT  12 n, q'[BEGIN]' txt FROM dual UNION ALL
        SELECT  13 n, q'[  l_patch := SYS.DBMS_SQLDIAG.CREATE_SQL_PATCH(]' txt FROM dual UNION ALL
        SELECT  14 n, q'[               sql_id      => '&&sql_id',]' txt FROM dual UNION ALL
        SELECT  15 n, q'[               hint_text   => '&&hint_text',]' txt FROM dual UNION ALL
        SELECT  16 n, q'[               name        => 'GUINA_PATCH_&&sql_id',]' txt FROM dual UNION ALL
        SELECT  17 n, q'[               description => 'coe_sql_patch_12c.sql - hint &&hint_text',]' txt FROM dual UNION ALL
        SELECT  18 n, q'[               category    => 'DEFAULT');]' txt FROM dual UNION ALL
        SELECT  19 n, q'[  DBMS_OUTPUT.PUT_LINE('SQL Patch criado: ' || l_patch);]' txt FROM dual UNION ALL
        SELECT  20 n, q'[END;]' txt FROM dual UNION ALL
        SELECT  21 n, q'[/]' txt FROM dual UNION ALL
        SELECT  22 n, q'[SET SERVEROUTPUT OFF]' txt FROM dual UNION ALL
        SELECT  23 n, q'[COL name     FORMAT a35 HEADING 'PATCH|-'    JUSTIFY CENTER]' txt FROM dual UNION ALL
        SELECT  24 n, q'[COL status   FORMAT a10 HEADING 'STATUS|-'   JUSTIFY CENTER]' txt FROM dual UNION ALL
        SELECT  25 n, q'[COL category FORMAT a12 HEADING 'CATEGORY|-' JUSTIFY CENTER]' txt FROM dual UNION ALL
        SELECT  26 n, q'[COL created  FORMAT a20 HEADING 'CRIADO|EM'  JUSTIFY CENTER]' txt FROM dual UNION ALL
        SELECT  27 n, q'[SELECT name, status, category, TO_CHAR(created, 'DD/MM/YY HH24:MI:SS') created]' txt FROM dual UNION ALL
        SELECT  28 n, q'[  FROM dba_sql_patches]' txt FROM dual UNION ALL
        SELECT  29 n, q'[ WHERE name = 'GUINA_PATCH_&&sql_id';]' txt FROM dual UNION ALL
        SELECT  30 n, q'[SET ECHO OFF]' txt FROM dual UNION ALL
        SELECT  31 n, q'[SPOOL OFF]' txt FROM dual UNION ALL
        SELECT  32 n, q'[PROMPT]' txt FROM dual UNION ALL
        SELECT  33 n, q'[PROMPT Confira acima se o patch foi criado. O cursor atual e invalidado: aguarde a proxima execucao do SQL e rode:]' txt FROM dual UNION ALL
        SELECT  34 n, q'[PROMPT   SELECT inst_id, child_number, sql_patch FROM gv$sql WHERE sql_id = '&&sql_id';]' txt FROM dual UNION ALL
        SELECT  35 n, q'[PROMPT   SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR('&&sql_id', <child>, 'ALLSTATS LAST'));]' txt FROM dual UNION ALL
        SELECT  36 n, q'[PROMPT Depois de coletar: @&&arq_base._drop.sql]' txt FROM dual
       )
 ORDER BY n;
SPOOL OFF

SPOOL &&arq_base._drop.sql
SELECT txt
  FROM (
        SELECT   1 n, q'[-- +--- gerado por coe_sql_patch_12c.sql. Remove o SQL Patch do SQL_ID &&sql_id]' txt FROM dual UNION ALL
        SELECT   2 n, q'[-- +--- requer o privilegio DROP ANY SQL PATCH]' txt FROM dual UNION ALL
        SELECT   3 n, q'[SET ECHO ON]' txt FROM dual UNION ALL
        SELECT   4 n, q'[SPOOL &&arq_base._drop.out]' txt FROM dual UNION ALL
        SELECT   5 n, q'[BEGIN]' txt FROM dual UNION ALL
        SELECT   6 n, q'[  SYS.DBMS_SQLDIAG.DROP_SQL_PATCH(name => 'GUINA_PATCH_&&sql_id');]' txt FROM dual UNION ALL
        SELECT   7 n, q'[END;]' txt FROM dual UNION ALL
        SELECT   8 n, q'[/]' txt FROM dual UNION ALL
        SELECT   9 n, q'[SELECT COUNT(*) patches_restantes FROM dba_sql_patches WHERE name = 'GUINA_PATCH_&&sql_id';]' txt FROM dual UNION ALL
        SELECT  10 n, q'[SET ECHO OFF]' txt FROM dual UNION ALL
        SELECT  11 n, q'[SPOOL OFF]' txt FROM dual
       )
 ORDER BY n;
SPOOL OFF

SET TERMOUT     ON
SET FEEDBACK    ON
SET HEADING     ON
SET PAGES       300
PROMPT
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | Arquivos gerados (NADA foi executado no banco):                                           |
PROMPT |   Log desta analise : &&arq_base..out                     |
PROMPT |   Cria o patch      : &&arq_base._create.sql              |
PROMPT |   Remove o patch    : &&arq_base._drop.sql                |
PROMPT | Revise o _create.sql, execute com @ e NAO esqueca do _drop.sql depois da coleta.          |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT

UNDEFINE sql_id
UNDEFINE hint_text
UNDEFINE arq_base
CLEAR COLUMNS
SET COLSEP ' '
SET LINES 200
