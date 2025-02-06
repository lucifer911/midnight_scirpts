#!/bin/bash

# Midnight Node Container Name
CONTAINER_NAME="midnight-node-docker-midnight-node-testnet-1"

# Color codes
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
RED="\033[1;31m"
CYAN="\033[1;36m"
RESET="\033[0m"

# Function to fetch data
fetch_data() {
    # Get uptime
    UPTIME=$(uptime -p)

    # Get Midnight Node Version
    NODE_VERSION="Midnight Testnet v1.0"

    # Get Syncing Info from Logs
    SYNC_LOG=$(docker logs --tail 50 "$CONTAINER_NAME" 2>&1 | grep "Syncing" | tail -n 1)

    # Extract values from log
    NETWORK_LATEST_BLOCK=$(echo "$SYNC_LOG" | grep -oP 'target=#\K\d+')
    MY_BEST_BLOCK=$(echo "$SYNC_LOG" | grep -oP 'best: #\K\d+')
    MY_FINALIZED_BLOCK=$(echo "$SYNC_LOG" | grep -oP 'finalized #\K\d+')

    # Get Peers Info
    PEERS_JSON=$(docker exec -it "$CONTAINER_NAME" curl -s -X POST \
        --data '{"jsonrpc":"2.0","method":"system_peers","params":[],"id":1}' \
        -H "Content-Type: application/json" http://localhost:9944)

    TOTAL_PEERS=$(echo "$PEERS_JSON" | jq '.result | length')

    # Get CPU and Memory Usage
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
    MEM_USAGE=$(free -m | awk 'NR==2{printf "%.2f MB\n", $3}')

    # Get Disk Usage
    DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}')

    # Count Blocks Produced by My Node
    BLOCKS_PRODUCED=$(docker logs "$CONTAINER_NAME" 2>&1 | grep -c "Produced block")

    # Get Sync Percentage
    if [[ "$NETWORK_LATEST_BLOCK" -gt 0 && "$MY_BEST_BLOCK" -gt 0 ]]; then
        SYNC_PERCENTAGE=$(echo "scale=2; ($MY_BEST_BLOCK / $NETWORK_LATEST_BLOCK) * 100" | bc)
    else
        SYNC_PERCENTAGE="Unknown"
    fi
}

# Function to display the main live view
display_status() {
    clear
    echo -e "\n    ${CYAN}🔵 Midnight Node  -  (Testnet)  -  ${NODE_VERSION}${RESET}"
    echo "    ----------------------------------------------"
    echo -e "    ${YELLOW}⏳ Uptime:${RESET} $UPTIME\t\t${BLUE}📡 Port:${RESET} 9944"
    echo "    ----------------------------------------------"
    echo -e "    | ${GREEN}🌍 Network Target Block:${RESET} $NETWORK_LATEST_BLOCK"
    echo -e "    | ${GREEN}📌 My Best Block:${RESET} $MY_BEST_BLOCK"
    echo -e "    | ${GREEN}✅ My Finalized Block:${RESET} $MY_FINALIZED_BLOCK"
    echo -e "    | ${CYAN}📊 Sync Status:${RESET} $SYNC_PERCENTAGE%"
    echo "    ----------------------------------------------"
    echo -e "    | ${YELLOW}👥 Peers Connected:${RESET} $TOTAL_PEERS"
    echo "    ----------------------------------------------"
    echo -e "    | ${RED}🔥 CPU Usage:${RESET} $CPU_USAGE%\t"
    echo -e "    | ${BLUE}💾 Memory:${RESET} $MEM_USAGE MB\t"
    echo -e "    | ${CYAN}🖴 Disk Usage:${RESET} $DISK_USAGE"
    echo "    ----------------------------------------------"
    echo -e "    | ${GREEN}📦 Blocks Produced:${RESET} $BLOCKS_PRODUCED"
    echo "    ----------------------------------------------"
    echo -e "    | [q] Quit | [p] Peers List | [r] Refresh"
}

# Function to show peer list
show_peers() {
    clear
    echo -e "\n    ${CYAN}🔍 Connected Peers:${RESET}"
    echo "    ----------------------------------------------"

    echo "$PEERS_JSON" | jq -r '
        .result[] |
        "    🔹 ${BLUE}Peer ID:${RESET} " + .peerId + "\n" +
        "       🔹 ${GREEN}Role:${RESET} " + .roles + "\n" +
        "       🔹 ${YELLOW}Best Block:${RESET} " + (.bestNumber | tostring) + "\n" +
        "    ----------------------------------------------"
    '

    echo -e "\n    [r] Return to Main Display | [q] Quit"
}

# Start Live Updating Loop
fetch_data
display_status

while true; do
    # Auto-refresh every 2 seconds
    sleep 2
    fetch_data
    display_status &

    # Read keyboard input
    read -rsn1 -t 2 input
    if [[ "$input" == "q" ]]; then
        clear
        echo "Exiting Midnight Node Monitor..."
        exit 0
    elif [[ "$input" == "p" ]]; then
        show_peers
        read -rsn1 input
        if [[ "$input" == "r" ]]; then
            display_status
        fi
    elif [[ "$input" == "r" ]]; then
        fetch_data
        display_status
    fi
done
