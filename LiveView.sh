#!/bin/bash

# USER VARIABLES
CONTAINER_NAME="midnight-node-docker-midnight-node-testnet-1"
PORT="9944"  # Set manually if needed (Default: 9944)
METRICS_URL="http://127.0.0.1:9615/metrics" # Set manually if needed (Default: 9615)

# Auto-detect Midnight node port from logs if not set manually
if [[ -z "$PORT" ]]; then
    PORT=$(docker logs "$CONTAINER_NAME" 2>&1 | grep -oP 'Listening for RPC on \K\d+' | head -1)
    if [[ -z "$PORT" ]]; then
        PORT="9944"  # Default to 9944 if auto-detection fails
    fi
fi

RPC_URL="http://127.0.0.1:$PORT"

# Color codes for better UI
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
RED="\033[1;31m"
CYAN="\033[1;36m"
RESET="\033[0m"

# Fetch Midnight Node Version (cached to reduce API calls)
NODE_VERSION=$(docker exec "$CONTAINER_NAME" curl -s -X POST \
    --data '{"jsonrpc":"2.0","id":1,"method":"system_version","params":[]}' \
    -H "Content-Type: application/json" "$RPC_URL" 2>/dev/null | jq -r '.result' || echo "Unknown")

# Function to fetch node data
fetch_data() {

    # Get NODE_KEY from .env file
    NODE_KEY=$(grep '^NODE_KEY=' /home/midnight/midnight-node-docker/.env | cut -d '=' -f2 | tr -d '"')

    # Get Uptime
    UPTIME=$(uptime -p)

    # Get Midnight Node Container Start Time
    CONTAINER_START_TIME=$(docker inspect -f '{{.State.StartedAt}}' "$CONTAINER_NAME" | cut -d '.' -f1)

    # Convert Start Time to Human-Readable Format
    CONTAINER_START_TIME_FORMATTED=$(date -d "$CONTAINER_START_TIME" +"%Y-%m-%d %H:%M:%S")

    # Get Host Machine Stats
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
    MEM_USAGE=$(free -m | awk 'NR==2{printf "%.2f GiB", $3/1024}')
    DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}')

    # Get Peers Count
    PEERS_JSON=$(docker exec "$CONTAINER_NAME" curl -s -X POST \
        --data '{"jsonrpc":"2.0","method":"system_peers","params":[],"id":1}' \
        -H "Content-Type: application/json" "$RPC_URL")
    TOTAL_PEERS=$(echo "$PEERS_JSON" | jq '.result | length')

    if [[ -z "$TOTAL_PEERS" || "$TOTAL_PEERS" -lt 1 ]]; then
        TOTAL_PEERS="No active peers"
    fi

    # Get Finalized Block Hash & Number
    FINALIZED_DATA=$(docker exec "$CONTAINER_NAME" curl -s -X POST \
        --data '{"jsonrpc":"2.0","method":"chain_getFinalizedHead","params":[],"id":1}' \
        -H "Content-Type: application/json" "$RPC_URL")
    FINALIZED_HASH=$(echo "$FINALIZED_DATA" | jq -r '.result')

    FINALIZED_BLOCK_DATA=$(docker exec "$CONTAINER_NAME" curl -s -X POST \
        --data "{\"jsonrpc\":\"2.0\",\"method\":\"chain_getHeader\",\"params\":[\"$FINALIZED_HASH\"],\"id\":1}" \
        -H "Content-Type: application/json" "$RPC_URL")
    FINALIZED_BLOCK=$(echo "$FINALIZED_BLOCK_DATA" | jq -r '.result.number' | xargs printf "%d\n")

    # Get Syncing Information
    SYNC_LOG=$(docker logs --tail 50 "$CONTAINER_NAME" 2>&1 | grep "Syncing" | tail -n 1)
    NETWORK_LATEST_BLOCK=$(echo "$SYNC_LOG" | grep -oP 'target=#\K\d+')
    MY_BEST_BLOCK=$(echo "$SYNC_LOG" | grep -oP 'best: #\K\d+')

    # Calculate Sync Percentage
    if [[ -n "$MY_BEST_BLOCK" && -n "$NETWORK_LATEST_BLOCK" && "$NETWORK_LATEST_BLOCK" -gt 0 ]]; then
        SYNC_PERCENTAGE=$(echo "scale=2; ($MY_BEST_BLOCK / $NETWORK_LATEST_BLOCK) * 100" | bc)
    else
        SYNC_PERCENTAGE="N/A"
    fi

    # Fetch Blocks Produced
    BLOCKS_PRODUCED=$(docker exec "$CONTAINER_NAME" curl -s $METRICS_URL | grep substrate_proposer_block_constructed_count | awk '{print $2}')
}

# Function to display the main dashboard
display_status() {
    clear
    echo -e "\n    ${CYAN}🔵 Midnight Node Monitor - Testnet - Version: ${WHITE}$NODE_VERSION${RESET}"
    echo "    =============================================================="
    echo -e "    ⏳ ${YELLOW}Uptime:${RESET}                $UPTIME"
    echo -e "    🚀 ${GREEN}Container Start Time:${RESET}   $CONTAINER_START_TIME_FORMATTED"
    echo "    --------------------------------------------------------------"
    echo -e "    🔑 ${YELLOW}Node Key:${RESET}"
    echo -e "       $NODE_KEY"
    echo -e "    📡 ${YELLOW}Port:${RESET}                  $PORT"
    echo "    --------------------------------------------------------------"
    echo -e "    🌍 ${GREEN}Network Target Block:${RESET}   $NETWORK_LATEST_BLOCK"
    echo -e "    📌 ${GREEN}My Best Block:${RESET}          $MY_BEST_BLOCK"
    echo -e "    ✅ ${GREEN}Finalized Block:${RESET}        $FINALIZED_BLOCK"
    echo -e "    📊 ${CYAN}Sync Status:${RESET}            $SYNC_PERCENTAGE%"
    echo "    --------------------------------------------------------------"
    echo -e "    👥 ${YELLOW}Peers Connected:${RESET}        $TOTAL_PEERS"
    echo "    --------------------------------------------------------------"
    echo -e "    🔥 ${RED}Host CPU Usage:${RESET}         $CPU_USAGE%"
    echo -e "    💾 ${BLUE}Memory Usage:${RESET}           $MEM_USAGE"
    echo -e "    🖴 ${CYAN}Disk Usage:${RESET}             $DISK_USAGE"
    echo "    --------------------------------------------------------------"
    echo -e "    📦 ${BLUE}Blocks Produced:${RESET}        $BLOCKS_PRODUCED"
    echo "    =============================================================="
    echo -e "    [q] Quit | [p] Peers List | [r] Refresh"
}

# Function to show peers (No auto-refresh)
show_peers() {
    clear
    echo -e "\n    🔍 Connected Peers:"
    echo "    ----------------------------------------------"

    PEERS_JSON=$(docker exec "$CONTAINER_NAME" curl -s -X POST \
        --data '{"jsonrpc":"2.0","method":"system_peers","params":[],"id":1}' \
        -H "Content-Type: application/json" "$RPC_URL")

    if [[ -z "$PEERS_JSON" || "$PEERS_JSON" == "null" ]]; then
        echo "    ❌ No peers connected."
    else
        echo "$PEERS_JSON" | jq -r '
            .result[] |
            "    🔹 Peer ID: " + .peerId + "\n" +
            "       🔹 Role: " + .roles + "\n" +
            "       🔹 Best Block: " + (.bestNumber | tostring) + "\n" +
            "    ----------------------------------------------"
        '
    fi

    echo -e "\n    [r] Return to Main Display | [q] Quit"

    while true; do
        read -rsn1 input
        case "$input" in
            r) return ;;
            q) clear; echo "Exiting Midnight Node Monitor..."; exit 0 ;;
        esac
    done
}

# Main loop for updating the display
while true; do
    fetch_data
    display_status
    read -rsn1 -t 2 input
    case "$input" in
        q) clear; echo "Exiting Midnight Node Monitor..."; exit 0 ;;
        p) show_peers ;;
        r) fetch_data; display_status ;;
    esac
done
