include .env
export

export PROJECT_ROOT=$(shell pwd)

env-up:
	@docker compose up -d iwh-postgres

env-down:
	@docker compose down iwh-postgres

env-cleanup:
	@read -p "Очистить все volume файлы окружения? [y/N]:" ans; \
	if [ "$$ans" = "y" ]; then \
		docker compose down iwh-postgres && \
		sudo rm -rf out/pgdata && \
		echo "Файлы окружения очищены"; \
	else \
		echo "Очистка файлов окружения отменена"; \
	fi

env-port-forward:
	@docker compose up -d port-forwarder

env-port-close:
	@docker compose down port-forwarder

migrate-create:
	@if [ -z "$(seq)" ]; then \
		echo "Отсутствует необходимый параметр seq. Пример: make migrate-create seq=init"; \
		exit 1; \
	fi; \
	docker compose run --rm iwh-postgres-migrate \
		create \
		-ext sql \
		-dir /migrations \
		-seq  "$(seq)"

migrate-action:
	@if [ -z "$(action)" ]; then \
		echo "Отсутствует необходимый параметр action. Пример: make migrate-action action=up"; \
		exit 1; \
	fi; \
	docker compose run  --rm iwh-postgres-migrate \
		-path /migrations \
		-database postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@iwh-postgres:5432/${POSTGRES_DB}?sslmode=disable \
		"$(action)"

migrate-up:
	@make migrate-action action=up

migrate-down:
	@make migrate-action action=down

