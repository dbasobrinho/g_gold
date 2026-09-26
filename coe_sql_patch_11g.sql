-- |
-- +-------------------------------------------------------------------------------------------+
-- | Objetivo   : Gera o SQL Patch de um SQL_ID (Oracle 11g e 12.1)                            |
-- |              API interna DBMS_SQLDIAG_INTERNAL.I_CREATE_PATCH (sql_text)                  |
-- |              Uso tipico: hint GATHER_PLAN_STATISTICS sem mexer no codigo                  |
-- |              O SQL precisa estar na shared pool (GV$SQLAREA) na execucao                  |
-- |              Para 12.2 em diante use coe_sql_patch_12c.sql                                |
-- | Criador    : Roberto Fernandes Sobrinho                                                   |
-- | Data       : 26/05/2020                                                                   |
-- | Exemplo    : @coe_sql_patch_11g.sql                                                       |
-- | Arquivo    : coe_sql_patch_11g.sql                                                        |
-- | Referencia : ORACLE-BASE SQL Repair Advisor 11g (links completos abaixo)                  |
-- | Modificacao: 1.0 - 26/05/2020 - rfsobrinho - Versao inicial (tun_..._11_menor)            |
-- |              2.0 - 26/09/2026 - rfsobrinho - Padrao dbasobrinho, renomeado para coe_      |
-- |              2.1 - 26/09/2026 - rfsobrinho - Nao cria mais o patch: gera _create e _drop  |
-- +-------------------------------------------------------------------------------------------+
-- |                                                                https://dbasobrinho.com.br |
-- +-------------------------------------------------------------------------------------------+
-- |"O Guina nao tinha do, se ragir, BUMMM! vira po!"
-- +-------------------------------------------------------------------------------------------+
-- | Ref: https://oracle-base.com/articles/11g/sql-repair-advisor-11g
-- | Ref: https://blogs.oracle.com/optimizer/using-sql-patch-to-add-hints-to-a-packaged-application
-- +-------------------------------------------------------------------------------------------+

SET TERMOUT OFF;
ALTER SESSION SET NLS_DATE_FORMAT='DD-MON-YY HH24:MI:SS';
EXEC dbms_application_info.set_module( module_name => 'patch[coe_sql_patch_11g.sql]', action_name => 'patch[coe_sql_patch_11g.sql]');
COLUMN current_instance NEW_VALUE current_instance NOPRINT;
SELECT rpad(sys_context('USERENV', 'INSTANCE_NAME'), 17) current_instance FROM dual;
COLUMN db_version NEW_VALUE db_version NOPRINT;
SELECT rpad(version, 10) db_version FROM v$instance;
SET TERMOUT ON;

PROMPT
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | https://github.com/dbasobrinho/g_gold/blob/master/coe_sql_patch_11g.sql                   |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | Script   : SQL Patch por SQL_ID (11g/12.1)                       +-+-+-+-+-+-+-+-+-+-+-+  |
PROMPT | Instancia: &current_instance                                     |d|b|a|s|o|b|r|i|n|h|o|  |
PROMPT | Versao   : 2.1                                                   +-+-+-+-+-+-+-+-+-+-+-+  |
PROMPT | Banco    : &db_version (para 11g e 12.1)                                                   |
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
SET TERMOUT     OFF

SPOOL &&arq_base._create.sql
PROMPT -- +--- gerado por coe_sql_patch_11g.sql em &db_version / &current_instance
PROMPT -- +--- revise antes de executar. Rodar como DBA no container onde o SQL executa.
PROMPT SET ECHO ON
PROMPT SET SERVEROUTPUT ON
PROMPT SET LINES 250
PROMPT SET PAGES 100
PROMPT SET HEADSEP '|'
PROMPT SET COLSEP '|'
PROMPT SPOOL &&arq_base._create.out
PROMPT DECLARE
PROMPT   l_sql_text CLOB;
PROMPT BEGIN
PROMPT   SELECT sql_fulltext
PROMPT     INTO l_sql_text
PROMPT     FROM gv$sqlarea
PROMPT    WHERE sql_id = '&&sql_id'
PROMPT      AND ROWNUM = 1;
PROMPT   SYS.DBMS_SQLDIAG_INTERNAL.I_CREATE_PATCH(
PROMPT     sql_text  => l_sql_text,
PROMPT     hint_text => '&&hint_text',
PROMPT     name      => 'GUINA_PATCH_&&sql_id');
PROMPT   DBMS_OUTPUT.PUT_LINE('SQL Patch criado: GUINA_PATCH_&&sql_id');
PROMPT END;
PROMPT /
PROMPT SET SERVEROUTPUT OFF
PROMPT COL name     FORMAT a35 HEADING 'PATCH|-'    JUSTIFY CENTER
PROMPT COL status   FORMAT a10 HEADING 'STATUS|-'   JUSTIFY CENTER
PROMPT COL category FORMAT a12 HEADING 'CATEGORY|-' JUSTIFY CENTER
PROMPT COL created  FORMAT a20 HEADING 'CRIADO|EM'  JUSTIFY CENTER
PROMPT SELECT name, status, category, TO_CHAR(created, 'DD/MM/YY HH24:MI:SS') created
PROMPT   FROM dba_sql_patches
PROMPT  WHERE name = 'GUINA_PATCH_&&sql_id';
PROMPT SET ECHO OFF
PROMPT SPOOL OFF
PROMPT PROMPT
PROMPT PROMPT Confira acima se o patch foi criado. O cursor atual e invalidado: aguarde a proxima execucao do SQL e rode:
PROMPT PROMPT   SELECT inst_id, child_number, sql_patch FROM gv$sql WHERE sql_id = '&&sql_id';
PROMPT PROMPT   SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR('&&sql_id', <child>, 'ALLSTATS LAST'));
PROMPT PROMPT Depois de coletar: @&&arq_base._drop.sql
SPOOL OFF

SPOOL &&arq_base._drop.sql
PROMPT -- +--- gerado por coe_sql_patch_11g.sql. Remove o SQL Patch do SQL_ID &&sql_id
PROMPT -- +--- requer o privilegio DROP ANY SQL PATCH
PROMPT SET ECHO ON
PROMPT SPOOL &&arq_base._drop.out
PROMPT BEGIN
PROMPT   SYS.DBMS_SQLDIAG.DROP_SQL_PATCH(name => 'GUINA_PATCH_&&sql_id');
PROMPT END;
PROMPT /
PROMPT SELECT COUNT(*) patches_restantes FROM dba_sql_patches WHERE name = 'GUINA_PATCH_&&sql_id';
PROMPT SET ECHO OFF
PROMPT SPOOL OFF
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
