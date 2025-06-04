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
done

git config --global user.name 'ytubot'
git config --global user.email 'ytu-developers-group+githubapi@york.ac.uk'
git add -A --force logs/
git commit -am '[Automated] Update Health Check Logs'
