#!/usr/bin/env bash
# Attempting to update the block ----------------

# ─── USER VARIABLES ────────────────────────────────
CONTAINER_NAME="midnight"
PORT="9944"
USE_DOCKER=true

# ─── PATHS ────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$HOME/midnight-node-docker/.env"
KEYS_FILE="$SCRIPT_DIR/partner-chains-public-keys.json"
RPC_URL="http://127.0.0.1:$PORT"

# ─── COLORS ───────────────────────────────────────
GREEN="\033[1;32m"; RED="\033[1;31m"; YELLOW="\033[1;33m"
CYAN="\033[1;36m"; WHITE="\033[1;37m"; RESET="\033[0m"

declare -A KEY_ITEMS=( ["grandpa_pub_key"]="gran" ["aura_pub_key"]="aura" ["sidechain_pub_key"]="crch" )
declare -A KEY_RESULTS

execute_command(){
  if [[ "$USE_DOCKER" == true ]]; then
    docker exec "$CONTAINER_NAME" "$@"
  else
    eval "$@"
  fi
}

fetch_data(){
  NODE_KEY=$(grep -E '^NODE_KEY=' "$ENV_FILE" | cut -d= -f2 | tr -d '"')
  UPTIME=$(uptime -p)
  CONTAINER_START=$(docker inspect -f '{{.State.StartedAt}}' "$CONTAINER_NAME" | cut -d'.' -f1)
  START_FMT=$(date -d "$CONTAINER_START" +"%Y-%m-%d %H:%M:%S")

  CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print $2+$4}')
  MEM=$(free -m | awk 'NR==2{printf "%.2f GiB",$3/1024}')
  DISK=$(df -h / | awk 'NR==2{print $5}')

  PEERS=$(execute_command curl -s -X POST \
    -d '{"jsonrpc":"2.0","id":1,"method":"system_peers","params":[]}' \
    -H "Content-Type:application/json" "$RPC_URL" | jq '.result|length')

  # Latest block (hex → decimal)
  LATEST_HEX=$(execute_command curl -s -X POST \
    -d '{"jsonrpc":"2.0","id":1,"method":"chain_getHeader","params":[]}' \
    -H "Content-Type:application/json" "$RPC_URL" | jq -r '.result.number')
  NETWORK_LATEST_BLOCK=$((LATEST_HEX))

  # Finalized block (hex → decimal)
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


  # Block broduction
  BLOCKS_PRODUCED=$(curl -s http://127.0.0.1:9615/metrics | awk -F' ' '/substrate_tasks_ended_total{.*basic-authorship-proposer/ {print $2}')
  # Alternate metric (optional): 
  # BLOCKS_PRODUCED=$(curl -s http://127.0.0.1:9615/metrics | awk -F' ' '/substrate_proposer_block_constructed_count/ {print $2}')

  # Key‑check
  for name in "${!KEY_ITEMS[@]}"; do
    pub=$(jq -r ".${name}" "$KEYS_FILE")
    KEY_RESULTS[$name]=$(execute_command curl -s \
      -d '{"jsonrpc":"2.0","id":1,"method":"author_hasKey","params":["'"$pub"'","'"${KEY_ITEMS[$name]}"'"]}' \
      -H "Content-Type:application/json" "$RPC_URL" | jq -r '.result')
  done

  NODE_VERSION=$(execute_command curl -s -X POST \
    -d '{"jsonrpc":"2.0","id":1,"method":"system_version","params":[]}' \
    -H "Content-Type:application/json" "$RPC_URL" | jq -r '.result')
}

display_status(){
  clear
  echo -e "\n  |     ${CYAN}🔵 Midnight Node Monitor - Version: ${WHITE}$NODE_VERSION${RESET}"
  echo -e "  |  LiveView version 0.1.2"
  echo "  |================================================================"
  echo -e "  | ⏳ Uptime:           ${YELLOW}$UPTIME${RESET}"
  echo -e "  | 🚀 Start Time:       ${GREEN}$START_FMT${RESET}"
  echo "  |----------------------------------------------------------------"
  echo -e "  | 🔑 Node Key: ${WHITE}$NODE_KEY${RESET}"
  echo -e "  | 📡 RPC Port:         ${WHITE}$PORT${RESET}"
  echo "  |----------------------------------------------------------------"
  echo -e "  | 🔐 Keys:"
  for key in grandpa_pub_key aura_pub_key sidechain_pub_key; do
      status=${KEY_RESULTS[$key]}
      pub=$(jq -r ".${key}" "$KEYS_FILE")
      short_key="${pub:0:18}..."
      if [[ "$status" == "true" ]]; then
          printf "  |    %-18s: %b✓ %s%b\n" "$key" "$GREEN" "$short_key" "$RESET"
      else
          printf "  |    %-18s: %b✗ Key not found%b\n" "$key" "$RED" "$RESET"
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
  echo "  | [q] Quit | [r] Refresh"
}

show_peers(){
  clear
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
  echo "  |  [r] Return | [p} Peer-list | [q] Quit"
  while true; do
    read -rsn1 input
    case "$input" in
      r) return ;;
      q) clear && exit ;;
    esac
  done
}

while true; do
  fetch_data
  display_status
  read -rsn1 -t 2 key
  case "$key" in
    q) clear && exit ;;
    p) show_peers ;;
  esac
done
