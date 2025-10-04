#!/bin/bash

# Helper script to generate an Argon2 password hash for Authelia users_database.yml
# Usage: ./generate_password.sh <password>

if [ $# -ne 1 ]; then
    echo "Usage: $0 <password>"
    exit 1
fi

PASSWORD="$1"

# Run the hash command inside the Authelia Docker container
# Assumes the container is named 'authelia' and is running
docker exec authelia authelia crypto hash generate argon2 --password "$PASSWORD"