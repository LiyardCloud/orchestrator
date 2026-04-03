.PHONY: up down restart logs ps deploy update build shell-postgres create-dbs

up:
	docker compose up -d

down:
	docker compose down

restart:
	docker compose restart

logs:
	docker compose logs -f

ps:
	docker compose ps

build:
	docker compose build

deploy:
	./scripts/deploy.sh

update:
	git submodule update --remote

dev:
	docker compose -f docker-compose.yml -f docker-compose.dev.yml up

shell-postgres:
	docker compose exec postgres psql -U $${POSTGRES_USER}

create-dbs:
	docker compose exec postgres psql -U $${POSTGRES_USER} -c "CREATE DATABASE dataroom_db;"
	# docker compose exec postgres psql -U $${POSTGRES_USER} -c "CREATE DATABASE journal_db;"
