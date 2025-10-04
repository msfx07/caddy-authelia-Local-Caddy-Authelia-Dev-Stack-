#!/bin/bash

# Define network variables globally
BRIDGE_NETWORK="caddy_net0"
SUBNET="10.0.1.0/24"
GATEWAY="10.0.1.254"


if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed or not in your PATH."
    exit 1
fi

# Function to check if a Docker network exists
network_exists() {
    docker network ls --format "{{.Name}}" | grep -q "^${BRIDGE_NETWORK}$"
}

# Function to create the network if it doesn't exist
build_network() {
    if network_exists; then
        echo "Bridge network '${BRIDGE_NETWORK}' already exists"
    else
        echo "Creating bridge network: ${BRIDGE_NETWORK}"
        if docker network create \
            --driver=bridge \
            --opt com.docker.network.bridge.name="$BRIDGE_NETWORK" \
            --opt com.docker.network.bridge.enable_icc=true \
            --opt com.docker.network.bridge.enable_ip_masquerade=true \
            --opt com.docker.network.driver.mtu=1500 \
            --subnet="$SUBNET" \
            --gateway="$GATEWAY" \
            "$BRIDGE_NETWORK"; then
            echo "Network bridge '$BRIDGE_NETWORK' created successfully."
        else
            echo "Error creating network bridge '$BRIDGE_NETWORK'."
            return 1 # Indicate failure
        fi
    fi
}

# Run the function
build_network