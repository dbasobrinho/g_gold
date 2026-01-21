
CREATE OR REPLACE NONEDITIONABLE TRIGGER "SYS"."TRG_WONKA_DDL_AUDIT"
  before DDL ON DATABASE
   WHEN (NVL (ora_login_user, 'SYS') not in ('SYS', 'SYSTEM','JOBS_CONTROLM', 'AWS_SCRESERVASERVICE')) DECLARE
  v_sql_id       varchar2(15);
  v_sql_id_v     varchar2(15);
  v_program      varchar2(300);
  v_obj_id       number;
  v_sql_text     clob;
  v_obj_bkp      clob;
  v_obj_comp     clob;
  v_obj_version  number;
  v_ora_sysevent varchar2(20);
  v_obj_hash     VARCHAR2(64);
  v_count        INTEGER;
-- ============================================================================================
-- Nome do Arquivo : SYS.trg_wonka_ddl_audit
-- Autor           : Roberto Fernandes Sobrinho
-- Data Criacao    : 04/02/2005
-- Descricao       : Gera o hist??rico de vers??es dos objetos alterados por DDL,
--                   incluindo dados do objeto, usu??rio que fez a alteracao e o
--                   codigo fonte anterior e modificacao.
-- Execucao        : Automatico - acionado por evento DDL ON DATABASE
-- Refer??ncia      : https://docs.oracle.com/cd/A87860_01/doc/appdev.817/a76939/adg14evt.htm
--
-- Hist??rico de Altera????es:
-- v1.0 - 20/07/2019 - rfsobrinho - Inclusao dos campos sql_id e sqltext
-- v2.0 - 28/07/2019 - rfsobrinho - Trigger totalmente reescrita
-- v2.1 - 20/12/2019 - rfsobrinho - Ajustado para evitar estouro do sql_text
-- v3.0 - 15/01/2025 - rfsobrinho - Incluida validacao por excecao em DDL_LOG_PROGRAM_USER_EXCEPTION
-- ============================================================================================
--
begin
   IF TRIM(ora_dict_obj_type) = 'SUMMARY' THEN
      RETURN;
   END IF;
  --/
  --/
  --/CAP_01 [PROGRAM / SQL_ID]
  select a.program, a.sql_id
    into v_program, v_sql_id
    from v$session a
   where a.sid || a.audsid = sys_context('userenv', 'sid') || sys_context('userenv', 'sessionid');
  --/
  --/Valida programa que nao deve gravar o LOG
  select count(1)
    into v_count
    from ddl_log_program_exception
   where program = trim(upper(v_program));

  if v_count > 0 then
    return;
  end if;

  select count(1)
    into v_count
    from DDL_LOG_PROGRAM_USER_EXCEPTION
   where program = trim(upper(v_program))
     and db_user = ora_login_user;

  if v_count > 0 then
    return;
  end if;
  --/
  --/CAP_02 [OBJ_ID]
  begin
    select x.object_id
      into v_obj_id
      from dba_objects x
     WHERE x.owner = ora_dict_obj_owner
       and x.object_type = ora_dict_obj_type
       AND x.object_name = ora_dict_obj_name;
  exception
    when no_data_found then
      v_obj_id := 0;
  end;
  --/
  v_ora_sysevent := ora_sysevent;
  IF TRIM(v_ora_sysevent) = 'SUMMARY' THEN
      RETURN;
  END IF;
  --/CAP_03 [SQL_TEXT]
  begin
    declare
      v_sql_out ora_name_list_t;
      v_num     number;
    begin
      v_num := ora_sql_txt(v_sql_out);
      for i in 1 .. v_num loop
        v_sql_text := v_sql_text || v_sql_out(i);
      end loop;
    end;
  exception
    --v2.1 - rfsobrinho - 20/12/2019
    when invalid_number then
      null;
  end;
  --/
  select nvl(max(e.obj_version), 0) + 1
    into v_obj_version
    from DDL_LOG e
   where e.obj_type = ora_dict_obj_type
     and e.obj_owner = ora_dict_obj_owner
     and e.obj_name = ora_dict_obj_name;
  --/CAP_04 [OBJ_BKP]
  if v_obj_id > 0 and
     ora_dict_obj_type IN ('PACKAGE BODY',
                           'TYPE BODY',
                           'PROCEDURE',
                           'TYPE',
                           'PACKAGE',
                           'FUNCTION',
                           'JAVA SOURCE',
                           'TRIGGER',
                           'VIEW') then
    --/
    if ora_dict_obj_type = 'VIEW' then
      for r3 in (select a.text
                   from dba_views a
                  where a.owner = ora_dict_obj_owner
                    and a.view_name = ora_dict_obj_name) loop
        v_obj_bkp := v_obj_bkp || r3.text;
      end loop;
    else
                BEGIN
                          for r3 in (select b.text
                                                   from dba_source b
                                                  where b.type = ora_dict_obj_type
                                                        and b.owner = ora_dict_obj_owner
                                                        and b.name = ora_dict_obj_name
                                                        AND LENGTH(TRIM(b.text)) > 0
                                                  order by b.line) loop
                                v_obj_bkp := v_obj_bkp || r3.text;
                                --DBMS_LOB.APPEND(v_obj_bkp, TO_CLOB(r3.text));
                          end loop;
           EXCEPTION WHEN OTHERS THEN NULL; END;
    end if;
    --/
        DECLARE
          l_blob        BLOB;
          l_dest_off    INTEGER := 1;
          l_src_off     INTEGER := 1;
          l_langctx     INTEGER := DBMS_LOB.DEFAULT_LANG_CTX;
          l_warning     INTEGER;
        BEGIN
          DBMS_LOB.CREATETEMPORARY(l_blob, TRUE);
          DBMS_LOB.CONVERTTOBLOB(
                dest_lob     => l_blob,
                src_clob     => v_sql_text,
                amount       => DBMS_LOB.LOBMAXSIZE,
                dest_offset  => l_dest_off,
                src_offset   => l_src_off,
                blob_csid    => NLS_CHARSET_ID('AL32UTF8'),
                lang_context => l_langctx,
                warning      => l_warning
          );
          v_obj_hash := RAWTOHEX(DBMS_CRYPTO.HASH(l_blob, DBMS_CRYPTO.HASH_SH1));
          DBMS_LOB.FREETEMPORARY(l_blob);
        END;

    --v_obj_hash := RAWTOHEX(DBMS_CRYPTO.HASH(UTL_I18N.STRING_TO_RAW(v_sql_text,'AL32UTF8'), DBMS_CRYPTO.HASH_SH1));

        if regexp_like(upper(v_sql_text), '/\*\s*QSMQ\s+VALIDATION\s*\*/') then
           return;
        end if;
        --/
        if regexp_like(
                 upper(trim(v_sql_text)),
                 '^ALTER\s+(PUBLIC\s+)?(PACKAGE|PROCEDURE|FUNCTION|VIEW|TRIGGER|TYPE|SYNONYM)\s+\S+\s+COMPILE\s*;?$',
                 'xi'
           ) then
          v_obj_version  := v_obj_version - 1;
          v_ora_sysevent := 'RECOMPIL_ALT';
    elsif regexp_like(upper(trim(v_sql_text)), '^GRANT\s+.+\s+TO\s+.+$', 'i') then
        v_obj_version  := v_obj_version - 1;
        else
          declare
                v_ultima_hash VARCHAR2(64);
          begin
                SELECT max(obj_hash)
                  INTO v_ultima_hash
                  FROM DDL_LOG
                 WHERE obj_type = ora_dict_obj_type
                   AND obj_owner = ora_dict_obj_owner
                   AND obj_name = ora_dict_obj_name
                   AND obj_version > 0
                   AND obj_version = v_obj_version - 1;

                IF v_obj_hash = v_ultima_hash THEN
                  v_ora_sysevent := 'RECOMPIL';
                  v_obj_version  := v_obj_version - 1;
                END IF;
          exception
                when no_data_found then
                  null; -- Primeira vers??o, segue com a atual
          end;
        end if;
  end if;
  --/
  ---dbms_system.ksdwrt(2, '002');
  insert into DDL_LOG
    (pdb,
     ddl_date,
     ddl_type,
     db_user,
     os_user,
     obj_id,
     obj_type,
     obj_owner,
     obj_name,
     obj_version,
     sql_id,
     sql_text,
     obj_bkp,
     terminal,
     program,
     ipadress,
     action,
     module,
     client_info,
     obj_hash)
  values
    (SYS_CONTEXT('USERENV', 'CON_NAME') 	-->PDB            VARCHAR2(30),
    ,CURRENT_TIMESTAMP 						-->DDL_DATE       DATE,
    ,v_ora_sysevent 						-->DDL_TYPE       VARCHAR2(30),
    ,ora_login_user 						-->DB_USER        VARCHAR2(30),
    ,sys_context('userenv', 'os_user') 		-->OS_USER        VARCHAR2(300),
    ,v_obj_id 								-->OBJ_ID         NUMBER,
    ,ora_dict_obj_type 						-->OBJ_TYPE       VARCHAR2(18),
    ,ora_dict_obj_owner 					-->OBJ_OWNER      VARCHAR2(30),
    ,ora_dict_obj_name 						-->OBJ_NAME       VARCHAR2(150),
    ,v_obj_version 							-->OBJ_VERSION    NUMBER,
    ,v_sql_id 								-->SQL_ID         VARCHAR2(20),
    ,v_sql_text 							-->SQL_TEXT       CLOB,
    ,v_obj_bkp 								-->OBJ_BKP        CLOB,
    ,sys_context('userenv', 'host') 		-->TERMINAL       VARCHAR2(300),
    ,v_program 								-->PROGRAM        VARCHAR2(300),
    ,SYS_CONTEXT('USERENV', 'IP_ADDRESS') 	-->IPADRESS       VARCHAR2(46),
    ,sys_context('userenv', 'action')		--> ACTION             VARCHAR2(300),
    ,sys_context('userenv', 'module') 		-->MODULE         VARCHAR2(300),
    ,sys_context('userenv', 'client_info') 	-->CLIENT_INFO    VARCHAR2(300)
    ,v_obj_hash);
exception
  when others then
    dbms_system.ksdwrt(2,'ORA-00902 ERRO NA TRIGGER WONKA [SYS.TRG_WONKA_DDL_AUDIT] - Backtrace: ' ||dbms_utility.format_error_backtrace || ' SQLERRM: ' ||substr(sqlerrm, 1, 300));
END trg_wonka_ddl_audit;
/
ALTER TRIGGER "SYS"."TRG_WONKA_DDL_AUDIT" ENABLE;
