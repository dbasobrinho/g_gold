PROMPT ..
PROMPT +--------------------------------------------------------------------------------------------------------------------------------------+
PROMPT |  _____   ______ _______ _______        _______               ______  _______ _______ _     _ ______   _____  _______  ______ ______  |
PROMPT | |     | |_____/ |_____| |       |      |______      ___      |     \ |_____| |______ |_____| |_____] |     | |_____| |_____/ |     \ |
PROMPT | |_____| |    \_ |     | |_____  |_____ |______               |_____/ |     | ______| |     | |_____] |_____| |     | |    \_ |_____/ |
PROMPT |                                                                                                                                      |
PROMPT +--------------------------------------------------------------------------------------------------------------------------------------+
PROMPT | Author : Adrian Billington                                                                                                           |
PROMPT | Version: V1.0                                                                                                                        | 
PROMPT | ref    : http://www.e2sn.com                                                                                +-+-+-+-+-+-+-+-+-+-+-+  |
PROMPT | ref    : http://www.oracle-developer.net                                                                    |d|b|a|s|o|b|r|i|n|h|o|  |
PROMPT | ref    : https://github.com/dbsid/moats_rac                                                                 +-+-+-+-+-+-+-+-+-+-+-+  |
PROMPT +--------------------------------------------------------------------------------------------------------------------------------------+
PROMPT ..
--set arrays 80 lines 2000 trims on head off tab off pages 0
-- Windows sqlplus properties for optimal output (relative to font):
--  * font: lucide console 12
--  * window size: height of 47
ACCEPT V_REFRESH NUMBER    PROMPT 'REFRESH IN SECONDS <Default = [5 ]>= ' DEFAULT 5
ACCEPT V_SCREEN  NUMBER    PROMPT 'SCREEN SIZE        <Default = [64]>= ' DEFAULT 64
set arrays 64 lines 2000 trims on head off tab off pages 0
--select * from table(moats.top(p_refresh_rate => 2,p_screen_size=>64))
--select * from table(moats.top(p_refresh_rate => 2,p_screen_size=>64, p_ash_height => 15,p_sql_height=>8 ))
select * from table(moats.top(p_refresh_rate => &&V_REFRESH,p_screen_size=>&&V_SCREEN, p_ash_height => 15,p_sql_height=>8 ))
/
--
--   function top (
--            p_refresh_rate    in integer default null,
--            p_screen_size     in integer default null,
--            p_ash_height      in integer default null,
--            p_sql_height      in integer default null,
--            p_ash_window_size in integer default null
--            ) return moats_output_ntt pipelined is
--   gc_max_screen_size      constant pls_integer     := 100;
--   gc_default_screen_size  constant pls_integer     := 40;
--   gc_default_ash_height   constant pls_integer     := 13;
--   gc_default_sql_height   constant pls_integer     := 8;
--   gc_ash_graph_length     constant pls_integer     := 86;
--   gc_screen_width         constant pls_integer     := 175;