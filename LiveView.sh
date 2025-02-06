#!/bin/bash

# USER VARIABLES
CONTAINER_NAME="midnight-node-docker-midnight-node-testnet-1"
MIDNIGHT_PORT="<PORT>"
RPC_URL="http://127.0.0.1:<PORT>" ## enter localhost or 127.0.0.1 with appropriate port
METRICS_URL="http://127.0.0.1:<PORT>/metrics" ## enter localhost or 127.0.0.1 with appropriate port

# Color codes
GREEN="\033[1;32m"
DARK_GREEN="\033[0;32m"  # Standard Dark Green
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
RED="\033[1;31m"
CYAN="\033[1;36m"
OLIVE="\033[38;5;58m"
WHITE="\033[1;37m"
GREY="\033[1;30m"  # Light Grey
DARK_GREY="\033[0;37m"  # Dark Grey
RESET="\033[0m"


# ==================================================================
# SCRIPT
# ==================================================================

# Convert hex to decimal safely
hex_to_decimal() {
    local hex_value=$1
    if [[ $hex_value =~ ^0x[0-9a-fA-F]+$ ]]; then
        printf "%d\n" "$hex_value"
    else
        echo "N/A"
    fi
}

# Function to fetch peer list and display it properly
show_peers() {
    clear
    echo -e "\n    🔍 Connected Peers:"
    echo "    ----------------------------------------------"

    PEERS_JSON=$(docker exec -it "$CONTAINER_NAME" curl -s -X POST \
        --data '{"jsonrpc":"2.0","method":"system_peers","params":[],"id":1}' \
        -H "Content-Type: application/json" "$RPC_URL" 2>/dev/null)

    echo "$PEERS_JSON" | jq -r '
        .result[] |
        "    🔹 Peer ID: " + .peerId + "\n" +
        "       🔹 Role: " + .roles + "\n" +
        "       🔹 Best Block: " + (.bestNumber | tostring) + "\n" +
        "    ----------------------------------------------"
    '

    echo -e "\n    [r] Return to Main Display | [q] Quit"
}

# Function to fetch data (optimized for performance)
fetch_data() {
    # Get Uptime
    UPTIME=$(uptime -p)

    # Fetch Midnight Node Version (cached to reduce calls)
    if [[ -z "$NODE_VERSION" ]]; then
        NODE_VERSION=$(docker exec -it "$CONTAINER_NAME" curl -s -X POST \
            --data '{"jsonrpc":"2.0","id":1,"method":"system_version","params":[]}' \
            -H "Content-Type: application/json" "$RPC_URL" 2>/dev/null | jq -r '.result' || echo "Unknown")
    fi

    # Fetch latest block details via RPC
    LATEST_BLOCK_JSON=$(docker exec -it "$CONTAINER_NAME" curl -s -X POST \
        --data '{"jsonrpc":"2.0","id":1,"method":"chain_getBlock","params":[]}' \
        -H "Content-Type: application/json" "$RPC_URL" 2>/dev/null || echo "{}")

    NETWORK_LATEST_BLOCK=$(echo "$LATEST_BLOCK_JSON" | jq -r '.result.block.header.number' 2>/dev/null || echo "0")
    NETWORK_LATEST_BLOCK=$(hex_to_decimal "$NETWORK_LATEST_BLOCK")

    # Get Finalized Block Hash
    FINALIZED_BLOCK_HASH=$(docker exec -it "$CONTAINER_NAME" curl -s -X POST \
        --data '{"jsonrpc":"2.0","id":1,"method":"chain_getFinalizedHead","params":[]}' \
        -H "Content-Type: application/json" "$RPC_URL" 2>/dev/null | jq -r '.result' || echo "0x0")

    # Fetch Finalized Block Details using Hash
    FINALIZED_BLOCK_JSON=$(docker exec -it "$CONTAINER_NAME" curl -s -X POST \
        --data '{"jsonrpc":"2.0","id":1,"method":"chain_getBlock","params":["'"$FINALIZED_BLOCK_HASH"'"]}' \
        -H "Content-Type: application/json" "$RPC_URL" 2>/dev/null || echo "{}")

    MY_FINALIZED_BLOCK=$(echo "$FINALIZED_BLOCK_JSON" | jq -r '.result.block.header.number' 2>/dev/null || echo "0")
    MY_FINALIZED_BLOCK=$(hex_to_decimal "$MY_FINALIZED_BLOCK")

    # Fetch Peer Data
    PEERS_JSON=$(docker exec -it "$CONTAINER_NAME" curl -s -X POST \
        --data '{"jsonrpc":"2.0","method":"system_peers","params":[],"id":1}' \
        -H "Content-Type: application/json" "$RPC_URL" 2>/dev/null || echo "{}")

    TOTAL_PEERS=$(echo "$PEERS_JSON" | jq '.result | length' 2>/dev/null || echo "0")
   # Get Host CPU & Memory Usage (MUCH LIGHTER)
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
    MEM_USAGE=$(free -m | awk 'NR==2{printf "%.2f GiB", $3/1024}')

    # Ensure proper spacing for disk usage
    DISK_USAGE=$(df -h / | awk 'NR==2 {print " " $5}')

    # Get Sync Percentage
    if [[ "$NETWORK_LATEST_BLOCK" -gt 0 && "$MY_FINALIZED_BLOCK" -gt 0 ]]; then
        SYNC_PERCENTAGE=$(echo "scale=2; ($MY_FINALIZED_BLOCK / $NETWORK_LATEST_BLOCK) * 100" | bc)
    else
        SYNC_PERCENTAGE="N/A"
    fi

    # Fetch Blocks Validated Using `/metrics`
    BLOCKS_VALIDATED=$(docker exec -it "$CONTAINER_NAME" curl -s $METRICS_URL | grep substrate_proposer_block_constructed_count | awk '{print $2}')
}

# Function to display the main live view
display_status() {
    clear
    echo -e "\n   ${RESET} 🔵 Midnight Node Monitor - Testnet     |   ⏳ Uptime: $UPTIME\t\t"
    echo -e "\n    🚀 Testnet (${BLUE}Version: $NODE_VERSION${RESET})   |   📡 Port: $MIDNIGHT_PORT"
    echo "    _____________________________________________________________________________________"
    echo "    -------------------------------------------------------------------------------------"
    echo -e "    | 🌍 Network Target Block: ${WHITE} $NETWORK_LATEST_BLOCK ${RESET}"
    echo -e "    | 📌 Finalized Block: ${WHITE} $MY_FINALIZED_BLOCK ${RESET}"
    echo -e "    | 📊 Sync Status: ${DARK_GREEN} $SYNC_PERCENTAGE% ${RESET}"
    echo "    ---------------------------------------------------------------"
    echo -e "    | 👥 Peers Connected: ${CYAN} $TOTAL_PEERS ${RESET}"
    echo "    ---------------------------------------------------------------"
    echo -e "    | 🔥 Host CPU Usage: ${YELLOW} $CPU_USAGE% ${RESET}"
    echo -e "    | 💾 Host Memory: ${YELLOW} $MEM_USAGE ${RESET}"
    echo -e "    | 🖴  Host Disk Usage: ${YELLOW} $DISK_USAGE ${RESET}"
    echo "    ---------------------------------------------------------------"
    echo -e "    | 📦 Blocks Validated: ${DARK_GREEN} $BLOCKS_VALIDATED ${RESET}"
    echo "    _____________________________________________________________________________________"
    echo -e "    | ${GREY}[q] Quit | [p] Peers List | [r] Refresh"

}

# Start loop to refresh data
while true; do
    fetch_data
    display_status
    sleep 10  # Reduce polling rate to lower CPU usage

    # Read user input
    read -rsn1 -t 10 input
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
    fi
done
