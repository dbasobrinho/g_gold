for mes in 06 07; do
  if [ "$mes" = "06" ]; then
    dias=$(seq -w 26 30)
  else
    dias=$(seq -w 1 25)
  fi

  for dia in $dias; do
    data="2025${mes}${dia}"
    echo -n "$data : "
    sh rep_monitor_cpu2.sh | grep -i "$data" | wc -l
  done
done