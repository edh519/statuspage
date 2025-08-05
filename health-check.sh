KEYSARRAY=()
URLSARRAY=()

urlsConfig="./urls.cfg"
echo "Reading $urlsConfig"
while read -r line; do
  echo "  $line"
  IFS='=' read -ra TOKENS <<< "$line"
  KEYSARRAY+=("${TOKENS[0]}")
  URLSARRAY+=("${TOKENS[1]}")
done < "$urlsConfig"

echo "***********************"
echo "Starting health checks with ${#KEYSARRAY[@]} configs:"

mkdir -p logs

for (( index=0; index < ${#KEYSARRAY[@]}; index++ )); do
  key="${KEYSARRAY[index]}"
  url="${URLSARRAY[index]}"
  
  # Remove carriage return characters (in case of Windows line endings)
  url="${url//$'\r'/}"

  echo "  $key=$url"
  for i in {1..4}; do
    response=$(curl --write-out '%{http_code}' --silent --output /dev/null "$url")
    if [[ "$response" -eq 200 || "$response" -eq 202 || "$response" -eq 301 || "$response" -eq 302 || "$response" -eq 307 ]]; then
      result="success"
      break
    else
      result="failed"
    fi
    sleep 5
  done

  dateTime=$(date +'%Y-%m-%d %H:%M')
  echo "$dateTime, $result" >> "logs/${key}_report.log"
  # Keep only the last 2000 lines
  tail -2000 "logs/${key}_report.log" > "logs/${key}_report.tmp" && mv "logs/${key}_report.tmp" "logs/${key}_report.log"

  # Log failed systems to failed_systems.log (email notifications)
  if [[ "$result" == "failed" ]]; then
    # if exists update timestamp, keep emailsent as is (every hr, compared in notify_failed_systems.sh)
    if grep -q "^$key," logs/failed_systems.log 2>/dev/null; then
      awk -F',' -v k="$key" -v t="$dateTime" 'BEGIN{OFS=","} {if($1==k){$2=t} print $0}' logs/failed_systems.log > logs/failed_systems.tmp && mv logs/failed_systems.tmp logs/failed_systems.log
    else
      echo "$key,$dateTime," >> logs/failed_systems.log
    fi
  else
    # Remove from failed_systems.log if it exists (system recovered)
    if [[ -f logs/failed_systems.log ]]; then
      if grep -q "^$key," logs/failed_systems.log 2>/dev/null; then
        grep -v "^$key," logs/failed_systems.log > logs/failed_systems.tmp 2>/dev/null || true
        if [[ -s logs/failed_systems.tmp ]]; then
          mv logs/failed_systems.tmp logs/failed_systems.log
        else
          # If tmp file is empty, remove the original file
          rm -f logs/failed_systems.log logs/failed_systems.tmp
        fi
      fi
    fi
  fi
done