#!/bin/bash

# Date: 02/18/2025
# Version: 0218.02
# Description: Create Docker volumes if they do not already exist
# Usage: ./build_storage.sh volume1 volume2 volume3

# Function to check if a Docker volume exists
volume_exists() {
    docker volume ls --format "{{.Name}}" | grep -q "^${1}$"
}

# Function to create the volume if it doesn't exist
create_volume() {
    if volume_exists "$1"; then
        echo "Volume '${1}' already exists"
    else
        echo "Creating volume: ${1}"
        docker volume create "$1"
        echo "Volume '$1' created successfully."
    fi
}

# Check if at least one volume name is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <volume_name1> [<volume_name2> ... <volume_nameN>]"
    exit 1
fi

# Loop through all provided volume names and create them
for VOLUME_NAME in "$@"; do
    create_volume "$VOLUME_NAME"
done