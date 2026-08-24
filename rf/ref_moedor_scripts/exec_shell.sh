DIR_BASE="/media/sf_tmp/AUTO/20250728/2025100"

rm -f "$DIR_BASE"/*.log 2>/dev/null
rm -f "$DIR_BASE/STATUS.sucesso"  2>/dev/null
rm -f "$DIR_BASE/STATUS.erro" 2>/dev/null
touch "$DIR_BASE/STATUS.executar"
rm -rf "${DIR_BASE}.sucesso" 2>/dev/null 
rm -rf "${DIR_BASE}.erro" 2>/dev/null

DIR_BASE="/media/sf_tmp/AUTO/20250728/2025101"
rm -f "$DIR_BASE"/*.log 2>/dev/null
rm -f "$DIR_BASE/STATUS.sucesso"  2>/dev/null
rm -f "$DIR_BASE/STATUS.erro" 2>/dev/null
touch "$DIR_BASE/STATUS.executar"
rm -rf "${DIR_BASE}.sucesso" 2>/dev/null 
rm -rf "${DIR_BASE}.erro" 2>/dev/null

sh /media/sf_tmp/AUTO/exec_moedor_scripts_oracle.sh