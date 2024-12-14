-- |
-- +-------------------------------------------------------------------------------------------+
-- | Objetivo   : Configuração do uso do In-Memory                                             |
-- | Criador    : Roberto Fernandes Sobrinho                                                   |
-- | Data       : 10/12/2024                                                                   |
-- | Exemplo    : @tun_in_memory_use.sql                                                       |  
-- | Arquivo    : tun_in_memory_use.sql                                                        |
-- | Referência :                                                                              |
-- | Modificação: 2.1 - 10/12/2024 - rfsobrinho - Adição de validação de segmentos In-Memory   |
-- |              2.2 - 12/12/2024 - rfsobrinho - Melhorias no uso de prompts para orientação  |
-- |              2.3 - 13/12/2024 - rfsobrinho - Ajustes de layout e inclusão de parâmetros   |
-- +-------------------------------------------------------------------------------------------+
-- |                                                                https://dbasobrinho.com.br |
-- +-------------------------------------------------------------------------------------------+
-- |"O Guina não tinha dó, se ragir, BUMMM! vira pó!"
-- +-------------------------------------------------------------------------------------------+
SET TERMOUT OFF;
ALTER SESSION SET NLS_DATE_FORMAT='DD-MON-YY HH24:MI:SS';
EXEC dbms_application_info.set_module(module_name => 'tun_in_memory_use', action_name => 'Configuração de In-Memory');
COLUMN current_instance NEW_VALUE current_instance NOPRINT;
SELECT rpad(sys_context('USERENV', 'INSTANCE_NAME'), 17) current_instance FROM dual;
SET TERMOUT ON;
PROMPT
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | https://github.com/dbasobrinho/g_gold/blob/main/tun_in_memory_use.sql                     |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | Script   : Configuração do In-Memory                              +-+-+-+-+-+-+-+-+-+-+-+ |
PROMPT | Instância: &current_instance                                      |d|b|a|s|o|b|r|i|n|h|o| |
PROMPT | Versão   : 2.3                                                    +-+-+-+-+-+-+-+-+-+-+-+ |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT
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
CLEAR COLUMNS 
CLEAR BREAKS
CLEAR COMPUTES

PROMPT +-------------------------------------------------------------------------------------------+
PROMPT |                                 MENU DE CONFIGURAÇÃO                                      |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | Este script ajuda a configurar o recurso In-Memory para uma tabela.                       |
PROMPT | Você será solicitado a informar o OWNER e o NOME da TABELA.                               |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT 
ACCEPT V_OWNER      PROMPT 'Digite OWNER : ' DEFAULT '-1';
ACCEPT V_TABLE_NAME PROMPT 'Digite TABELA: ' DEFAULT '-1';
PROMPT 
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT |                          CONFIGURAÇÃO DA ÁREA IN-MEMORY                                   |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT ALTER SYSTEM SET INMEMORY_SIZE = 250M SCOPE=SPFILE SID='*';
PROMPT ALTER SYSTEM SET INMEMORY_QUERY = ENABLE SCOPE=SPFILE SID='*';
PROMPT ALTER SYSTEM SET INMEMORY_FORCE = DEFAULT SCOPE=SPFILE SID='*';
PROMPT
PROMPT Certifique-se de que a SGA esteja dimensionada para acomodar o INMEMORY_SIZE.
PROMPT
PROMPT SHUTDOWN IMMEDIATE;
PROMPT STARTUP;
PROMPT
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT |                        VARIAÇÕES POSSÍVEIS DO IN-MEMORY                                   |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | MEMCOMPRESS: NO MEMCOMPRESS, DML, QUERY LOW, QUERY HIGH, CAPACITY LOW, CAPACITY HIGH      |  
PROMPT | PRIORITY   : NONE, LOW, MEDIUM, HIGH, CRITICAL                                            |
PROMPT | DISTRIBUTE : DISTRIBUTE AUTO, DISTRIBUTE BY ROWID RANGE, DISTRIBUTE BY PARTITION          |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT 
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT |                        CONFIGURAÇÃO DA TABELA PARA IN-MEMORY                              |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT ALTER TABLE &&V_OWNER..&&V_TABLE_NAME INMEMORY MEMCOMPRESS FOR QUERY HIGH PRIORITY CRITICAL;
PROMPT 
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT |                      VERIFICANDO OS SEGMENTOS IN-MEMORY                                   |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT 
COL SEGMENT_NAME FORMAT A30
COL PARTITION_NAME FORMAT A30
COL INMEMORY_SIZE_MB FORMAT 999,999,999
COL BYTES_MB FORMAT 999,999,999
COL POPULATE_STATUS FORMAT A20
COL COMPRESSION_RATIO FORMAT 999.99

SELECT segment_name,
       partition_name,
       inmemory_size / 1024 / 1024 AS inmemory_size_mb,
       bytes / 1024 / 1024 AS bytes_mb,
       populate_status,
       TRUNC(bytes / inmemory_size, 1) * 100 AS compression_ratio
  FROM v$im_segments
 WHERE owner = UPPER(DECODE('&V_OWNER', '-1', owner, '&V_OWNER'))
   AND segment_name = UPPER(DECODE('&V_TABLE_NAME', '-1', segment_name, '&V_TABLE_NAME'))
 ORDER BY segment_name, partition_name;

PROMPT 
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT |                         REMOÇÃO DA TABELA DO IN-MEMORY                                    |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT ALTER TABLE  &&V_OWNER..&&V_TABLE_NAME  NO INMEMORY;
PROMPT 
UNDEFINE V_OWNER
UNDEFINE V_TABLE_NAME
