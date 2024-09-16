-- Define o prompt para mostrar o nome do usuário e o identificador de conexão
SET SQLPROMPT "_USER'@'_CONNECT_IDENTIFIER> "

-- Define o editor padrão
DEFINE _EDITOR = vim

-- Configurações de ambiente
SET TERMOUT             OFF
SET FEEDBACK            OFF
SET TIME                OFF
SET LINES               188
SET PAGES               300

-- Formatação de colunas
COLUMN FILE_NAME FORMAT A120
COLUMN NAME      FORMAT A80
COLUMN TYPE      FORMAT A30
COLUMN VALUE     FORMAT A110
COLUMN COUNT(*)  FORMAT 999999999999999
COLUMN CNT       FORMAT 999999999999999

-- Ajuste de sessão
ALTER SESSION SET NLS_DATE_FORMAT = 'DD-MON-YYYY HH24:MI:SS';

-- Definição de módulo para monitoramento de atividades
EXEC dbms_application_info.set_module( module_name => 'DBA - TRABALHANDO . . . - SQLPLUS_SYS [ZAS]', action_name => 'DBA - TRABALHANDO . . . - SQLPLUS_SYS [ZAS]');

-- Configurações adicionais
SET LONG 20000
SET LONGCHUNKSIZE 20000
SET TAB OFF
SET TRIMSPOOL ON
SET TERMOUT ON
SET FEEDBACK ON
SET VERIFY OFF
SET ECHO OFF
SET TIMING ON
SET HISTORY ON

-- Mensagem de boas-vindas personalizada
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | Blog     : https://dbasobrinho.com.br/                           +-+-+-+-+-+-+-+-+-+-+-+  |
PROMPT | Ambiente : Treinamento                                           |d|b|a|s|o|b|r|i|n|h|o|  |
PROMPT | Versão   : 1.0                                                   +-+-+-+-+-+-+-+-+-+-+-+  |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT
