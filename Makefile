.PHONY: help init build up down logs ps exec config config-srt up-srt verify-srt config-host-flows up-host-flows

help:
	@printf '%s\n' 'make init    Create .env from .env.example and workspace/' 'make build   Build the workbench image' 'make up      Build and start the workbench' 'make down    Stop the stack' 'make logs    Follow workbench logs' 'make ps      Show service status' 'make exec    Open a shell in the workbench' 'make config-srt  Validate SRT overlay' 'make up-srt  Run with loaded SRT profiles' 'make verify-srt  Test sandbox enforcement' 'make up-host-flows  Start with host-backed workflow source'

init:
	@test -e .env || cp .env.example .env
	@mkdir -p workspace
	@printf '%s\n' 'Review .env and replace all placeholder secrets before starting.'

build:
	docker compose build workbench

up:
	docker compose up -d --build

down:
	docker compose down

logs:
	docker compose logs -f workbench

ps:
	docker compose ps

exec:
	docker compose exec workbench bash

config:
	docker compose config --quiet

config-srt:
	docker compose -f compose.yaml -f compose.srt.yaml config --quiet

up-srt:
	docker compose -f compose.yaml -f compose.srt.yaml up -d --build

verify-srt:
	docker compose -f compose.yaml -f compose.srt.yaml exec workbench verify-srt

config-host-flows:
	docker compose -f compose.yaml -f compose.node-red-host-flows.yaml config --quiet

up-host-flows:
	docker compose -f compose.yaml -f compose.node-red-host-flows.yaml up -d --build
