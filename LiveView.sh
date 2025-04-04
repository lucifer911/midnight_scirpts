#!/usr/bin/env bash

# ─── USER VARIABLES ────────────────────────────────
CONTAINER_NAME="midnight"
PORT="9944"
USE_DOCKER=true

# ─── PATHS ─────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$HOME/midnight-node-docker/.env"
KEYS_FILE="$SCRIPT_DIR/partner-chains-public-keys.json"
RPC_URL="http://127.0.0.1:$PORT"

# ─── COLORS ───────────────────────────────────────
GREEN="\033[1;32m"; RED="\033[1;31m"; YELLOW="\033[1;33m"
CYAN="\033[1;36m"; WHITE="\033[1;37m"; BLUE="\033[1;34m"; RESET="\033[0m"

declare -A KEY_ITEMS=( ["grandpa_pub_key"]="gran" ["aura_pub_key"]="aura" ["sidechain_pub_key"]="crch" )
declare -A KEY_RESULTS
declare -A PUBLIC_KEYS

execute_command(){
  if [[ "$USE_DOCKER" == true ]]; then
    docker exec "$CONTAINER_NAME" "$@"
  else
    eval "$@"
  fi
}

fetch_static_data(){
  NODE_KEY=$(grep -E '^NODE_KEY=' "$ENV_FILE" | cut -d= -f2 | tr -d '"')
  for key in "${!KEY_ITEMS[@]}"; do
    PUBLIC_KEYS[$key]=$(jq -r ".${key}" "$KEYS_FILE")
  done
}

fetch_dynamic_data(){
  UPTIME=$(uptime -p)
  CONTAINER_START=$(docker inspect -f '{{.State.StartedAt}}' "$CONTAINER_NAME" 2>/dev/null | cut -d'.' -f1)
  START_FMT=$(date -d "$CONTAINER_START" +"%Y-%m-%d %H:%M:%S" 2>/dev/null)

  CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print $2+$4}')
  MEM=$(free -m | awk 'NR==2{printf "%.2f GiB",$3/1024}')
  DISK=$(df -h / | awk 'NR==2{print $5}')

  PEERS=$(execute_command curl -s -X POST \
    -d '{"jsonrpc":"2.0","id":1,"method":"system_peers","params":[]}' \
    -H "Content-Type:application/json" "$RPC_URL" | jq '.result|length')

  LATEST_HEX=$(execute_command curl -s -X POST \
    -d '{"jsonrpc":"2.0","id":1,"method":"chain_getHeader","params":[]}' \
    -H "Content-Type:application/json" "$RPC_URL" | jq -r '.result.number')
  NETWORK_LATEST_BLOCK=$((LATEST_HEX))

  FINALIZED_HASH=$(execute_command curl -s -X POST \
    -d '{"jsonrpc":"2.0","id":1,"method":"chain_getFinalizedHead","params":[]}' \
    -H "Content-Type:application/json" "$RPC_URL" | jq -r '.result')
  FINALIZED_HEX=$(execute_command curl -s -X POST \
    -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"chain_getHeader\",\"params\":[\"$FINALIZED_HASH\"]}" \
    -H "Content-Type:application/json" "$RPC_URL" | jq -r '.result.number')
  FINALIZED_BLOCK=$((FINALIZED_HEX))

  SYNC_TARGET=$(execute_command curl -s -X POST \
    -d '{"jsonrpc":"2.0","id":1,"method":"system_syncState","params":[]}' \
    -H "Content-Type:application/json" "$RPC_URL" | jq -r '.result.highestBlock')

  if [[ $SYNC_TARGET -gt 0 ]]; then
    SYNC_PERCENTAGE=$(awk "BEGIN{printf \"%.2f\",($NETWORK_LATEST_BLOCK/$SYNC_TARGET)*100}")
  else
    SYNC_PERCENTAGE="N/A"
  fi

  BLOCKS_PRODUCED=$(curl -s http://127.0.0.1:9615/metrics | awk -F' ' '/substrate_tasks_ended_total{.*basic-authorship-proposer/ {print $2}')

  NODE_VERSION=$(execute_command curl -s -X POST \
    -d '{"jsonrpc":"2.0","id":1,"method":"system_version","params":[]}' \
    -H "Content-Type:application/json" "$RPC_URL" | jq -r '.result')
}

check_keys(){
  for name in "${!KEY_ITEMS[@]}"; do
    pub=${PUBLIC_KEYS[$name]}
    KEY_RESULTS[$name]=$(execute_command curl -s \
      -d '{"jsonrpc":"2.0","id":1,"method":"author_hasKey","params":["'"$pub"'","'"${KEY_ITEMS[$name]}"'"]}' \
      -H "Content-Type:application/json" "$RPC_URL" | jq -r '.result')
  done
}

display_dashboard(){
  tput reset
  tput cup 0 0
  echo -e "\n  |     ${CYAN}🔵 Midnight Node Monitor - Version: ${WHITE}$NODE_VERSION${RESET}"
  echo -e "  |  LiveView version 0.2.0"
  echo "  |================================================================"
  echo -e "  | ⏳ Uptime:           ${YELLOW}$UPTIME${RESET}"
  echo -e "  | 🚀 Start Time:       ${GREEN}$START_FMT${RESET}"
  echo "  |----------------------------------------------------------------"
  echo -e "  | 📡 RPC Port:         ${WHITE}$PORT${RESET}"
  echo "  |----------------------------------------------------------------"
  echo -e "  | 🔐 Keys:"
  for key in "${!KEY_ITEMS[@]}"; do
      status=${KEY_RESULTS[$key]}
      pub=${PUBLIC_KEYS[$key]}
      label="$key"
      if [[ "$key" == "sidechain_pub_key" ]]; then
        label="Sidechain Public Key"
      fi
      short_key="${pub:0:18}..."
      if [[ "$status" == "true" ]]; then
          printf "  |    %-22s: %b✓ %s%b\n" "$label" "$GREEN" "$short_key" "$RESET"
      else
          printf "  |    %-22s: %b✗ Key not found%b\n" "$label" "$RED" "$RESET"
      fi
  done
  echo "  |----------------------------------------------------------------"
  echo -e "  | 🌍 Latest Block:     ${GREEN}$NETWORK_LATEST_BLOCK${RESET}"
  echo -e "  | ✅ Finalized Block:  ${GREEN}$FINALIZED_BLOCK${RESET}"
  echo -e "  | 📊 Sync:             ${CYAN}$SYNC_PERCENTAGE%${RESET}"
  echo -e "  | 👥 Peers:            ${YELLOW}$PEERS${RESET}"
  echo "  |----------------------------------------------------------------"
  echo -e "  | 🔥 CPU:              ${RED}$CPU%${RESET}"
  echo -e "  | 💾 MEM:              ${BLUE}$MEM${RESET}"
  echo -e "  | 💽 Disk:             ${CYAN}$DISK${RESET}"
  echo -e "  | 📦 Blocks Produced:  ${BLUE}$BLOCKS_PRODUCED${RESET}"
  echo "  |================================================================"
  echo "  | [q] Quit | [p] Peers"
}

show_peers(){
  tput reset
  echo -e "\n  |  🔍 Connected Peers:"
  echo "  |  --------------------------------------------------------------"
  PEERS_JSON=$(execute_command curl -s -X POST \
    -d '{"jsonrpc":"2.0","id":1,"method":"system_peers","params":[]}' \
    -H "Content-Type:application/json" "$RPC_URL")
  if [[ -z "$PEERS_JSON" || "$PEERS_JSON" == "null" ]]; then
    echo "  |  ❌ No peers connected."
  else
    echo "$PEERS_JSON" | jq -r '.result[] | "  |  🔹 Peer ID: " + .peerId + " | Role: " + .roles + " | Best Block: " + (.bestNumber|tostring)'
  fi
  echo "  |  --------------------------------------------------------------"
  echo "  |  [r] Return | [q] Quit"
  # tput reset
  while true; do
    read -rsn1 input
    case "$input" in
      r) return ;;
      q) clear && exit ;;
    esac
  done
}

tput civis  # Hide cursor
trap "tput cnorm; clear; exit" SIGINT SIGTERM

fetch_static_data
check_keys

while true; do
  fetch_dynamic_data
  display_dashboard
  read -rsn1 -t 1 key
  case "$key" in
    q) tput cnorm; clear; exit ;;
    p) show_peers ;;
  esac
done
