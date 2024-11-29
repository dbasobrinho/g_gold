-- +-------------------------------------------------------------------------------------------+
-- | Objetivo   : Procurar palavras-chave dentro dos corpos das visões.                        |
-- | Criador    : Roberto Fernandes Sobrinho                                                   |
-- | Data       : 29/11/2024                                                                   |
-- | Exemplo    : @find_text_view_source.sql                                                   |  
-- | Arquivo    : find_text_view_source.sql                                                    |
-- | Referência :                                                                              |
-- | Modificação:                                                                              |
-- +-------------------------------------------------------------------------------------------+
-- |                                                                https://dbasobrinho.com.br | 
-- +-------------------------------------------------------------------------------------------+
WHENEVER SQLERROR EXIT SQL.SQLCODE;
WHENEVER OSERROR EXIT;
SET TERMOUT OFF;
ALTER SESSION SET NLS_DATE_FORMAT='DD-MON-YY HH24:MI:SS';
EXEC dbms_application_info.set_module(module_name => 'tun[sqlpatch_add]', action_name => 'tun[sqlpatch_add]');
COLUMN current_instance NEW_VALUE current_instance NOPRINT;
SELECT rpad(sys_context('USERENV', 'INSTANCE_NAME'), 17) current_instance FROM dual;
SET TERMOUT ON;
PROMPT
PROMPT +--------------------------------------------------------------------------------------------+
PROMPT | https://github.com/dbasobrinho/g_gold/blob/main/find_text_view_source.sql                  |
PROMPT +--------------------------------------------------------------------------------------------+
PROMPT | Script   : LOCALIZAR TEXTO DENTRO DE VIEWS                       +-+-+-+-+-+-+-+-+-+-+-+   |
PROMPT | Instância: &current_instance                                     |d|b|a|s|o|b|r|i|n|h|o|   |
PROMPT | Versão   : 1.0                                                   +-+-+-+-+-+-+-+-+-+-+-+   |
PROMPT +--------------------------------------------------------------------------------------------+
PROMPT
SET ECHO        OFF
SET FEEDBACK    OFF
SET HEADING     ON
SET LINES       188
SET PAGES       300
SET TIMING      OFF
SET TRIMOUT     ON
SET TRIMSPOOL   ON
SET VERIFY      OFF
SET TIME        OFF
SET TIMING      OFF
SET SERVEROUTPUT ON SIZE UNLIMITED;
PROMPT ================================================================================
PROMPT |            *** BUSCA DEPENCENCIAS EM VIEWS POR PALAVRA-CHAVE ***             |
PROMPT ================================================================================
PROMPT |                  Informe o texto a ser buscado nas views e pressione [Enter]:|
PROMPT ================================================================================
ACCEPT p_busca CHAR PROMPT '| Palavra-chave: '
PROMPT ================================================================================
--CT_CONTRACT_CONDITIONS_H
DECLARE
    v_busca VARCHAR2(200) := UPPER(TRIM('&p_busca'));
BEGIN
    IF LENGTH(nvl(v_busca,'x')) <= 3 THEN
        DBMS_OUTPUT.PUT_LINE('       A palavra-chave deve ter mais de 3 caracteres. Busca cancelada.');
        RETURN;
    END IF;

    FOR rec IN (
        select view_name, owner
        from   dba_views
        order  by owner, view_name
    ) LOOP
        IF DBMS_LOB.INSTR(UPPER(DBMS_METADATA.GET_DDL('VIEW', rec.view_name, rec.owner)), v_busca) > 0 THEN
            DBMS_OUTPUT.PUT_LINE('       View : ' || rec.owner || '.' || rec.view_name);
        END IF;
    END LOOP;
END;
/
PROMPT ================================================================================
PROMPT |                       *** BUSCA FINALIZADA! ***                              |
PROMPT ================================================================================
SET FEEDBACK ON
SET VERIFY ON
