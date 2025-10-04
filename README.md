
# caddy-authelia 🚦🔐

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE) [![Docker Compose](https://img.shields.io/badge/Docker%20Compose-v2-blue.svg)](https://docs.docker.com/compose/) [![Compose Valid](https://github.com/msfx07/caddy-authelia-Local-Caddy-Authelia-Dev-Stack-/actions/workflows/compose-validate.yml/badge.svg)](https://github.com/msfx07/caddy-authelia-Local-Caddy-Authelia-Dev-Stack-/actions) [![Makefile](https://img.shields.io/badge/Makefile-available-brightgreen.svg)](https://github.com/msfx07/caddy-authelia-Local-Caddy-Authelia-Dev-Stack-/actions) 

Lightweight local development stack combining Caddy (reverse proxy) and Authelia (authentication/authorization) managed with Docker Compose and convenience Makefile scripts. ⚙️🔒

This repository provides a ready-to-run example for running Caddy and Authelia together on a local machine using Docker. It is intended for development, testing, and learning purposes — not as a production deployment.

## Table of Contents

- [Features](#features)
- [Prerequisites](#prerequisites)
- [Quick start](#quick-start)
- [Configuration & secrets](#configuration--secrets)
- [Common tasks (Make targets)](#common-tasks-make-targets)
- [Files of interest](#files-of-interest)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

---

## Features ✨

- Caddy as HTTPS reverse proxy (Caddyfile in repository)
- Authelia for forward authentication (config in `config/authelia/`)
- Docker Compose orchestration and helper `Makefile` targets for common workflows
- Helper scripts for generating secrets and validating/reloading configuration

---

## Prerequisites ✅

- Docker Engine (20.10+) and either Docker Compose V2 (`docker compose`) or legacy `docker-compose`
- make
- sudo (or add your user to the `docker` group) when running scripts/Make targets that require it

On most Linux distributions you can follow Docker's official install instructions. This project expects Docker to be able to create an external Docker network and named volumes.

---

## Quick start 🚀

1. Clone the repository and change into it:

   git clone https://github.com/msfx07/caddy-authelia-Local-Caddy-Authelia-Dev-Stack-.git caddy-authelia && cd caddy-authelia

2. Generate Authelia secrets (creates a `.env` file). DO NOT commit the `.env` file.

   ./scripts/gen_secrets.sh

   Or use the Make target:

   make authelia-gen-secrets

3. Build network, volumes and pull images:

   make build

4. Add the repository's local host entries to `/etc/hosts` for the sample domains used in `Caddyfile`:

   sudo ./scripts/add_local_hosts.sh

5. Start services:

   make start

6. Load Caddy config file into container

   make caddy-config-update
   make caddy-validate

7. Open a browser to the example sites (these names are used in the bundled `Caddyfile`):

- https://test.sandbox99.local (example site protected by Authelia)
- https://auth0.sandbox99.local (Authelia endpoint)

Default credentials

The example Authelia users file (`config/authelia/users.yml`) includes a default user for testing:

- Username: `admin`
- Password: `admin`

This account is provided for local development and testing only. Change or remove this example user and update credentials before publishing or using this setup in any less-trusted environment.


💡 Notes
- The compose file expects external Docker volumes and a network named `caddy_net0`. The `make build` target runs helper scripts (`build_network.sh` and `build_storage.sh`) to create them.
- The repository uses internal TLS (`tls internal`) for the local domains; this is suitable for development only.

---

## Configuration & secrets 🔑

- Authelia configuration lives in `config/authelia/configuration.yml` and user data in `config/authelia/users.yml`.
- Caddy configuration is in the repository `Caddyfile` and additional security snippets are in `config/caddy_security.conf`.
- Secrets (session secret, storage encryption key, JWT secret) are generated into a local `.env` file by `./scripts/gen_secrets.sh`. The Makefile and compose setup read from `.env`.

Security reminder: never commit `.env` or any real secrets into source control. Treat the generated `.env` and any files in `config/authelia/secrets/` as sensitive.

---

## Common tasks (Make targets) 🛠️

- make build — create network and volumes, pull images
- make start — start all services (uses `docker compose up -d`)
- make stop — stop services
- make restart — restart services
- make clean — remove containers/images/volumes/networks created by this project
- make prune — interactive/prudent system prune (see Makefile for details)
- make caddy-validate — validate the repository `Caddyfile`
- make caddy-config-update — copy Caddy config into the caddy config volume, validate and reload
- make authelia-gen-secrets — generate `.env` with secrets for Authelia
- make authelia-validate-config — validate Authelia configuration within the Authelia container
- make logs-caddy / make logs-authelia — show last logs for each service

Example: quickly generate secrets, build and run:

   ./scripts/gen_secrets.sh
   make build
   sudo ./scripts/add_local_hosts.sh
   make start

---

## Files of interest 📂

- `docker-compose.yml` — Compose definition for `caddy` and `authelia` services
- `Caddyfile` — main Caddy configuration used by the container
- `config/caddy_security.conf` — Caddy security headers/snippets imported by `Caddyfile`
- `config/authelia/configuration.yml` — Authelia configuration
- `config/authelia/users.yml` — example users database for file-backed authentication
- `scripts/` — helper scripts (secret generation, validate/reload Caddy, host setup, etc.)
- `Makefile` — a set of convenience targets that wrap common Docker and script operations

---

## Troubleshooting 🐞

- Docker permission errors: run Make targets with `sudo` or add your user to the `docker` group.
- If the external volumes or network are missing, run `make build` (this runs `build_network.sh` and `build_storage.sh`).
- Caddy reload fails: run `./scripts/validate_caddy.sh` to validate the `Caddyfile` locally, then `./scripts/reload_caddy.sh` to attempt a graceful reload.
- Authelia config validation: `make authelia-validate-config` runs `authelia validate-config` inside the container.
- Logs: `make logs-caddy` and `make logs-authelia` show recent logs.

If you hit issues not documented here, open an issue with logs and a short description of steps to reproduce.

---

## Contributing 🤝

Contributions are welcome. If you want to improve the repository:

1. Fork the repository and create a branch for your change.
2. Make small, well-scoped commits with clear messages.
3. Open a pull request describing the change and why it helps.

Please do not include secrets or credentials in commits.

---

## License 📄

This project is licensed under the MIT License — see the `LICENSE` file for details.
