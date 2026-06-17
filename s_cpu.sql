-- |
-- +-------------------------------------------------------------------------------------------+
-- | Objetivo   : CPU do MOMENTO por sessao/SQL (delta de DB CPU entre dois snapshots)         |
-- | Criador    : Roberto Fernandes Sobrinho                                                   |
-- | Data       : 16/06/2026                                                                   |
-- | Exemplo    : @s_cpu                 (pergunta o intervalo; Enter usa 10; faixa 1 a 60)    |
-- | Arquivo    : s_cpu.sql                                                                    |
-- | Referncia  : familia g_gold (irmao do s.sql)                                              |
-- | Como funct.: tira foto do DB CPU, dorme N segundos, tira a segunda foto e mostra a        |
-- |              diferenca. Resultado e o CPU consumido NO intervalo, nao o acumulado da vida |
-- | Modificacao: 1.0 - 16/06/2026 - rfsobrinho - Versao inicial (snapshot duplo via PL/SQL)   |
-- |              1.1 - 16/06/2026 - rfsobrinho - Intervalo via parametro @s_cpu N (1 a 60)    |
-- |              1.2 - 16/06/2026 - rfsobrinho - ACCEPT com default 10 (Enter usa 10)         |
-- |              1.3 - 17/06/2026 - rfsobrinho - SLEEP universal (DBMS_SESSION 18c+ com       |
-- |                    fallback para DBMS_LOCK em versoes antigas, sem editar o script)       |
-- +-------------------------------------------------------------------------------------------+
-- |                                                                https://dbasobrinho.com.br |
-- +-------------------------------------------------------------------------------------------+
-- | Não espere o futuro mudar tua vida, porque o futuro será a consequência do presente |
-- +-------------------------------------------------------------------------------------------+

SET SERVEROUTPUT ON SIZE UNLIMITED
SET FEEDBACK    OFF
SET VERIFY      OFF
SET LINESIZE    200
SET TRIMSPOOL   ON

-- ---- intervalo em segundos (faixa 1 a 60, default 10 ao teclar Enter) ----------------------
PROMPT
ACCEPT intervalo_raw CHAR DEFAULT '10' PROMPT 'Intervalo de medicao em segundos (1 a 60) [Enter = 10]: '

SET TERMOUT OFF
COLUMN intervalo        NEW_VALUE intervalo        NOPRINT
COLUMN current_instance NEW_VALUE current_instance NOPRINT
SELECT TO_CHAR( LEAST(60, GREATEST(1,
                 NVL( CASE WHEN REGEXP_LIKE(TRIM('&intervalo_raw'),'^[0-9]+(\.[0-9]+)?$')
                           THEN TO_NUMBER(TRIM('&intervalo_raw')) END, 10) )) )  intervalo
,      RPAD(sys_context('USERENV','INSTANCE_NAME'),17)                          current_instance
FROM dual;
SET TERMOUT ON

PROMPT
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | https://github.com/dbasobrinho/g_gold/blob/main/s_cpu.sql                                 |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | Script   : CPU do MOMENTO (delta DB CPU)                         +-+-+-+-+-+-+-+-+-+-+-+  |
PROMPT | Instancia: &current_instance                                     |d|b|a|s|o|b|r|i|n|h|o|  |
PROMPT | Versao   : 1.3                                                   +-+-+-+-+-+-+-+-+-+-+-+  |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | Medindo CPU por &intervalo segundos . . . aguarde                                   


DECLARE
  c_int   CONSTANT NUMBER := &intervalo;          -- segundos do intervalo (ja capado em 1..60)

  -- snapshot 1: DB CPU (microsegundos) por inst#sid
  TYPE t_num IS TABLE OF NUMBER INDEX BY VARCHAR2(64);
  g_snap1   t_num;
  g_topsql  t_num;                                -- soma do delta por sql_id

  -- linha de saida ja com o delta calculado
  TYPE r_lin IS RECORD (
     sidser  VARCHAR2(20),
     usr     VARCHAR2(12),
     sqlid   VARCHAR2(16),
     dcpu    NUMBER,                              -- segundos de CPU no intervalo
     pct     NUMBER,                              -- % de 1 core no intervalo
     st      VARCHAR2(22),
     mach    VARCHAR2(18),
     et      NUMBER
  );
  TYPE t_lin IS TABLE OF r_lin;
  g_lin   t_lin := t_lin();

  -- top por sql_id
  TYPE r_top IS RECORD ( sqlid VARCHAR2(20), v NUMBER );
  TYPE t_top IS TABLE OF r_top;
  g_t     t_top := t_top();

  v_key   VARCHAR2(64);
  v_idx   VARCHAR2(64);
  v_d     NUMBER;
  v_tmp   r_lin;
  v_rt    r_top;
  v_line  VARCHAR2(400);

  FUNCTION fmt_hdr RETURN VARCHAR2 IS
  BEGIN
     RETURN RPAD('SID/SERIAL',14)||'|'||RPAD('USERNAME',10)||'|'||RPAD('SQL_ID/CHILD',16)||'|'||
            LPAD('%CPU',5)||'|'||LPAD('CPU_s',7)||'|'||RPAD('STATE/WAIT',22)||'|'||
            RPAD('MACHINE',18)||'|'||LPAD('ET',6);
  END;
BEGIN
  -- ============================ SNAPSHOT 1 ============================
  FOR r IN (SELECT inst_id, sid, value
            FROM   gv$sess_time_model
            WHERE  stat_name = 'DB CPU') LOOP
     g_snap1(r.inst_id||'#'||r.sid) := r.value;
  END LOOP;

  -- SLEEP universal: tenta DBMS_SESSION.SLEEP (18c+), cai para DBMS_LOCK.SLEEP (legado)
  BEGIN
     EXECUTE IMMEDIATE 'BEGIN DBMS_SESSION.SLEEP(:s); END;' USING c_int;
  EXCEPTION
     WHEN OTHERS THEN
        EXECUTE IMMEDIATE 'BEGIN DBMS_LOCK.SLEEP(:s); END;' USING c_int;
  END;

  -- ===================== SNAPSHOT 2 + DELTA ==========================
  FOR r IN (
     SELECT s.inst_id, s.sid, s.serial#, s.username,
            s.sql_id, s.sql_child_number,
            s.state, s.event, s.machine, s.last_call_et,
            tm.value AS cpu2
     FROM   gv$session s
     JOIN   gv$sess_time_model tm
            ON  tm.inst_id = s.inst_id
            AND tm.sid     = s.sid
            AND tm.stat_name = 'DB CPU'
     WHERE  s.status = 'ACTIVE'
       AND  s.username IS NOT NULL
       AND  NVL(s.wait_class,'?') != 'Idle'
  ) LOOP
     v_key := r.inst_id||'#'||r.sid;

     IF g_snap1.EXISTS(v_key) THEN
        v_d := r.cpu2 - g_snap1(v_key);
     ELSE
        v_d := 0;                      -- sessao nova no intervalo, sem baseline
     END IF;

     IF v_d < 0 THEN v_d := 0; END IF; -- reconexao / SID reusado no intervalo
     v_d := v_d / 1000000;             -- microsegundos -> segundos

     IF v_d > 0 THEN
        v_tmp.sidser := r.sid||','||r.serial#||',@'||r.inst_id;
        v_tmp.usr    := SUBSTR(r.username,1,12);
        v_tmp.sqlid  := SUBSTR(NVL(r.sql_id,'-')||'['||r.sql_child_number||']',1,16);
        v_tmp.dcpu   := ROUND(v_d,1);
        v_tmp.pct    := ROUND(v_d / c_int * 100);
        v_tmp.st     := CASE WHEN r.state = 'WAITING'
                             THEN SUBSTR(TRIM(REPLACE(REPLACE(r.event,'SQL*Net'),'Streams')),1,22)
                             ELSE 'ON CPU' END;
        v_tmp.mach   := SUBSTR(r.machine, NVL(INSTR(r.machine,'\')+1,1), 18); --'\
        v_tmp.et     := r.last_call_et;
        g_lin.EXTEND; g_lin(g_lin.COUNT) := v_tmp;

        IF r.sql_id IS NOT NULL THEN
           v_idx := r.sql_id||'['||r.sql_child_number||']';
           IF g_topsql.EXISTS(v_idx) THEN
              g_topsql(v_idx) := g_topsql(v_idx) + v_d;
           ELSE
              g_topsql(v_idx) := v_d;
           END IF;
        END IF;
     END IF;
  END LOOP;

  -- =================== ORDENA LINHAS POR CPU DESC ====================
  IF g_lin.COUNT > 1 THEN
     FOR i IN 1 .. g_lin.COUNT - 1 LOOP
        FOR j IN i + 1 .. g_lin.COUNT LOOP
           IF g_lin(j).dcpu > g_lin(i).dcpu THEN
              v_tmp := g_lin(i); g_lin(i) := g_lin(j); g_lin(j) := v_tmp;
           END IF;
        END LOOP;
     END LOOP;
  END IF;

  -- =================== TOP 3 SQL POR CPU NO INTERVALO ================
  v_idx := g_topsql.FIRST;
  WHILE v_idx IS NOT NULL LOOP
     g_t.EXTEND;
     g_t(g_t.COUNT).sqlid := v_idx;
     g_t(g_t.COUNT).v     := g_topsql(v_idx);
     v_idx := g_topsql.NEXT(v_idx);
  END LOOP;

  IF g_t.COUNT > 1 THEN
     FOR i IN 1 .. g_t.COUNT - 1 LOOP
        FOR j IN i + 1 .. g_t.COUNT LOOP
           IF g_t(j).v > g_t(i).v THEN
              v_rt := g_t(i); g_t(i) := g_t(j); g_t(j) := v_rt;
           END IF;
        END LOOP;
     END LOOP;
  END IF;

  v_line := NULL;
  FOR i IN 1 .. LEAST(3, g_t.COUNT) LOOP
     v_line := v_line || CASE WHEN i > 1 THEN '  |  ' END
                       || ROUND(g_t(i).v,1)||'s >> '||g_t(i).sqlid;
  END LOOP;

  -- ============================ SAIDA ================================
  DBMS_OUTPUT.PUT_LINE('+-------------------------------------------------------------------------------------------+');
  DBMS_OUTPUT.PUT_LINE('| TOP CPU ('||c_int||'s): '||NVL(v_line,'(nada consumindo CPU no intervalo)'));
  DBMS_OUTPUT.PUT_LINE('+-------------------------------------------------------------------------------------------+');
  DBMS_OUTPUT.PUT_LINE('. . . ');
  DBMS_OUTPUT.PUT_LINE(fmt_hdr);
  DBMS_OUTPUT.PUT_LINE(RPAD('-',103,'-'));

  IF g_lin.COUNT = 0 THEN
     DBMS_OUTPUT.PUT_LINE('(nenhuma sessao consumiu CPU nos '||c_int||'s medidos)');
  ELSE
     FOR i IN 1 .. g_lin.COUNT LOOP
        DBMS_OUTPUT.PUT_LINE(
           RPAD(g_lin(i).sidser,14)||'|'||
           RPAD(g_lin(i).usr,10)||'|'||
           RPAD(g_lin(i).sqlid,16)||'|'||
           LPAD(g_lin(i).pct,5)||'|'||
           LPAD(TO_CHAR(g_lin(i).dcpu),7)||'|'||
           RPAD(g_lin(i).st,22)||'|'||
           RPAD(g_lin(i).mach,18)||'|'||
           LPAD(g_lin(i).et,6));
     END LOOP;
	 DBMS_OUTPUT.PUT_LINE('. . . ');
  END IF;
END;
/

UNDEFINE intervalo_raw
SET FEEDBACK ON
