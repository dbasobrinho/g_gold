-- |
-- +-------------------------------------------------------------------------------------------+
-- | Objetivo   : Gera o script de ROLES (S/I/U/D/E) e DDL por schema para um usuario          |
-- | Criador    : Roberto Fernandes Sobrinho                                                   |
-- | Data       : 11/09/2026                                                                   |
-- | Exemplo    : @gera_grants_role_por_schema_para_user.sql ANDRE_SANTOS FATP,FAT,RSE,TRSE    |
-- | Arquivo    : gera_grants_role_por_schema_para_user.sql                                    |
-- | Referncia  : Roles R_<SCHEMA>_#S/#I/#U/#D/#E = SELECT/INSERT/UPDATE/DELETE/EXECUTE        |
-- | Modificacao: 1.0 - 11/09/2026 - rfsobrinho - Versao inicial                               |
-- |              1.1 - 11/09/2026 - rfsobrinho - Valida parametros e aborta antes de gerar    |
-- |              1.2 - 11/09/2026 - rfsobrinho - Saida so com comandos, spool com data/hora   |
-- |              1.3 - 11/09/2026 - rfsobrinho - Pula view sem GRANT OPTION, nome oficial     |
-- +-------------------------------------------------------------------------------------------+
-- |                                                                https://dbasobrinho.com.br |
-- +-------------------------------------------------------------------------------------------+
-- |"Grant sem revisao e igual pastel de vento: parece cheio, mas nao tem nada dentro!"
-- +-------------------------------------------------------------------------------------------+
--> Este script SOMENTE GERA o arquivo grants_<USUARIO>_<BANCO>_<AAAAMMDD_HHMISS>.sql.
--> Nenhum GRANT e executado aqui. O arquivo gerado tem so os comandos de execucao.
--> Revise o arquivo gerado e execute manualmente com @, conectado com usuario DBA
--> (precisa de CREATE ROLE e GRANT ANY OBJECT PRIVILEGE; no 23ai+, GRANT ANY SCHEMA PRIVILEGE).
--> Parametro 1 = usuario que recebe os acessos | Parametro 2 = schemas separados por virgula
-- +-------------------------------------------------------------------------------------------+
SET VERIFY OFF;
DEFINE p_usuario = '&1'
DEFINE p_schemas = '&2'
SET TERMOUT OFF;
SET SQLBLANKLINES ON;
EXEC dbms_application_info.set_module( module_name => 'gera_grants_role_por_schema_para_user', action_name => 'GERADOR');
COLUMN current_instance NEW_VALUE current_instance NOPRINT;
COLUMN v_usuario        NEW_VALUE v_usuario        NOPRINT;
COLUMN v_schemas        NEW_VALUE v_schemas        NOPRINT;
COLUMN v_regexp         NEW_VALUE v_regexp         NOPRINT;
COLUMN v_db             NEW_VALUE v_db             NOPRINT;
COLUMN v_guarda         NEW_VALUE v_guarda         NOPRINT;
COLUMN v_data           NEW_VALUE v_data           NOPRINT;
COLUMN v_ts             NEW_VALUE v_ts             NOPRINT;
COLUMN v_major          NEW_VALUE v_major          NOPRINT;
SELECT RPAD(SYS_CONTEXT('USERENV','INSTANCE_NAME'),17)                                  AS current_instance,
       UPPER(TRIM('&p_usuario'))                                                        AS v_usuario,
       UPPER(REPLACE('&p_schemas',' ',''))                                              AS v_schemas,
       '^R_(' || UPPER(REPLACE(REPLACE('&p_schemas',' ',''),',','|')) || ')_#[SIUDE]$'  AS v_regexp,
       UPPER(SYS_CONTEXT('USERENV','DB_NAME'))                                          AS v_db,
       UPPER(SYS_CONTEXT('USERENV','DB_UNIQUE_NAME') || '/' ||
             SYS_CONTEXT('USERENV','CON_NAME'))                                         AS v_guarda,
       TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS')                                         AS v_data,
       TO_CHAR(SYSDATE,'YYYYMMDD_HH24MISS')                                             AS v_ts
FROM   dual;
SELECT TO_NUMBER(REGEXP_SUBSTR(version,'^[0-9]+')) AS v_major FROM v$instance;
SET TERMOUT ON;
CLEAR BREAKS
CLEAR COMPUTES
SET FEEDBACK ON
SET HEADING ON
SET LINESIZE 220
SET PAGESIZE 200
SET TRIMSPOOL ON
SET COLSEP '|'
SET HEADSEP '|'
SPOOL gera_grants_role_por_schema_para_user_&v_ts..out
PROMPT
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | https://github.com/dbasobrinho/g_gold/blob/main/gera_grants_role_por_schema_para_user.sql |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | Script   : Gera ROLES e DDL por schema                           +-+-+-+-+-+-+-+-+-+-+-+  |
PROMPT | Instancia: &current_instance                                     |d|b|a|s|o|b|r|i|n|h|o|  |
PROMPT | Versao   : 1.3                                                   +-+-+-+-+-+-+-+-+-+-+-+  |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | Param 1  : &p_usuario
PROMPT | Param 2  : &p_schemas
PROMPT | Usuario  : &v_usuario
PROMPT | Schemas  : &v_schemas
PROMPT | Banco    : &v_guarda (Oracle &v_major)
PROMPT | Arquivo  : grants_&v_usuario._&v_db._&v_ts..sql
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT
SET ECHO ON
PROMPT
PROMPT +-- [0] Validacao dos parametros (se falhar, aborta aqui e NAO gera nada)
WHENEVER SQLERROR EXIT SQL.SQLCODE
DECLARE
  v_usr VARCHAR2(200)  := '&v_usuario';
  v_sch VARCHAR2(4000) := '&v_schemas';
  v_qtd NUMBER;
BEGIN
  IF v_usr IS NULL THEN
    RAISE_APPLICATION_ERROR(-20001, 'Parametro 1 (usuario) vazio');
  END IF;
  IF v_sch IS NULL THEN
    RAISE_APPLICATION_ERROR(-20002, 'Parametro 2 (schemas) vazio');
  END IF;
  SELECT COUNT(*) INTO v_qtd FROM dba_users WHERE username = v_usr;
  IF v_qtd = 0 THEN
    RAISE_APPLICATION_ERROR(-20003, 'Usuario ' || v_usr || ' nao existe neste banco');
  END IF;
  IF INSTR(',' || v_sch || ',', ',' || v_usr || ',') > 0 THEN
    RAISE_APPLICATION_ERROR(-20004, 'Usuario ' || v_usr || ' esta na lista de schemas [' || v_sch || ']. Confira o parametro 2');
  END IF;
  FOR r IN (SELECT TRIM(REGEXP_SUBSTR(v_sch, '[^,]+', 1, LEVEL)) AS s
            FROM   dual
            CONNECT BY REGEXP_SUBSTR(v_sch, '[^,]+', 1, LEVEL) IS NOT NULL) LOOP
    SELECT COUNT(*) INTO v_qtd FROM dba_users WHERE username = r.s;
    IF v_qtd = 0 THEN
      RAISE_APPLICATION_ERROR(-20005, 'Schema ' || r.s || ' nao existe neste banco');
    END IF;
  END LOOP;
END;
/
WHENEVER SQLERROR CONTINUE
PROMPT
PROMPT +-- [1] Usuario que recebe os acessos
COL username           FORMAT A25 HEADING 'USUARIO|-'            JUSTIFY CENTER
COL account_status     FORMAT A20 HEADING 'STATUS|-'             JUSTIFY CENTER
COL default_tablespace FORMAT A20 HEADING 'TABLESPACE|DEFAULT'   JUSTIFY CENTER
COL profile            FORMAT A20 HEADING 'PROFILE|-'            JUSTIFY CENTER
COL criado             FORMAT A10 HEADING 'CRIADO|EM'            JUSTIFY CENTER
SELECT u.username,
       u.account_status,
       u.default_tablespace,
       u.profile,
       TO_CHAR(u.created,'DD/MM/YYYY') AS criado
FROM   dba_users u
WHERE  u.username = '&v_usuario';
PROMPT
PROMPT +-- [2] Schemas da solicitacao (EXISTE = NAO nao gera nada para o schema)
COL owner       FORMAT A15   HEADING 'SCHEMA|-'      JUSTIFY CENTER
COL existe      FORMAT A6    HEADING 'EXISTE|-'      JUSTIFY CENTER
COL status_sch  FORMAT A20   HEADING 'STATUS|SCHEMA' JUSTIFY CENTER
COL tabelas     FORMAT 99999 HEADING 'QTD|TABELAS'   JUSTIFY CENTER
COL views       FORMAT 99999 HEADING 'QTD|VIEWS'     JUSTIFY CENTER
COL sequences   FORMAT 99999 HEADING 'QTD|SEQUENCES' JUSTIFY CENTER
COL codigo      FORMAT 99999 HEADING 'QTD|CODIGO'    JUSTIFY CENTER
WITH sch AS (
  SELECT UPPER(TRIM(REGEXP_SUBSTR('&v_schemas','[^,]+',1,LEVEL))) AS owner, LEVEL AS pos
  FROM   dual
  CONNECT BY REGEXP_SUBSTR('&v_schemas','[^,]+',1,LEVEL) IS NOT NULL
)
SELECT sch.owner,
       NVL2(u.username,'SIM','NAO')                                             AS existe,
       u.account_status                                                         AS status_sch,
       (SELECT COUNT(*) FROM dba_tables t    WHERE t.owner = sch.owner)          AS tabelas,
       (SELECT COUNT(*) FROM dba_views v     WHERE v.owner = sch.owner)          AS views,
       (SELECT COUNT(*) FROM dba_sequences q WHERE q.sequence_owner = sch.owner) AS sequences,
       (SELECT COUNT(*) FROM dba_objects o   WHERE o.owner = sch.owner
                                               AND o.object_type IN ('PACKAGE','PROCEDURE','FUNCTION','TYPE')) AS codigo
FROM   sch
LEFT JOIN dba_users u ON u.username = sch.owner
ORDER BY sch.pos;
PROMPT
PROMPT +-- [3] Roles do padrao que ja existem no banco (nao serao recriadas)
COL role FORMAT A30 HEADING 'ROLE|-' JUSTIFY CENTER
SELECT r.role
FROM   dba_roles r
WHERE  REGEXP_LIKE(r.role,'&v_regexp')
ORDER BY r.role;
PROMPT
PROMPT +-- [4] Roles que o usuario ja possui hoje
COL granted_role FORMAT A30 HEADING 'ROLE|-'         JUSTIFY CENTER
COL admin_option FORMAT A6  HEADING 'ADMIN|OPTION'   JUSTIFY CENTER
COL default_role FORMAT A7  HEADING 'DEFAULT|ROLE'   JUSTIFY CENTER
SELECT p.granted_role,
       p.admin_option,
       p.default_role
FROM   dba_role_privs p
WHERE  p.grantee = '&v_usuario'
ORDER BY p.granted_role;
PROMPT
PROMPT +-- [5] Privilegios de sistema diretos do usuario hoje
COL privilege FORMAT A40 HEADING 'PRIVILEGIO|-' JUSTIFY CENTER
SELECT s.privilege,
       s.admin_option
FROM   dba_sys_privs s
WHERE  s.grantee = '&v_usuario'
ORDER BY s.privilege;
PROMPT
PROMPT +-- [6] Grants em view que serao PULADOS: sem GRANT OPTION no objeto base (ORA-01720), view invalida ou DB link inexistente
COL v_owner  FORMAT A10 HEADING 'SCHEMA|VIEW'      JUSTIFY CENTER
COL v_name   FORMAT A30 HEADING 'VIEW|-'           JUSTIFY CENTER
COL p        FORMAT A7  HEADING 'GRANT|PULADO'     JUSTIFY CENTER
COL objeto   FORMAT A45 HEADING 'OBJETO|OUTRO SCHEMA' JUSTIFY CENTER
COL f_type   FORMAT A10 HEADING 'TIPO|-'           JUSTIFY CENTER
COL req_priv FORMAT A8  HEADING 'FALTA|WGO'        JUSTIFY CENTER
WITH sch AS (
  SELECT UPPER(TRIM(REGEXP_SUBSTR('&v_schemas','[^,]+',1,LEVEL))) AS owner, LEVEL AS pos
  FROM   dual
  CONNECT BY REGEXP_SUBSTR('&v_schemas','[^,]+',1,LEVEL) IS NOT NULL
),
sch_ok AS (
  SELECT sch.owner, sch.pos
  FROM   sch
  JOIN   dba_users u ON u.username = sch.owner
),
dep AS (
  SELECT /*+ MATERIALIZE */
         d.owner, d.name, d.type, d.referenced_owner, d.referenced_name, d.referenced_type
  FROM   dba_dependencies d
  WHERE  (d.owner IN (SELECT owner FROM sch_ok) AND d.type IN ('VIEW','SYNONYM'))
  OR     (d.owner = 'PUBLIC' AND d.type = 'SYNONYM')
),
vdep AS (
  SELECT DISTINCT
         CONNECT_BY_ROOT d.owner AS v_owner,
         CONNECT_BY_ROOT d.name  AS v_name,
         d.referenced_owner      AS f_owner,
         d.referenced_name       AS f_name,
         d.referenced_type       AS f_type
  FROM   dep d
  START WITH d.type = 'VIEW'
  AND    d.owner IN (SELECT owner FROM sch_ok)
  CONNECT BY NOCYCLE
         PRIOR d.referenced_owner = d.owner
  AND    PRIOR d.referenced_name  = d.name
  AND    PRIOR d.referenced_type  = d.type
  AND    (   PRIOR d.referenced_type = 'SYNONYM'
          OR (PRIOR d.referenced_type = 'VIEW' AND PRIOR d.referenced_owner = PRIOR d.owner))
),
px AS (
  SELECT 'S' AS s, 'SELECT' AS p FROM dual UNION ALL
  SELECT 'I' AS s, 'INSERT' AS p FROM dual UNION ALL
  SELECT 'U' AS s, 'UPDATE' AS p FROM dual UNION ALL
  SELECT 'D' AS s, 'DELETE' AS p FROM dual
),
vreq AS (
  SELECT v.v_owner, v.v_name, v.f_owner, v.f_name, v.f_type, x.s, x.p,
         CASE WHEN v.f_type IN ('FUNCTION','PROCEDURE','PACKAGE','TYPE') THEN 'EXECUTE' ELSE x.p END AS req_priv
  FROM   vdep v
  CROSS JOIN px x
  WHERE  v.f_owner NOT IN (v.v_owner, 'PUBLIC')
  AND    v.f_type IN ('TABLE','VIEW','MATERIALIZED VIEW','FUNCTION','PROCEDURE','PACKAGE','TYPE')
  AND    NOT (v.f_owner = 'SYS' AND v.f_type IN ('FUNCTION','PROCEDURE','PACKAGE','TYPE'))
),
vfalta AS (
  SELECT r.*
  FROM   vreq r
  WHERE  NOT EXISTS (SELECT 1
                     FROM   dba_tab_privs p
                     WHERE  p.owner      = r.f_owner
                     AND    p.table_name = r.f_name
                     AND    p.privilege  = r.req_priv
                     AND    p.grantable  = 'YES'
                     AND    p.grantee   IN (r.v_owner, 'PUBLIC'))
),
vinv AS (
  SELECT o.owner AS v_owner, o.object_name AS v_name, 'VIEW INVALIDA (' || o.status || ')' AS motivo
  FROM   dba_objects o
  JOIN   sch_ok ON sch_ok.owner = o.owner
  WHERE  o.object_type = 'VIEW'
  AND    o.status <> 'VALID'
  UNION
  SELECT d.owner, d.name, 'DB LINK INEXISTENTE ' || d.referenced_link_name
  FROM   dba_dependencies d
  JOIN   sch_ok ON sch_ok.owner = d.owner
  WHERE  d.type = 'VIEW'
  AND    d.referenced_link_name IS NOT NULL
  AND    NOT EXISTS (SELECT 1
                     FROM   dba_db_links l
                     WHERE  l.owner IN (d.owner, 'PUBLIC')
                     AND    (l.db_link = d.referenced_link_name OR l.db_link LIKE d.referenced_link_name || '.%'))
),
vbad AS (
  SELECT v_owner, v_name, s FROM vfalta
  UNION
  SELECT i.v_owner, i.v_name, x.s FROM vinv i CROSS JOIN px x
)
SELECT v_owner, v_name, p, objeto, f_type, req_priv
FROM  (SELECT f.v_owner, f.v_name, f.p,
              f.f_owner || '.' || f.f_name AS objeto,
              f.f_type, f.req_priv,
              DECODE(f.p,'SELECT',1,'INSERT',2,'UPDATE',3,4) AS ord
       FROM   vfalta f
       UNION ALL
       SELECT i.v_owner, i.v_name, 'TODOS', i.motivo, 'VIEW', '-', 0
       FROM   vinv i)
ORDER BY v_owner, v_name, ord, objeto;
SET ECHO OFF
SPOOL OFF
SET TERMOUT OFF
SET FEEDBACK OFF
SET HEADING OFF
SET PAGESIZE 0
SET LINESIZE 400
SET TRIMSPOOL ON
SET TRIMOUT ON
SET TAB OFF
SET COLSEP ' '
COL txt FORMAT A400
SPOOL grants_&v_usuario._&v_db._&v_ts..sql
WITH sch AS (
  SELECT UPPER(TRIM(REGEXP_SUBSTR('&v_schemas','[^,]+',1,LEVEL))) AS owner, LEVEL AS pos
  FROM   dual
  CONNECT BY REGEXP_SUBSTR('&v_schemas','[^,]+',1,LEVEL) IS NOT NULL
),
sch_ok AS (
  SELECT sch.owner, sch.pos
  FROM   sch
  JOIN   dba_users u ON u.username = sch.owner
),
usr AS (
  SELECT '&v_usuario' AS grantee FROM dual
),
suf AS (
  SELECT 'S' AS s, 1 AS o, 'SELECT'  AS p FROM dual UNION ALL
  SELECT 'I' AS s, 2 AS o, 'INSERT'  AS p FROM dual UNION ALL
  SELECT 'U' AS s, 3 AS o, 'UPDATE'  AS p FROM dual UNION ALL
  SELECT 'D' AS s, 4 AS o, 'DELETE'  AS p FROM dual UNION ALL
  SELECT 'E' AS s, 5 AS o, 'EXECUTE' AS p FROM dual
),
dml AS (
  SELECT 'I' AS s FROM dual UNION ALL
  SELECT 'U' AS s FROM dual UNION ALL
  SELECT 'D' AS s FROM dual
),
ddl AS (
  SELECT 1 AS o, 'CREATE ANY TABLE' AS p FROM dual UNION ALL
  SELECT 2,  'ALTER ANY TABLE'     FROM dual UNION ALL
  SELECT 3,  'DROP ANY TABLE'      FROM dual UNION ALL
  SELECT 4,  'COMMENT ANY TABLE'   FROM dual UNION ALL
  SELECT 5,  'CREATE ANY INDEX'    FROM dual UNION ALL
  SELECT 6,  'ALTER ANY INDEX'     FROM dual UNION ALL
  SELECT 7,  'DROP ANY INDEX'      FROM dual UNION ALL
  SELECT 8,  'CREATE ANY VIEW'     FROM dual UNION ALL
  SELECT 9,  'DROP ANY VIEW'       FROM dual UNION ALL
  SELECT 10, 'CREATE ANY SEQUENCE' FROM dual UNION ALL
  SELECT 11, 'ALTER ANY SEQUENCE'  FROM dual UNION ALL
  SELECT 12, 'DROP ANY SEQUENCE'   FROM dual UNION ALL
  SELECT 13, 'CREATE ANY PROCEDURE' FROM dual UNION ALL
  SELECT 14, 'ALTER ANY PROCEDURE' FROM dual UNION ALL
  SELECT 15, 'DROP ANY PROCEDURE'  FROM dual UNION ALL
  SELECT 16, 'CREATE ANY TRIGGER'  FROM dual UNION ALL
  SELECT 17, 'ALTER ANY TRIGGER'   FROM dual UNION ALL
  SELECT 18, 'DROP ANY TRIGGER'    FROM dual UNION ALL
  SELECT 19, 'CREATE ANY SYNONYM'  FROM dual UNION ALL
  SELECT 20, 'DROP ANY SYNONYM'    FROM dual
),
tab_all AS (
  SELECT t.owner, t.table_name AS obj
  FROM   dba_tables t
  JOIN   sch_ok ON sch_ok.owner = t.owner
  WHERE  NVL(t.dropped,'NO')     = 'NO'
  AND    NVL(t.nested,'NO')      = 'NO'
  AND    NVL(t.secondary,'N')    = 'N'
  AND    NVL(t.iot_type,'X')    <> 'IOT_OVERFLOW'
  AND    t.table_name NOT LIKE 'BIN$%'
),
tab_dml AS (
  SELECT a.owner, a.obj
  FROM   tab_all a
  WHERE  a.obj NOT LIKE 'MLOG$%'
  AND    a.obj NOT LIKE 'RUPD$%'
  AND    NOT EXISTS (SELECT 1 FROM dba_external_tables e WHERE e.owner = a.owner AND e.table_name = a.obj)
  AND    NOT EXISTS (SELECT 1 FROM dba_mviews m          WHERE m.owner = a.owner AND m.mview_name = a.obj)
),
vw AS (
  SELECT v.owner, v.view_name AS obj
  FROM   dba_views v
  JOIN   sch_ok ON sch_ok.owner = v.owner
),
sq AS (
  SELECT q.sequence_owner AS owner, q.sequence_name AS obj
  FROM   dba_sequences q
  JOIN   sch_ok ON sch_ok.owner = q.sequence_owner
  WHERE  q.sequence_name NOT LIKE 'ISEQ$$%'
),
cod AS (
  SELECT o.owner, o.object_name AS obj
  FROM   dba_objects o
  JOIN   sch_ok ON sch_ok.owner = o.owner
  WHERE  o.object_type IN ('PACKAGE','PROCEDURE','FUNCTION','TYPE')
  AND    o.generated = 'N'
  AND    o.object_name NOT LIKE 'SYS_PLSQL%'
),
dep AS (
  SELECT /*+ MATERIALIZE */
         d.owner, d.name, d.type, d.referenced_owner, d.referenced_name, d.referenced_type
  FROM   dba_dependencies d
  WHERE  (d.owner IN (SELECT owner FROM sch_ok) AND d.type IN ('VIEW','SYNONYM'))
  OR     (d.owner = 'PUBLIC' AND d.type = 'SYNONYM')
),
vdep AS (
  SELECT DISTINCT
         CONNECT_BY_ROOT d.owner AS v_owner,
         CONNECT_BY_ROOT d.name  AS v_name,
         d.referenced_owner      AS f_owner,
         d.referenced_name       AS f_name,
         d.referenced_type       AS f_type
  FROM   dep d
  START WITH d.type = 'VIEW'
  AND    d.owner IN (SELECT owner FROM sch_ok)
  CONNECT BY NOCYCLE
         PRIOR d.referenced_owner = d.owner
  AND    PRIOR d.referenced_name  = d.name
  AND    PRIOR d.referenced_type  = d.type
  AND    (   PRIOR d.referenced_type = 'SYNONYM'
          OR (PRIOR d.referenced_type = 'VIEW' AND PRIOR d.referenced_owner = PRIOR d.owner))
),
px AS (
  SELECT 'S' AS s, 'SELECT' AS p FROM dual UNION ALL
  SELECT 'I' AS s, 'INSERT' AS p FROM dual UNION ALL
  SELECT 'U' AS s, 'UPDATE' AS p FROM dual UNION ALL
  SELECT 'D' AS s, 'DELETE' AS p FROM dual
),
vreq AS (
  SELECT v.v_owner, v.v_name, v.f_owner, v.f_name, v.f_type, x.s, x.p,
         CASE WHEN v.f_type IN ('FUNCTION','PROCEDURE','PACKAGE','TYPE') THEN 'EXECUTE' ELSE x.p END AS req_priv
  FROM   vdep v
  CROSS JOIN px x
  WHERE  v.f_owner NOT IN (v.v_owner, 'PUBLIC')
  AND    v.f_type IN ('TABLE','VIEW','MATERIALIZED VIEW','FUNCTION','PROCEDURE','PACKAGE','TYPE')
  AND    NOT (v.f_owner = 'SYS' AND v.f_type IN ('FUNCTION','PROCEDURE','PACKAGE','TYPE'))
),
vfalta AS (
  SELECT r.*
  FROM   vreq r
  WHERE  NOT EXISTS (SELECT 1
                     FROM   dba_tab_privs p
                     WHERE  p.owner      = r.f_owner
                     AND    p.table_name = r.f_name
                     AND    p.privilege  = r.req_priv
                     AND    p.grantable  = 'YES'
                     AND    p.grantee   IN (r.v_owner, 'PUBLIC'))
),
vinv AS (
  SELECT o.owner AS v_owner, o.object_name AS v_name, 'VIEW INVALIDA (' || o.status || ')' AS motivo
  FROM   dba_objects o
  JOIN   sch_ok ON sch_ok.owner = o.owner
  WHERE  o.object_type = 'VIEW'
  AND    o.status <> 'VALID'
  UNION
  SELECT d.owner, d.name, 'DB LINK INEXISTENTE ' || d.referenced_link_name
  FROM   dba_dependencies d
  JOIN   sch_ok ON sch_ok.owner = d.owner
  WHERE  d.type = 'VIEW'
  AND    d.referenced_link_name IS NOT NULL
  AND    NOT EXISTS (SELECT 1
                     FROM   dba_db_links l
                     WHERE  l.owner IN (d.owner, 'PUBLIC')
                     AND    (l.db_link = d.referenced_link_name OR l.db_link LIKE d.referenced_link_name || '.%'))
),
vbad AS (
  SELECT v_owner, v_name, s FROM vfalta
  UNION
  SELECT i.v_owner, i.v_name, x.s FROM vinv i CROSS JOIN px x
),
g AS (
  SELECT owner, obj, 'S' AS s FROM tab_all
  UNION ALL
  SELECT v.owner, v.obj, 'S' AS s FROM vw v
  WHERE  NOT EXISTS (SELECT 1 FROM vbad b WHERE b.v_owner = v.owner AND b.v_name = v.obj AND b.s = 'S')
  UNION ALL
  SELECT owner, obj, 'S' AS s FROM sq
  UNION ALL
  SELECT t.owner, t.obj, d.s FROM tab_dml t CROSS JOIN dml d
  UNION ALL
  SELECT v.owner, v.obj, d.s FROM vw v CROSS JOIN dml d
  WHERE  NOT EXISTS (SELECT 1 FROM vbad b WHERE b.v_owner = v.owner AND b.v_name = v.obj AND b.s = d.s)
  UNION ALL
  SELECT owner, obj, 'E' AS s FROM cod
),
cab AS (
  SELECT 1 AS sub, 'SET ECHO OFF' AS txt FROM dual UNION ALL
  SELECT 2, 'SET FEEDBACK OFF' FROM dual UNION ALL
  SELECT 3, 'SET VERIFY OFF' FROM dual UNION ALL
  SELECT 4, 'COLUMN v_ts NEW_VALUE v_ts NOPRINT' FROM dual UNION ALL
  SELECT 5, 'SELECT TO_CHAR(SYSDATE,''YYYYMMDD_HH24MISS'') AS v_ts FROM dual;' FROM dual UNION ALL
  SELECT 6, 'SPOOL grants_&v_usuario._&v_db._exec_' || CHR(38) || 'v_ts..out' FROM dual UNION ALL
  SELECT 7, 'SET ECHO ON' FROM dual UNION ALL
  SELECT 8, 'SET FEEDBACK ON' FROM dual
),
lin AS (
  SELECT 0 AS pos, 0 AS sec, c.sub, CAST(NULL AS VARCHAR2(128)) AS nm, c.txt FROM cab c
  UNION ALL
  SELECT 99999, 9, 1, NULL, 'SPOOL OFF' FROM dual
  UNION ALL
  SELECT s.pos, 1, f.o, NULL, 'CREATE ROLE R_' || s.owner || '_#' || f.s || ';'
  FROM   sch_ok s
  CROSS JOIN suf f
  WHERE  NOT EXISTS (SELECT 1 FROM dba_roles r WHERE r.role = 'R_' || s.owner || '_#' || f.s)
  UNION ALL
  SELECT s.pos, 2, f.o, g.obj,
         'GRANT ' || f.p || ' ON ' || g.owner || '.' ||
         CASE WHEN REGEXP_LIKE(g.obj,'^[A-Z][A-Z0-9_$#]*$') THEN g.obj ELSE '"' || g.obj || '"' END ||
         ' TO R_' || g.owner || '_#' || g.s || ';'
  FROM   g
  JOIN   sch_ok s ON s.owner = g.owner
  JOIN   suf f    ON f.s     = g.s
  UNION ALL
  SELECT s.pos, 3, f.o, NULL, 'GRANT R_' || s.owner || '_#' || f.s || ' TO ' || u.grantee || ';'
  FROM   sch_ok s
  CROSS JOIN suf f
  CROSS JOIN usr u
  UNION ALL
  SELECT s.pos, 4, d.o, NULL, 'GRANT ' || d.p || ' ON SCHEMA ' || s.owner || ' TO ' || u.grantee || ';'
  FROM   sch_ok s
  CROSS JOIN ddl d
  CROSS JOIN usr u
  WHERE  &v_major >= 23
)
SELECT txt
FROM   lin
ORDER BY pos, sec, sub, nm NULLS FIRST;
SPOOL OFF
SET TERMOUT ON
SET ECHO ON
SET HEADING ON
SET FEEDBACK ON
SET PAGESIZE 200
SET LINESIZE 220
SET COLSEP '|'
PROMPT
PROMPT +-- [7] Arquivo gerado: grants_&v_usuario._&v_db._&v_ts..sql
PROMPT +-- Diagnostico: gera_grants_role_por_schema_para_user_&v_ts..out
PROMPT +-- DDL: Oracle &v_major. Antes do 23ai nao existe privilegio por schema, DDL fica fora do arquivo
PROMPT Revise o arquivo e execute manualmente: @grants_&v_usuario._&v_db._&v_ts..sql
SET ECHO OFF
