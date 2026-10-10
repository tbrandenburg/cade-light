.PHONY: help init build up down logs ps exec config

help:
	@printf '%s\n' 'make init    Create .env from .env.example and workspace/' 'make build   Build the workbench image' 'make up      Build and start the workbench' 'make down    Stop the stack' 'make logs    Follow workbench logs' 'make ps      Show service status' 'make exec    Open a shell in the workbench'

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
