-- |
-- +--------------------------------------------------------------------------------------------+
-- | Objetivo   : Copiar todos os acessos de um usuario de origem para um usuario destino       |
-- |              roles, privilegios de sistema, objeto e coluna, roles default,                |
-- |              quotas em tablespace e grants de proxy (CONNECT THROUGH)                      |
-- | Criador    : Roberto Fernandes Sobrinho                                                    |
-- | Data       : 01/09/2026                                                                    |
-- | Exemplo    : @copy_user.sql                                                                |
-- | Arquivo    : copy_user.sql                                                                 |
-- | Referncia  : https://dbasobrinho.com.br/configurando-proxy-user-e-connect-through-em       |
-- |              -ambientes-oracle/                                                            |
-- | Modificacao: 1.0 - 01/09/2026 - rfsobrinho - Versao inicial, unifica users_copy.sql,       |
-- |                                              copy_user_pl.sql e copy_user_pl_tudao.sql     |
-- |              1.1 - 01/09/2026 - rfsobrinho - Ignora objetos da recyclebin (BIN$...)        |
-- +--------------------------------------------------------------------------------------------+
-- | Saida      : <ORIGEM>_TO_<DESTINO>_YYYYMMDD_HH24MISS.sql pronto para execucao              |
-- |              Sem origem ou destino nada e gerado nem executado, a saida vai para           |
-- |              copy_user_PARAMETRO_FALTANDO_<data>.log                                       |
-- | Ambiente   : Banco PRIMARIO, sessao SQL*Plus como SYS ou DBA, conectado no container       |
-- |              (PDB) onde os usuarios existem                                                |
-- | Versoes    : Sintaxe compativel de 11.2 a 23ai                                             |
-- | Atencao    : Este script NUNCA executa DDL. Ele apenas GERA o arquivo .sql. A execucao     |
-- |              e sempre manual, pelo DBA, apos revisar o conteudo gerado                     |
-- |              ECHO fica OFF de proposito, o eco das linhas invalidaria o arquivo gerado     |
-- |              Senha com o caractere & exige SET DEFINE OFF antes, ou use KEEP               |
-- +--------------------------------------------------------------------------------------------+
-- |                                                                 https://dbasobrinho.com.br |
-- +--------------------------------------------------------------------------------------------+
-- |"Privilegio copiado no grito vira ORA-01031 no pior horario."
-- +--------------------------------------------------------------------------------------------+

SET ECHO         OFF
SET FEEDBACK     OFF
SET HEADING      OFF
SET VERIFY       OFF
SET TRIMOUT      ON
SET TRIMSPOOL    ON
SET LINESIZE     4000
SET PAGESIZE     0
SET COLSEP       '|'
SET DEFINE       ON
SET SQLBLANKLINES ON
SET SERVEROUTPUT ON SIZE UNLIMITED FORMAT WRAPPED

SET TERMOUT OFF;
ALTER SESSION SET NLS_DATE_FORMAT='DD-MON-YY HH24:MI:SS';
EXEC dbms_application_info.set_module( module_name => 'copy_user[copy_user.sql]', action_name => 'copy_user[copy_user.sql]');
COLUMN current_instance NEW_VALUE current_instance NOPRINT;
SELECT rpad(sys_context('USERENV', 'INSTANCE_NAME'), 17) current_instance FROM dual;
COLUMN current_container NEW_VALUE current_container NOPRINT;
SELECT rpad(nvl(sys_context('USERENV','CON_NAME'),'NAO MULTITENANT'), 17) current_container FROM dual;
SET TERMOUT ON;
PROMPT
PROMPT +--------------------------------------------------------------------------------------------+
PROMPT | https://github.com/dbasobrinho/g_gold/blob/main/copy_user.sql                              |
PROMPT +--------------------------------------------------------------------------------------------+
PROMPT | Script   : Copia de acessos entre usuarios                         +-+-+-+-+-+-+-+-+-+-+-+ |
PROMPT | Instancia: &current_instance                                       |d|b|a|s|o|b|r|i|n|h|o| |
PROMPT | Container: &current_container                                      +-+-+-+-+-+-+-+-+-+-+-+ |
PROMPT | Versao   : 1.1                                                                             |
PROMPT +--------------------------------------------------------------------------------------------+
PROMPT | Origem e destino sao obrigatorios. Em branco, nada e gerado.                               |
PROMPT | Este script apenas GERA o .sql. Nada e executado no banco.                                 |
PROMPT +--------------------------------------------------------------------------------------------+
PROMPT

-- Sentinela: se o operador apenas apertar Enter, o valor permanece o de baixo
DEFINE p_src  = "NAO_INFORMADO"
DEFINE p_tgt  = "NAO_INFORMADO"
DEFINE p_pwd  = "NAO_INFORMADO"

ACCEPT p_src  CHAR PROMPT 'USUARIO DE ORIGEM (modelo)                    = '
ACCEPT p_tgt  CHAR PROMPT 'USUARIO DE DESTINO                            = '
ACCEPT p_pwd  CHAR PROMPT 'SENHA DO DESTINO (ou KEEP para copiar o hash) = '

-- ---------------------------------------------------------------------------
-- Monta o nome do arquivo de saida. Origem ou destino ausente derruba o nome
-- para .log, deixando claro que nada foi gerado.
-- ---------------------------------------------------------------------------
SET TERMOUT OFF

COLUMN c_ts   NEW_VALUE v_ts   NOPRINT
COLUMN c_arq  NEW_VALUE v_arq  NOPRINT
COLUMN c_base NEW_VALUE v_base NOPRINT

SELECT TO_CHAR(SYSDATE,'YYYYMMDD_HH24MISS') AS c_ts FROM dual;

SELECT CASE
         WHEN TRIM('&p_src') IS NULL
           OR TRIM('&p_tgt') IS NULL
           OR UPPER(TRIM('&p_src')) = 'NAO_INFORMADO'
           OR UPPER(TRIM('&p_tgt')) = 'NAO_INFORMADO'
         THEN 'copy_user_PARAMETRO_FALTANDO'
         ELSE UPPER(TRIM('&p_src')) || '_TO_' || UPPER(TRIM('&p_tgt'))
       END AS c_base
  FROM dual;

SELECT '&v_base' || '_' || '&v_ts' ||
       CASE WHEN '&v_base' = 'copy_user_PARAMETRO_FALTANDO' THEN '.log' ELSE '.sql' END AS c_arq
  FROM dual;

SET TERMOUT ON

PROMPT
PROMPT Gerando arquivo: &v_arq
PROMPT

SPOOL &v_arq

DECLARE

  c_src   CONSTANT VARCHAR2(128) := UPPER(TRIM('&p_src'));
  c_tgt   CONSTANT VARCHAR2(128) := UPPER(TRIM('&p_tgt'));
  c_pwd   CONSTANT VARCHAR2(256) := TRIM('&p_pwd');
  c_ts    CONSTANT VARCHAR2(30)  := '&v_ts';
  c_base  CONSTANT VARCHAR2(300) := '&v_base';

  v_ger   PLS_INTEGER := 0;
  v_lix   PLS_INTEGER := 0;
  v_n     PLS_INTEGER;
  v_tot   PLS_INTEGER;
  v_def   PLS_INTEGER;
  v_expira BOOLEAN := FALSE;
  v_lista VARCHAR2(30000);
  v_stmt  VARCHAR2(32000);
  v_obj   VARCHAR2(600);
  v_opt   VARCHAR2(80);

  e_parametro EXCEPTION;

  -- --------------------------------------------------------------------------
  PROCEDURE nota (p_txt IN VARCHAR2) IS
  BEGIN
    DBMS_OUTPUT.PUT_LINE(p_txt);
  END nota;

  -- --------------------------------------------------------------------------
  -- Nome de objeto entre aspas, para suportar minuscula ou caractere especial
  -- --------------------------------------------------------------------------
  FUNCTION q (p_nome IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    RETURN '"' || p_nome || '"';
  END q;

  -- --------------------------------------------------------------------------
  -- Apenas escreve o comando no arquivo gerado. Nada e executado aqui.
  -- --------------------------------------------------------------------------
  PROCEDURE roda (p_stmt IN VARCHAR2) IS
  BEGIN
    DBMS_OUTPUT.PUT_LINE(p_stmt || ';');
    v_ger := v_ger + 1;
  END roda;

  -- --------------------------------------------------------------------------
  FUNCTION clausula_senha RETURN VARCHAR2 IS
    v_ddl CLOB;
    v_val VARCHAR2(4000);
  BEGIN
    IF c_pwd IS NULL OR UPPER(c_pwd) = 'NAO_INFORMADO' THEN
      v_expira := TRUE;
      nota('-- AVISO: senha nao informada. Aplicada senha provisoria com PASSWORD EXPIRE.');
      RETURN 'IDENTIFIED BY "Troc@r#2026"';
    END IF;

    IF UPPER(c_pwd) <> 'KEEP' THEN
      RETURN 'IDENTIFIED BY "' || c_pwd || '"';
    END IF;

    DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'SQLTERMINATOR',FALSE);
    v_ddl := DBMS_METADATA.GET_DDL('USER', c_src);
    v_val := REGEXP_SUBSTR(SUBSTR(v_ddl,1,4000), 'IDENTIFIED BY VALUES ''[^'']+''');

    IF v_val IS NULL THEN
      v_expira := TRUE;
      nota('-- AVISO: nao foi possivel extrair o hash da origem. Senha provisoria aplicada.');
      RETURN 'IDENTIFIED BY "Troc@r#2026"';
    END IF;

    nota('-- AVISO: hash copiado da origem. Em banco com hash 10G (DES) o hash depende');
    nota('--        do nome do usuario e a senha antiga NAO vai funcionar no destino.');
    RETURN v_val;
  EXCEPTION
    WHEN OTHERS THEN
      v_expira := TRUE;
      nota('-- AVISO: DBMS_METADATA indisponivel (' || SUBSTR(SQLERRM,1,120) || ').');
      nota('--        Senha provisoria aplicada.');
      RETURN 'IDENTIFIED BY "Troc@r#2026"';
  END clausula_senha;

BEGIN

  -- ==========================================================================
  -- Trava de parametro: sem origem e destino, nada acontece
  -- ==========================================================================
  IF c_base = 'copy_user_PARAMETRO_FALTANDO' THEN
    nota('===========================================================================');
    nota(' EXECUCAO CANCELADA');
    nota('===========================================================================');
    nota(' Usuario de origem informado : ' || NVL(c_src,'(vazio)'));
    nota(' Usuario de destino informado: ' || NVL(c_tgt,'(vazio)'));
    nota(' ');
    nota(' Os dois sao obrigatorios. Nenhum comando foi gerado nem executado.');
    nota(' Rode novamente informando origem e destino.');
    nota('===========================================================================');
    RAISE e_parametro;
  END IF;

  IF c_src = c_tgt THEN
    nota('-- EXECUCAO CANCELADA: origem e destino sao o mesmo usuario.');
    RAISE e_parametro;
  END IF;

  SELECT COUNT(*) INTO v_n FROM dba_users WHERE username = c_src;
  IF v_n = 0 THEN
    nota('-- EXECUCAO CANCELADA: usuario de origem ' || c_src ||
         ' nao existe neste container.');
    RAISE e_parametro;
  END IF;

  -- ==========================================================================
  -- Cabecalho do arquivo gerado
  -- ==========================================================================
  nota('-- ===========================================================================');
  nota('-- Script    : ' || c_base || '_' || c_ts || '.sql');
  nota('-- Objetivo  : Copiar os acessos de ' || c_src || ' para ' || c_tgt);
  nota('-- Gerado por: copy_user.sql em ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS'));
  nota('-- Banco     : ' || SYS_CONTEXT('USERENV','DB_NAME') ||
       '   Instancia: ' || SYS_CONTEXT('USERENV','INSTANCE_NAME'));
  nota('-- Container : ' || NVL(SYS_CONTEXT('USERENV','CON_NAME'),'NAO MULTITENANT'));
  nota('-- Gerado na sessao de: ' || SYS_CONTEXT('USERENV','SESSION_USER'));
  nota('-- Ambiente  : Executar no banco PRIMARIO, sessao SQL*Plus como SYS ou DBA,');
  nota('--             conectado no mesmo container em que foi gerado.');
  nota('-- Atencao   : arquivo apenas GERADO. Revise e execute manualmente.');
  nota('-- ===========================================================================');
  nota(' ');
  nota('SET ECHO ON');
  nota('SET FEEDBACK 6');
  nota('SET LINESIZE 200');
  nota('SET PAGESIZE 100');
  nota('SET COLSEP ''|''');
  nota('SPOOL ' || c_base || '_' || c_ts || '.out');
  nota(' ');

  IF NVL(SYS_CONTEXT('USERENV','CON_NAME'),'X') = 'CDB$ROOT'
     AND c_tgt NOT LIKE 'C##%' THEN
    nota('-- AVISO: sessao no CDB$ROOT. Usuario comum precisa do prefixo C##.');
    nota('--        Se a intencao e criar usuario local, conecte na PDB correta.');
    nota(' ');
  END IF;

  -- ==========================================================================
  -- 1. Criacao do usuario de destino
  -- ==========================================================================
  nota('-- ---- 1. Usuario ---------------------------------------------------------');

  SELECT COUNT(*) INTO v_n FROM dba_users WHERE username = c_tgt;

  IF v_n > 0 THEN
    nota('-- Usuario ' || c_tgt || ' ja existe. Criacao ignorada, acessos acrescentados.');
  ELSE
    FOR r IN (SELECT default_tablespace, temporary_tablespace, profile, account_status
                FROM dba_users
               WHERE username = c_src)
    LOOP
      v_stmt := 'CREATE USER ' || q(c_tgt) || ' ' || clausula_senha ||
                ' DEFAULT TABLESPACE '   || q(r.default_tablespace) ||
                ' TEMPORARY TABLESPACE ' || q(r.temporary_tablespace) ||
                ' PROFILE '              || q(r.profile);
      roda(v_stmt);

      IF v_expira THEN
        roda('ALTER USER ' || q(c_tgt) || ' PASSWORD EXPIRE');
      END IF;

      IF r.account_status LIKE 'LOCKED%' THEN
        nota('-- Origem esta com a conta bloqueada. Se quiser o mesmo no destino:');
        nota('-- ALTER USER ' || q(c_tgt) || ' ACCOUNT LOCK;');
      END IF;
    END LOOP;
  END IF;
  nota(' ');

  -- ==========================================================================
  -- 2. Roles
  -- ==========================================================================
  nota('-- ---- 2. Roles -----------------------------------------------------------');
  v_n := 0;
  FOR r IN (SELECT granted_role, admin_option
              FROM dba_role_privs
             WHERE grantee = c_src
             ORDER BY granted_role)
  LOOP
    v_stmt := 'GRANT ' || q(r.granted_role) || ' TO ' || q(c_tgt) ||
              CASE WHEN r.admin_option = 'YES' THEN ' WITH ADMIN OPTION' END;
    roda(v_stmt);
    v_n := v_n + 1;
  END LOOP;
  IF v_n = 0 THEN nota('-- Nenhuma role concedida diretamente na origem.'); END IF;
  nota(' ');

  -- ==========================================================================
  -- 3. Privilegios de sistema
  -- ==========================================================================
  nota('-- ---- 3. Privilegios de sistema ------------------------------------------');
  v_n := 0;
  FOR r IN (SELECT privilege, admin_option
              FROM dba_sys_privs
             WHERE grantee = c_src
             ORDER BY privilege)
  LOOP
    v_stmt := 'GRANT ' || r.privilege || ' TO ' || q(c_tgt) ||
              CASE WHEN r.admin_option = 'YES' THEN ' WITH ADMIN OPTION' END;
    roda(v_stmt);
    v_n := v_n + 1;
  END LOOP;
  IF v_n = 0 THEN nota('-- Nenhum privilegio de sistema direto na origem.'); END IF;
  nota(' ');

  -- ==========================================================================
  -- 4. Privilegios de objeto
  --    DIRECTORY, EDITION e MINING MODEL exigem a palavra chave do tipo
  -- ==========================================================================
  nota('-- ---- 4. Privilegios de objeto -------------------------------------------');

  -- Objeto dropado continua na recyclebin com o nome BIN$... e os grants
  -- originais permanecem em DBA_TAB_PRIVS. Copiar isso nao faz sentido.
  SELECT COUNT(*)
    INTO v_lix
    FROM dba_tab_privs tp
   WHERE tp.grantee = c_src
     AND (tp.table_name LIKE 'BIN$%'
          OR EXISTS (SELECT 1 FROM dba_recyclebin rb
                      WHERE rb.owner       = tp.owner
                        AND rb.object_name = tp.table_name));

  IF v_lix > 0 THEN
    nota('-- ' || v_lix || ' privilegio(s) sobre objeto da recyclebin ignorado(s).');
  END IF;

  v_n := 0;
  FOR r IN (SELECT tp.privilege,
                   tp.owner,
                   tp.table_name,
                   tp.grantable,
                   tp.hierarchy,
                   (SELECT MAX(o.object_type)
                      FROM dba_objects o
                     WHERE o.owner       = tp.owner
                       AND o.object_name = tp.table_name
                       AND o.object_type IN ('DIRECTORY','EDITION','MINING MODEL')) AS tipo
              FROM dba_tab_privs tp
             WHERE tp.grantee = c_src
               AND tp.table_name NOT LIKE 'BIN$%'
               AND NOT EXISTS (SELECT 1 FROM dba_recyclebin rb
                                WHERE rb.owner       = tp.owner
                                  AND rb.object_name = tp.table_name)
             ORDER BY tp.owner, tp.table_name, tp.privilege)
  LOOP
    v_obj := CASE r.tipo
               WHEN 'DIRECTORY'    THEN 'DIRECTORY '    || q(r.table_name)
               WHEN 'EDITION'      THEN 'EDITION '      || q(r.table_name)
               WHEN 'MINING MODEL' THEN 'MINING MODEL ' || q(r.owner) || '.' || q(r.table_name)
               ELSE q(r.owner) || '.' || q(r.table_name)
             END;

    v_opt := '';
    IF r.hierarchy = 'YES' THEN v_opt := v_opt || ' WITH HIERARCHY OPTION'; END IF;
    IF r.grantable = 'YES' THEN v_opt := v_opt || ' WITH GRANT OPTION';     END IF;

    v_stmt := 'GRANT ' || r.privilege || ' ON ' || v_obj || ' TO ' || q(c_tgt) || v_opt;
    roda(v_stmt);
    v_n := v_n + 1;
  END LOOP;
  IF v_n = 0 THEN nota('-- Nenhum privilegio de objeto direto na origem.'); END IF;
  nota(' ');

  -- ==========================================================================
  -- 5. Privilegios de coluna
  -- ==========================================================================
  nota('-- ---- 5. Privilegios de coluna -------------------------------------------');
  v_n := 0;
  FOR r IN (SELECT cp.privilege, cp.owner, cp.table_name, cp.column_name, cp.grantable
              FROM dba_col_privs cp
             WHERE cp.grantee = c_src
               AND cp.table_name NOT LIKE 'BIN$%'
               AND NOT EXISTS (SELECT 1 FROM dba_recyclebin rb
                                WHERE rb.owner       = cp.owner
                                  AND rb.object_name = cp.table_name)
             ORDER BY cp.owner, cp.table_name, cp.column_name, cp.privilege)
  LOOP
    v_stmt := 'GRANT ' || r.privilege || ' (' || q(r.column_name) || ') ON ' ||
              q(r.owner) || '.' || q(r.table_name) || ' TO ' || q(c_tgt) ||
              CASE WHEN r.grantable = 'YES' THEN ' WITH GRANT OPTION' END;
    roda(v_stmt);
    v_n := v_n + 1;
  END LOOP;
  IF v_n = 0 THEN nota('-- Nenhum privilegio de coluna na origem.'); END IF;
  nota(' ');

  -- ==========================================================================
  -- 6. Roles default
  --    ALTER USER ... DEFAULT ROLE substitui a lista inteira, nao acumula.
  --    Por isso e emitido UM UNICO comando.
  -- ==========================================================================
  nota('-- ---- 6. Roles default ---------------------------------------------------');

  SELECT COUNT(*),
         SUM(CASE WHEN default_role = 'YES' THEN 1 ELSE 0 END)
    INTO v_tot, v_def
    FROM dba_role_privs
   WHERE grantee = c_src;

  v_tot := NVL(v_tot,0);
  v_def := NVL(v_def,0);

  IF v_tot = 0 THEN
    nota('-- Origem nao possui role. Nada a definir.');

  ELSIF v_def = 0 THEN
    roda('ALTER USER ' || q(c_tgt) || ' DEFAULT ROLE NONE');

  ELSIF v_def = v_tot THEN
    roda('ALTER USER ' || q(c_tgt) || ' DEFAULT ROLE ALL');

  ELSE
    v_lista := NULL;
    FOR r IN (SELECT granted_role
                FROM dba_role_privs
               WHERE grantee = c_src
                 AND default_role = 'YES'
               ORDER BY granted_role)
    LOOP
      v_lista := v_lista || CASE WHEN v_lista IS NULL THEN '' ELSE ', ' END || q(r.granted_role);
    END LOOP;

    IF LENGTH(v_lista) <= 25000 THEN
      roda('ALTER USER ' || q(c_tgt) || ' DEFAULT ROLE ' || v_lista);
    ELSE
      v_lista := NULL;
      FOR r IN (SELECT granted_role
                  FROM dba_role_privs
                 WHERE grantee = c_src
                   AND default_role = 'NO'
                 ORDER BY granted_role)
      LOOP
        v_lista := v_lista || CASE WHEN v_lista IS NULL THEN '' ELSE ', ' END || q(r.granted_role);
      END LOOP;
      roda('ALTER USER ' || q(c_tgt) || ' DEFAULT ROLE ALL EXCEPT ' || v_lista);
    END IF;
  END IF;
  nota(' ');

  -- ==========================================================================
  -- 7. Quotas em tablespace
  -- ==========================================================================
  nota('-- ---- 7. Quotas ----------------------------------------------------------');
  v_n := 0;
  FOR r IN (SELECT tq.tablespace_name, tq.max_bytes
              FROM dba_ts_quotas tq
             WHERE tq.username = c_src
               AND EXISTS (SELECT 1 FROM dba_tablespaces ts
                            WHERE ts.tablespace_name = tq.tablespace_name)
             ORDER BY tq.tablespace_name)
  LOOP
    v_stmt := 'ALTER USER ' || q(c_tgt) || ' QUOTA ' ||
              CASE WHEN r.max_bytes = -1 THEN 'UNLIMITED' ELSE TO_CHAR(r.max_bytes) END ||
              ' ON ' || q(r.tablespace_name);
    roda(v_stmt);
    v_n := v_n + 1;
  END LOOP;
  IF v_n = 0 THEN nota('-- Nenhuma quota explicita na origem.'); END IF;
  nota(' ');

  -- ==========================================================================
  -- 8. Proxy (CONNECT THROUGH) em que a origem e o cliente
  -- ==========================================================================
  nota('-- ---- 8. Proxy connect through -------------------------------------------');
  v_n := 0;
  FOR r IN (SELECT proxy, authorization_constraint
              FROM dba_proxies
             WHERE client = c_src
             ORDER BY proxy)
  LOOP
    nota('-- Constraint na origem: ' || r.authorization_constraint);
    v_stmt := 'ALTER USER ' || q(c_tgt) || ' GRANT CONNECT THROUGH ' || q(r.proxy);
    roda(v_stmt);
    v_n := v_n + 1;
  END LOOP;
  IF v_n = 0 THEN nota('-- Origem nao possui proxy configurado.'); END IF;
  nota(' ');

  -- ==========================================================================
  -- Rodape
  -- ==========================================================================
  nota('SPOOL OFF');
  nota(' ');
  nota('-- ===========================================================================');
  nota('-- Resumo: ' || v_ger || ' comandos gerados. Nenhum foi executado.');
  nota('-- Revise o conteudo e execute com @' || c_base || '_' || c_ts || '.sql');
  nota('-- ');
  nota('-- Nao copiado por natureza: objetos do schema de origem, privilegios');
  nota('-- herdados de PUBLIC, politicas de VPD/Database Vault e ACL de rede.');
  nota('-- ===========================================================================');

EXCEPTION
  WHEN e_parametro THEN
    NULL;
END;
/

SPOOL OFF

PROMPT
PROMPT Arquivo gerado: &v_arq
PROMPT

UNDEFINE p_src
UNDEFINE p_tgt
UNDEFINE p_pwd
UNDEFINE v_ts
UNDEFINE v_arq
UNDEFINE v_base
UNDEFINE current_instance
UNDEFINE current_container
CLEAR COLUMNS

SET HEADING  ON
SET FEEDBACK 6
SET PAGESIZE 50000
SET LINESIZE 200
SET VERIFY   ON
SET SQLBLANKLINES OFF