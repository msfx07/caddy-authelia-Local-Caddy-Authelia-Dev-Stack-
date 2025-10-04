# Makefile for managing the caddy and authelia services/containers/images

COMPOSE_FILE ?= docker-compose.yml
# Docker Compose command: prefer 'docker compose' (Compose V2) if available,
# otherwise fall back to the legacy 'docker-compose' binary. Users may still
# override by passing DC=... on the make command line.
ifeq ($(origin DC), undefined)
DC := $(shell if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1 2>/dev/null; then echo "docker compose"; elif command -v docker-compose >/dev/null 2>&1; then echo "docker-compose"; else echo "docker-compose"; fi)
endif
CONTAINER ?=
NETWORK_SCRIPT ?= ./build_network.sh
STORAGE_SCRIPT ?= ./build_storage.sh
STORAGE_ARGS ?= caddy_data caddy_config authelia_data
SUDO ?= sudo
NETWORK_PATTERN ?= caddy_net0
CADDY_IMAGE ?= caddy:2.10.2
AUTHELIA_IMAGE ?= authelia/authelia:4.39.11
SCRIPTS_DIR := ./scripts
PRUNE_FORCE ?= no
REMOVE_FORCE ?= no

.PHONY: build start stop restart status logs-caddy logs-authelia clean prune help
.PHONY: caddy-config-update caddy-validate authelia-gen-secrets authelia-view-config authelia-view-users validate-config update-config

build:
	@echo "Checking if already built..."
	@if $(SUDO) docker network inspect caddy_net0 >/dev/null 2>&1 && $(SUDO) docker volume inspect caddy_data >/dev/null 2>&1 && $(SUDO) docker volume inspect caddy_config >/dev/null 2>&1 && $(SUDO) docker volume inspect authelia_data >/dev/null 2>&1 && $(SUDO) docker images --format '{{.Repository}}:{{.Tag}}' | grep -q '^caddy:2.10.2$' && $(SUDO) docker images --format '{{.Repository}}:{{.Tag}}' | grep -q '^authelia/authelia:4.39.11$'; then \
		echo "Already built. Network, volumes, and images are present."; \
		$(MAKE) --no-print-directory status; \
		exit 0; \
	fi
	@echo "Running network build script: $(SUDO) $(NETWORK_SCRIPT)";
	@$(SUDO) $(NETWORK_SCRIPT)
	@echo "Running storage build script: $(SUDO) $(STORAGE_SCRIPT) $(STORAGE_ARGS)";
	@$(SUDO) $(STORAGE_SCRIPT) $(STORAGE_ARGS)
	@echo "Pulling caddy image: $(CADDY_IMAGE)";
	@$(SUDO) docker pull $(CADDY_IMAGE) || echo "Warning: failed to pull $(CADDY_IMAGE)"
	@echo "Pulling authelia image: $(AUTHELIA_IMAGE)";
	@$(SUDO) docker pull $(AUTHELIA_IMAGE) || echo "Warning: failed to pull $(AUTHELIA_IMAGE)"
	@echo "Displaying build status...";
	@$(MAKE) --no-print-directory status

start:
	@echo "Checking required volumes and network..."
	@$(SUDO) docker volume inspect caddy_data >/dev/null 2>&1 || { echo "ERROR: Volume 'caddy_data' not found. Run 'make build' first."; exit 1; }
	@$(SUDO) docker volume inspect caddy_config >/dev/null 2>&1 || { echo "ERROR: Volume 'caddy_config' not found. Run 'make build' first."; exit 1; }
	@$(SUDO) docker volume inspect authelia_data >/dev/null 2>&1 || { echo "ERROR: Volume 'authelia_data' not found. Run 'make build' first."; exit 1; }
	@$(SUDO) docker network inspect caddy_net0 >/dev/null 2>&1 || { echo "ERROR: Network 'caddy_net0' not found. Run 'make build' first."; exit 1; }
	@echo "Starting all services..."
	$(SUDO) $(DC) -f $(COMPOSE_FILE) up -d

stop:
	@if $(SUDO) docker ps --filter "name=caddy" --filter "status=running" -q | grep -q . || $(SUDO) docker ps --filter "name=authelia" --filter "status=running" -q | grep -q .; then \
		echo "Stopping all services..."; \
		$(SUDO) $(DC) -f $(COMPOSE_FILE) stop; \
	else \
		echo "No running caddy or authelia containers to stop."; \
	fi

restart:
	@if $(SUDO) docker ps --filter "name=caddy" --filter "status=running" -q | grep -q . || $(SUDO) docker ps --filter "name=authelia" --filter "status=running" -q | grep -q .; then \
		echo "Restarting all services..."; \
		$(SUDO) $(DC) -f $(COMPOSE_FILE) restart; \
	else \
		echo "No running caddy or authelia containers to restart."; \
	fi

clean:
	@echo "Stopping $(SERVICE) (if running)..."
	-$(DC) -f $(COMPOSE_FILE) stop $(SERVICE) || true
	@echo "Stopping authelia (if running)..."
	-$(DC) -f $(COMPOSE_FILE) stop authelia || true
	@echo "Removing containers with name containing '$(SERVICE)'..."
	$(SUDO) docker ps -a --filter "name=$(SERVICE)" --format "{{.ID}}" | xargs -r $(SUDO) docker rm -f || true
	@echo "Removing containers with name containing 'authelia'..."
	$(SUDO) docker ps -a --filter "name=authelia" --format "{{.ID}}" | xargs -r $(SUDO) docker rm -f || true
	@echo "Removing images with repository/tag matching '$(SERVICE)'..."
	$(SUDO) docker images --format "{{.Repository}}:{{.Tag}} {{.Repository}}" | awk '/$(SERVICE)/{print $$1}' | xargs -r $(SUDO) docker rmi -f || true
	@echo "Removing images with repository/tag matching 'authelia'..."
	$(SUDO) docker images --format "{{.Repository}}:{{.Tag}} {{.Repository}}" | awk '/authelia/{print $$1}' | xargs -r $(SUDO) docker rmi -f || true
	@echo "Removing volumes caddy_data, caddy_config, authelia_data..."
	$(SUDO) docker volume rm caddy_data caddy_config authelia_data || true
	@echo "Removing network caddy_net0..."
	$(SUDO) docker network rm caddy_net0 || true
	@echo "Running status check..."
	{ $(MAKE) status; } || true

prune:
	@echo "Prune requested: PRUNE_FORCE=$(PRUNE_FORCE)";
	@if [ "$(PRUNE_FORCE)" != "yes" ]; then \
		echo "To actually prune resources, run: make PRUNE_FORCE=yes prune"; \
		exit 0; \
	fi; \
	@echo "Pruning unused containers, networks, images (dangling), and volumes..."; \
	# Use docker system prune with filters to be explicit; remove dangling images, unused networks, and unused volumes
	docker system prune -f --volumes || true

authelia-gen-secrets:
	@echo "Generating secrets for Authelia..."
	@./scripts/gen_secrets.sh
	@echo

authelia-update-config:
	@echo "Copying config files into Docker volume, validating and restarting authelia..."
	@$(SCRIPTS_DIR)/update_authelia_config.sh
	@echo

authelia-validate-config:
	@echo "Validating configuration inside running authelia container..."
	$(SUDO) docker exec authelia authelia validate-config --config /config/configuration.yml
	@echo

authelia-view-config:
	@echo "Showing Authelia configuration file:"
	cat ./config/authelia/configuration.yml || true
	@echo

authelia-view-users:
	@echo "Showing Authelia users database file:"
	cat ./config/authelia/users.yml || true
	@echo

status:
	@command -v docker >/dev/null 2>&1 || { echo "ERROR: docker CLI not found in PATH"; exit 1; }

	@printf "\n\n🖼️  %s image:\n" "$(SERVICE)"
	@{ \
		IMG=$$($(SUDO) docker inspect --format='{{.Config.Image}}' $(SERVICE) 2>/dev/null || true); \
		if [ -n "$$IMG" ]; then \
			$(SUDO) docker images "$$IMG" || echo "Image $$IMG not found locally"; \
		else \
			$(SUDO) docker images --format 'table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}' | grep -F -i -- "$(SERVICE)" || echo "No $(SERVICE) image found locally"; \
		fi; \
	}
	@printf "\n\n🖼️  Authelia image:\n"
	@{ \
		IMG=$$($(SUDO) docker inspect --format='{{.Config.Image}}' authelia 2>/dev/null || true); \
		if [ -n "$$IMG" ]; then \
			$(SUDO) docker images "$$IMG" || echo "Image $$IMG not found locally"; \
		else \
			$(SUDO) docker images --format 'table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}' | grep -F -i -- "authelia" || echo "No authelia image found locally"; \
		fi; \
	}
	@printf "\n\n📋 All containers:\n"
	@$(SUDO) docker ps -a --format "table {{.Names}}\t{{.RunningFor}}\t{{.Status}}\t{{.Ports}}"

logs-caddy:
	@echo "Displaying last 100 logs for caddy..."
	$(SUDO) docker logs --tail 100 caddy

logs-authelia:
	@echo "Displaying last 100 logs for authelia..."
	$(SUDO) docker logs --tail 100 authelia

caddy-config-update:
	@echo "Updating caddy config volume and reloading Caddy..."
	@./scripts/copy_caddy_conf_to_volume.sh caddy_config config/caddy_security.conf
	@./scripts/copy_caddy_conf_to_volume.sh caddy_config Caddyfile
	@./scripts/validate_caddy.sh || (echo "Validation failed" && exit 1)
	@./scripts/reload_caddy.sh || (echo "Reload failed" && exit 1)

caddy-validate:
	@echo "Validating Caddy configuration..."
	@./scripts/validate_caddy.sh --quiet

help:
	@printf "Usage:\n"
	@printf "  make [target]\n\n"
	@printf "Targets:\n"
	@printf "  build         Build network and storage (runs %s and %s)\n" "$(NETWORK_SCRIPT)" "$(STORAGE_SCRIPT)"
	@printf "  status        Show status of all services and images\n"
	@printf "  start         Start all services (docker-compose up -d)\n"
	@printf "  stop          Stop all services (docker-compose stop)\n"
	@printf "  restart       Stop then start all services\n"
	@printf "  logs-caddy    Show last 100 logs for caddy service\n"
	@printf "  logs-authelia Show last 100 logs for authelia service\n"
	@printf "  clean         Stop, remove containers and images matching %s\n" "$(SERVICE)"
	@printf "  prune         Remove orphan resources (requires PRUNE_FORCE=yes)\n\n"
	@printf "  caddy-config-update  Update Caddy config volume, validate, and reload Caddy\n"
	@printf "  caddy-validate       Validate Caddy configuration quietly\n\n"
	@printf "  authelia-gen-secrets          Generate secrets for Authelia\n"
	@printf "  authelia-update-config        Update Authelia config volume, validate, and restart Authelia\n"
	@printf "  authelia-validate-config      Validate Authelia configuration\n"
	@printf "  authelia-view-config          Show Authelia configuration file\n"
	@printf "  authelia-view-users           Show Authelia users database file\n\n"
	@printf "Variables (can be set on the make command line):\n"
	@printf "  COMPOSE_FILE=%s\n" "$(COMPOSE_FILE)"
	@printf "  DC=%s\n" "$(DC)"
	@printf "  PRUNE_FORCE=yes    (set to actually perform prune operations)\n"
