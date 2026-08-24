-- | 
-- +-------------------------------------------------------------------------------------------+
-- | Objetivo   : Diagnostico geral de contencao (qualquer enqueue ou espera com bloqueador)   |
-- | Criador    : Roberto Fernandes Sobrinho                                                   |
-- | Data       : 24/08/2026                                                                   | 
-- | Exemplo    : @lock_diag_geral.sql                                                         |
-- | Arquivo    : lock_diag_geral.sql                                                          |
-- | Modificacao: 1.0 - 24/08/2026 - rfsobrinho - primeira versao                              |
-- |                                              quatro secoes: vitimas, causadoras,          |
-- |                                              enqueues segurados e resumo                  |
-- +-------------------------------------------------------------------------------------------+
-- |                                                                https://dbasobrinho.com.br |
-- +-------------------------------------------------------------------------------------------+
-- |"O Guina nao tinha do, se ragir, BUMMM! vira po!"
-- +-------------------------------------------------------------------------------------------+
-- |
-- +-------------------------------------------------------------------------------------------+
-- | Notas da versao 1.0:                                                                      |
-- |   * Complementa o locktree.sql: onde a arvore mostra a hierarquia, este mostra o          |
-- |     retrato agregado, o raio-x das causadoras e o comando de kill ja montado.             |
-- |   * Deteccao por blocking_session/final_blocking_session do gv$session, entao pega        |
-- |     qualquer tipo: TX, TM (FK sem indice, DDL), UL, HW, SQ, CF, alem de esperas que       |
-- |     nao sao enqueue (row cache lock, library cache lock/pin, gc buffer busy).             |
-- |   * Usa FINAL_BLOCKING_SESSION (11.2+), entao em cadeia de varios niveis aponta a         |
-- |     raiz e nao o intermediario.                                                           |
-- |   * O ROWID da secao 1 so e montado quando ROW_WAIT_OBJ# e valido. Para espera que        |
-- |     nao e de linha, o recurso sai como "(nao e lock de linha)".                           |
-- |   * Pergunta o usuario alvo na entrada. Digite % para varrer o banco inteiro.             |
-- +-------------------------------------------------------------------------------------------+
--|
SET TERMOUT OFF;
ALTER SESSION SET NLS_DATE_FORMAT='DD-MON-YY HH24:MI:SS';
EXEC dbms_application_info.set_module( module_name => 'lock_diag[lock_diag_geral.sql]', action_name =>  'lock_diag[lock_diag_geral.sql]');
COLUMN current_instance NEW_VALUE current_instance NOPRINT;
SELECT rpad(sys_context('USERENV', 'INSTANCE_NAME'), 17) current_instance FROM dual;
SET TERMOUT ON;
 
PROMPT
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | Informe o usuario alvo do diagnostico.                                                    |
PROMPT | Digite o nome exato (ex: ERSECOMPRD_COFRE) ou % para TODOS os usuarios.                   |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT
ACCEPT v_user CHAR DEFAULT '%' PROMPT 'Usuario (ENTER = % todos): '

SET TERMOUT OFF;
COLUMN filtro_user NEW_VALUE filtro_user NOPRINT;
COLUMN sp_name     NEW_VALUE sp_name     NOPRINT;
COLUMN sp_show     NEW_VALUE sp_show     NOPRINT;
WITH nome AS (
  SELECT 'lock_diag_geral_'                              ||
         sys_context('USERENV','INSTANCE_NAME')          || '_' ||
         to_char(sysdate,'YYYY-MM-DD-HH24MISS')          || '.out' AS arquivo
    FROM dual
)
SELECT rpad(upper('&v_user'), 17) filtro_user,
       arquivo                    sp_name,
       rpad(arquivo, 45)          sp_show
  FROM nome;
SET TERMOUT ON;

SPOOL &sp_name
PROMPT
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | https://github.com/dbasobrinho/g_gold/blob/main/lock_diag_geral.sql                       |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | Script   : Diagnostico Geral de Locks (qualquer enqueue)         +-+-+-+-+-+-+-+-+-+-+-+  |
PROMPT | Instancia: &current_instance                                     |d|b|a|s|o|b|r|i|n|h|o|  |
PROMPT | Versao   : 1.6                                                   +-+-+-+-+-+-+-+-+-+-+-+  |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | Spool    : &sp_name                              
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT
SET ECHO        OFF
SET FEEDBACK    OFF
SET HEADING     OFF
SET LINES       240
SET PAGES       0
SET TERMOUT     ON
SET TIMING      OFF
SET TRIMOUT     ON
SET TRIMSPOOL   ON
SET VERIFY      OFF
SET TAB         OFF
SET LONG        20000

COLUMN saida FORMAT A240

PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | SECAO 1 - ESPERAS COM BLOQUEADOR (VITIMAS), TODOS OS TIPOS DE LOCK                        |
PROMPT | filtro v_user: SIM, aplicado no waiter                                                    |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT EVENT                                     CLASSE          ENQ  RAIZ_CADEIA        QTD  NOS  MAX_S
PROMPT --------------------------------------------------------------------------------------------------

WITH espera AS (
  SELECT w.inst_id,
         w.sid,
         w.event,
         w.wait_class,
         w.seconds_in_wait,
         w.row_wait_obj#                                   AS obj,
         w.row_wait_file#                                  AS f,
         w.row_wait_block#                                 AS b,
         w.row_wait_row#                                   AS r,
         NVL(w.final_blocking_instance || ':' ||
             w.final_blocking_session,
             w.blocking_instance || ':' ||
             w.blocking_session)                           AS raiz,
         (SELECT MIN(lr.type)
            FROM gv$lock lr
           WHERE lr.inst_id = w.inst_id
             AND lr.sid     = w.sid
             AND lr.request > 0)                           AS enq
    FROM gv$session w
   WHERE w.blocking_session IS NOT NULL
     AND w.type     = 'USER'
     AND w.username LIKE upper('&v_user')
),
detalhe AS (
  SELECT e.*,
         CASE WHEN o.object_name IS NOT NULL
              THEN o.owner || '.' || o.object_name END                    AS objeto,
         CASE WHEN e.obj > 0 AND o.data_object_id IS NOT NULL
              THEN DBMS_ROWID.ROWID_CREATE(1, o.data_object_id, e.f, e.b, e.r)
         END                                                          AS linha,
         CASE WHEN e.obj > 0 THEN o.object_type END                   AS seg_type,
         NVL(i.table_owner, NVL(l.owner,  o.owner))                   AS tab_owner,
         NVL(i.table_name,  NVL(l.table_name, o.object_name))         AS tab_name
    FROM espera e
    LEFT JOIN dba_objects o
      ON o.object_id = e.obj
    LEFT JOIN dba_indexes i
      ON i.owner = o.owner AND i.index_name = o.object_name
    LEFT JOIN dba_lobs l
      ON l.owner = o.owner AND l.segment_name = o.object_name
)
SELECT RPAD(d.event, 41)                             ||
       ' ' || RPAD(NVL(d.wait_class,'-'), 15)        ||
       ' ' || RPAD(NVL(d.enq,'-'), 4)                ||
       ' ' || RPAD(NVL(d.raiz,'-'), 16)              ||
       ' ' || LPAD(COUNT(*), 5)                      ||
       ' ' || LPAD(COUNT(DISTINCT d.inst_id), 4)     ||
       ' ' || LPAD(MAX(d.seconds_in_wait), 6)        ||
       CHR(10) ||
       '     -> recurso : ' ||
       CASE
         WHEN d.objeto IS NOT NULL AND d.linha IS NOT NULL
              THEN d.objeto || ' rowid=' || d.linha
         WHEN d.objeto IS NOT NULL
              THEN d.objeto || ' (sem rowid: data_object_id nulo)'
         WHEN d.obj > 0
              THEN 'obj#=' || d.obj || ' (nao encontrado em dba_objects)'
         ELSE '(nao e lock de linha)'
       END ||
       CASE
         WHEN d.linha IS NOT NULL
          AND (d.seg_type = 'TABLE' OR d.seg_type LIKE 'TABLE %')
         THEN CHR(10) || '     -> ver     : select * from ' ||
              d.tab_owner || '.' || d.tab_name ||
              ' where rowid = ''' || d.linha || ''';'
         WHEN d.linha IS NOT NULL
         THEN CHR(10) || '     -> segmento: ' || d.seg_type ||
              ', tabela base ' || d.tab_owner || '.' || d.tab_name
       END || CHR(10)                                AS saida
  FROM detalhe d
 GROUP BY d.event, d.wait_class, d.enq, d.raiz, d.obj,
          d.objeto, d.linha, d.seg_type, d.tab_owner, d.tab_name
 ORDER BY COUNT(*) DESC;

PROMPT
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | SECAO 2 - SESSOES BLOQUEADORAS (CAUSADORAS), RAIZ DA CADEIA                               |
PROMPT | filtro v_user: SIM no waiter, NAO no bloqueador (o culpado pode ser outro usuario)        |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT SESSAO           USUARIO         MACHINE                 STATUS   INATIVO_S  UNDO_BLK  VITIMAS
PROMPT --------------------------------------------------------------------------------------------------

SELECT RPAD(b.inst_id || ':' || b.sid || ',' || b.serial#, 16)    ||
       ' ' || RPAD(NVL(b.username,'-'), 15)                       ||
       ' ' || RPAD(NVL(b.machine,'-'), 23)                        ||
       ' ' || RPAD(b.status, 8)                                   ||
       ' ' || LPAD(b.last_call_et, 9)                             ||
       ' ' || LPAD(NVL(TO_CHAR(t.used_ublk),'-'), 9)              ||
       ' ' || LPAD((SELECT COUNT(*)
                      FROM gv$session w
                     WHERE w.final_blocking_session  = b.sid
                       AND w.final_blocking_instance = b.inst_id
                       AND w.username LIKE upper('&v_user')), 8) ||
       CHR(10) ||
       '     -> program : ' || NVL(b.program,'-')                 ||
       CHR(10) ||
       '     -> module  : ' || NVL(b.module,'-') ||
       '  | action: '       || NVL(b.action,'-')                  ||
       CHR(10) ||
       '     -> evento  : ' || NVL(b.event,'-') ||
       '  | classe: '       || NVL(b.wait_class,'-')              ||
       CHR(10) ||
       '     -> sql_id  : ' || NVL(NVL(b.sql_id, b.prev_sql_id),'-') ||
       '  | logon: '        || TO_CHAR(b.logon_time,'DD/MM/YYYY HH24:MI:SS') ||
       CHR(10) ||
       '     -> kill    : ALTER SYSTEM KILL SESSION ''' ||
       b.sid || ',' || b.serial# || ',@' || b.inst_id || ''' IMMEDIATE;' ||
       CHR(10)                                                    AS saida
  FROM gv$session b
  LEFT JOIN gv$transaction t
    ON t.ses_addr = b.saddr AND t.inst_id = b.inst_id
 WHERE EXISTS (SELECT 1
                 FROM gv$session w
                WHERE w.final_blocking_session  = b.sid
                  AND w.final_blocking_instance = b.inst_id
                  AND w.username LIKE upper('&v_user'))
 ORDER BY (SELECT COUNT(*)
             FROM gv$session w
            WHERE w.final_blocking_session  = b.sid
              AND w.final_blocking_instance = b.inst_id
              AND w.username LIKE upper('&v_user')) DESC;

PROMPT
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | SECAO 3 - ENQUEUES SEGURADOS QUE BLOQUEIAM (TX, TM, UL, HW, SQ, CF, TS...)                |
PROMPT | filtro v_user: NAO, inventario global de BLOCK=1 no banco inteiro                         |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT TIPO  SESSAO           USUARIO         MODO         RECURSO
PROMPT --------------------------------------------------------------------------------------------------

SELECT RPAD(l.type, 5)                                                ||
       ' ' || RPAD(l.inst_id || ':' || s.sid || ',' || s.serial#, 16) ||
       ' ' || RPAD(NVL(s.username,'-'), 15)                           ||
       ' ' || RPAD(DECODE(l.lmode, 0,'NONE', 1,'NULL', 2,'ROW-S',
                                   3,'ROW-X', 4,'SHARE', 5,'S/ROW-X',
                                   6,'EXCLUSIVE',
                                   TO_CHAR(l.lmode)), 12)             ||
       ' ' || NVL(o.owner || '.' || o.object_name,
                  'id1=' || l.id1 || ' id2=' || l.id2)                ||
       CHR(10) ||
       '     -> ctime   : ' || l.ctime || 's segurando' ||
       '  | esperando por esse lock: ' ||
       (SELECT COUNT(*)
          FROM gv$lock lw
         WHERE lw.type    = l.type
           AND lw.id1     = l.id1
           AND lw.id2     = l.id2
           AND lw.request > 0)                                        ||
       CHR(10) ||
       '     -> kill    : ALTER SYSTEM KILL SESSION ''' ||
       s.sid || ',' || s.serial# || ',@' || l.inst_id || ''' IMMEDIATE;' ||
       CHR(10)                                                        AS saida
  FROM gv$lock l
  JOIN gv$session s
    ON s.sid = l.sid AND s.inst_id = l.inst_id
  LEFT JOIN dba_objects o
    ON o.object_id = l.id1
   AND l.type      = 'TM'
 WHERE l.block = 1
 ORDER BY l.type, l.inst_id, s.sid;

PROMPT
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | SECAO 4 - RESUMO POR EVENTO, TIPO DE ENQUEUE E MODO PEDIDO                                |
PROMPT | filtro v_user: SIM, aplicado no waiter                                                    |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT EVENT                                          TIPO  MODO_PEDIDO                       QTD
PROMPT --------------------------------------------------------------------------------------------------

SELECT RPAD(s.event, 46)                                          ||
       ' ' || RPAD(NVL(l.type,'-'), 5)                            ||
       ' ' || RPAD(DECODE(l.request, 0,'0 - nenhum',
                                     1,'1 - NULL',
                                     2,'2 - ROW-S',
                                     3,'3 - ROW-X',
                                     4,'4 - SHARE (chave unica)',
                                     5,'5 - S/ROW-X',
                                     6,'6 - EXCLUSIVE (upd/del)',
                                     TO_CHAR(l.request)), 30)     ||
       ' ' || LPAD(COUNT(*), 6)                                   AS saida
  FROM gv$session s
  LEFT JOIN gv$lock l
    ON l.inst_id  = s.inst_id
   AND l.sid      = s.sid
   AND l.request  > 0
 WHERE s.blocking_session IS NOT NULL
   AND s.type     = 'USER'
   AND s.username LIKE upper('&v_user')
 GROUP BY s.event, l.type, l.request
 ORDER BY COUNT(*) DESC;

PROMPT
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | SECAO 5 - HOTSPOT POR ROWID (linha em disputa + SELECT pronto)                            |
PROMPT | filtro v_user: SIM, aplicado no waiter                                                    |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT OBJETO / PARTICAO                        ROWID                NOS   QTD NBLOQ  BLOQUEADORES
PROMPT --------------------------------------------------------------------------------------------------

WITH base AS (
  SELECT o.owner                          AS seg_owner,
         o.object_name                    AS seg_name,
         o.object_type                    AS seg_type,
         o.subobject_name                 AS particao,
         o.data_object_id,
         s.row_wait_file#                 AS f,
         s.row_wait_block#                AS b,
         s.row_wait_row#                  AS r,
         s.inst_id,
         NVL(s.final_blocking_instance || ':' || s.final_blocking_session,
             s.blocking_instance       || ':' || s.blocking_session) AS bloq
    FROM gv$session s
    JOIN dba_objects o
      ON o.object_id = s.row_wait_obj#
   WHERE s.username        LIKE upper('&v_user')
     AND s.type            = 'USER'
     AND s.row_wait_obj#  <> -1
     AND o.data_object_id IS NOT NULL
     AND s.blocking_session IS NOT NULL
),
resolvido AS (
  SELECT b.*,
         NVL(i.table_owner, NVL(l.owner,      b.seg_owner))  AS tab_owner,
         NVL(i.table_name,  NVL(l.table_name, b.seg_name))   AS tab_name
    FROM base b
    LEFT JOIN dba_indexes i
      ON i.owner = b.seg_owner AND i.index_name   = b.seg_name
    LEFT JOIN dba_lobs l
      ON l.owner = b.seg_owner AND l.segment_name = b.seg_name
),
bloq_distinto AS (
  SELECT DISTINCT seg_owner, seg_name, data_object_id, f, b, r, bloq
    FROM resolvido
),
bloq_lista AS (
  SELECT seg_owner, seg_name, data_object_id, f, b, r,
         LISTAGG(bloq, ', ') WITHIN GROUP (ORDER BY bloq) AS lista_bloq,
         COUNT(*)                                          AS nbloq
    FROM bloq_distinto
   GROUP BY seg_owner, seg_name, data_object_id, f, b, r
),
agg AS (
  SELECT seg_owner, seg_name, seg_type, particao, data_object_id,
         f, b, r, tab_owner, tab_name,
         COUNT(DISTINCT inst_id) AS nos,
         COUNT(*)                AS qtd
    FROM resolvido
   GROUP BY seg_owner, seg_name, seg_type, particao, data_object_id,
            f, b, r, tab_owner, tab_name
)
SELECT RPAD(a.seg_owner || '.' || a.seg_name ||
            CASE WHEN a.particao IS NOT NULL
                 THEN ' (' || a.particao || ')' END, 40)                       ||
       ' ' || RPAD(DBMS_ROWID.ROWID_CREATE(1, a.data_object_id,
                                           a.f, a.b, a.r), 20)                 ||
       ' ' || LPAD(a.nos, 3)                                                   ||
       ' ' || LPAD(a.qtd, 5)                                                   ||
       ' ' || LPAD(bl.nbloq, 5)                                                ||
       '  ' || bl.lista_bloq                                                   ||
       CHR(10) ||
       '     -> ' ||
       CASE
         WHEN a.seg_type = 'TABLE' OR a.seg_type LIKE 'TABLE %' THEN
           'select * from ' || a.tab_owner || '.' || a.tab_name ||
           ' where rowid = ''' ||
           DBMS_ROWID.ROWID_CREATE(1, a.data_object_id, a.f, a.b, a.r) || ''';'
         ELSE
           a.seg_type || ' -> tabela base ' || a.tab_owner || '.' || a.tab_name ||
           ' (rowid nao aplicavel direto)'
       END || CHR(10)                                                          AS saida
  FROM agg a
  JOIN bloq_lista bl
    ON  bl.seg_owner      = a.seg_owner
    AND bl.seg_name       = a.seg_name
    AND bl.data_object_id = a.data_object_id
    AND bl.f              = a.f
    AND bl.b              = a.b
    AND bl.r              = a.r
 ORDER BY a.qtd DESC;

PROMPT
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | COMO LER                                                                                  |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | SECAO 1 : toda sessao listada e VITIMA. ENQ = tipo de enqueue pedido (TX, TM, UL...).     |
PROMPT |            Evento que nao e enqueue vem com '-' e recurso "(nao e lock de linha)".        |
PROMPT |            RAIZ_CADEIA usa FINAL_BLOCKING, ja aponta o culpado no fim da corrente.        |
PROMPT | SECAO 2 : as CAUSADORAS.                                                                  |
PROMPT |            INACTIVE + INATIVO_S alto -> transacao esquecida aberta no cliente.            |
PROMPT |            ACTIVE + sql_id rodando   -> transacao trabalhando, otimizar o SQL.            |
PROMPT |            UNDO_BLK alto             -> rollback caro se matar a sessao.                  |
PROMPT | SECAO 3 : quem segura enqueue com BLOCK=1.                                                |
PROMPT |            TX transacao | TM tabela (DDL x DML, FK sem indice) | UL DBMS_LOCK             |
PROMPT |            HW high water mark | SQ sequence | CF controlfile                              |
PROMPT | SECAO 4 : request 4 (SHARE) -> conflito de CHAVE UNICA.                                   |
PROMPT |            request 6 (EXCLUSIVE) -> update ou delete de linha existente.                  |
PROMPT | FILTRO   : v_user vale sempre sobre a VITIMA. O bloqueador nunca e filtrado (secao 2)     |
PROMPT |            e a secao 3 e global de proposito. Ver cabecalho do script.                    |
PROMPT | SECAO 5 : hotspot por linha. Copie o SELECT da segunda linha para ver o registro em       |
PROMPT |            disputa. NBLOQ=1 com QTD alto -> uma sessao segura e o resto se acumula.       |
PROMPT |            NOS=3 -> a mesma linha e disputada nos tres nos, revisar a aplicacao.          |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT

SPOOL OFF

PROMPT
PROMPT Relatorio gravado em: &sp_name
PROMPT

SET HEADING  ON
SET PAGES    300
SET FEEDBACK ON
SET LINES    220
UNDEFINE v_user
UNDEFINE sp_name
UNDEFINE sp_show
UNDEFINE filtro_user