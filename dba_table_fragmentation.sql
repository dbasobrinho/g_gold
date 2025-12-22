SET LINESIZE 300
SET PAGESIZE 200
SET VERIFY OFF
SET FEEDBACK ON

COLUMN OWNER              FORMAT A20
COLUMN TABLE_NAME        FORMAT A35
COLUMN TABLESPACE_NAME   FORMAT A25
COLUMN GB_ALOCADO_TOTAL  FORMAT 999,999,999.99
COLUMN GB_ABAIXO_HWM     FORMAT 999,999,999.99
COLUMN GB_FRAGMENTADO    FORMAT 999,999,999.99
COLUMN PCT_FRAGMENTACAO  FORMAT 999.99

WITH seg_info AS (
    SELECT
        owner,
        segment_name AS table_name,
        tablespace_name,
        bytes AS bytes_alocados_total
    FROM dba_segments
    WHERE segment_type = 'TABLE'
),
tab_hwm AS (
    SELECT
        t.owner,
        t.table_name,
        t.blocks * ts.block_size AS bytes_abaixo_hwm
    FROM dba_tables t
    JOIN dba_tablespaces ts 
      ON t.tablespace_name = ts.tablespace_name
    WHERE t.blocks IS NOT NULL
)
SELECT
    s.owner,
    s.table_name,
    s.tablespace_name,
    ROUND(s.bytes_alocados_total / 1024 / 1024 / 1024, 2) AS gb_alocado_total,
    ROUND(t.bytes_abaixo_hwm   / 1024 / 1024 / 1024, 2) AS gb_abaixo_hwm,
    ROUND((s.bytes_alocados_total - t.bytes_abaixo_hwm) / 1024 / 1024 / 1024, 2) AS gb_fragmentado,
    ROUND((s.bytes_alocados_total - t.bytes_abaixo_hwm) * 100 / s.bytes_alocados_total, 2) AS pct_fragmentacao
FROM seg_info s
JOIN tab_hwm t 
  ON s.owner = t.owner 
 AND s.table_name = t.table_name
WHERE 
      (s.bytes_alocados_total - t.bytes_abaixo_hwm) > 1 * 1024 * 1024 * 1024
  AND ((s.bytes_alocados_total - t.bytes_abaixo_hwm) * 100 / s.bytes_alocados_total) > 5
ORDER BY gb_fragmentado DESC;