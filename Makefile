# Makefile — Упрощает команды Docker Compose для разработки и продакшена

# Переменные окружения по умолчанию
ENV_FILE_TEST=.env.test
ENV_FILE_DEV=.env.development
ENV_FILE_PROD=.env.production

# ========================
# 👨‍💻 TEST
# ========================

test-build:
	docker compose --env-file $(ENV_FILE_TEST) build web-test

test:
	make test-build
	docker compose --env-file $(ENV_FILE_TEST) run --rm web-test bundle exec rspec

test-file:
	make test-build
	docker compose --env-file $(ENV_FILE_TEST) run --rm web-test bundle exec rspec $(f)

test-db-create:
	docker compose --env-file $(ENV_FILE_TEST) run --rm web-test bundle exec rails db:create

test-db-migrate:
	docker compose --env-file $(ENV_FILE_TEST) run --rm web-test bundle exec rails db:migrate

test-db-prepare:
	docker compose --env-file $(ENV_FILE_TEST) run --rm web-test bundle exec rails db:prepare



# ========================
# 👨‍💻 DEVELOPMENT
# ========================

## 🛠 Сборка dev-образа без запуска контейнеров
build-dev:
	docker compose --env-file $(ENV_FILE_DEV) build

## 🚀 Запустить dev-среду (локально с volumes и портами)
up-dev:
	docker compose --env-file $(ENV_FILE_DEV) up --build

## 🧹 Остановить и удалить dev-контейнеры и volume
clean-dev:
	docker compose --env-file $(ENV_FILE_DEV) down -v

## 🐛 Логи контейнеров dev-режима
logs-dev:
	docker compose --env-file $(ENV_FILE_DEV) logs -ft

## 🔧 Установка гемов через bundle install внутри контейнера
bundle-install:
	docker compose --env-file $(ENV_FILE_DEV) exec web bundle install

## 🔧 Создание БД, миграции и сиды (db:prepare)
db-prepare:
	docker compose --env-file $(ENV_FILE_DEV) exec web bin/rails db:prepare

## 📦 Применить только миграции (db:migrate)
db-migrate:
	docker compose --env-file $(ENV_FILE_DEV) exec web bin/rails db:migrate

## ⬆️ Выполнить конкретную миграцию по VERSION
db-up:
	docker compose --env-file $(ENV_FILE_DEV) exec web bin/rails db:migrate:up VERSION=$(VERSION)

## 🧪 Откат последней миграции (db:rollback)
db-rollback:
	docker compose --env-file $(ENV_FILE_DEV) exec web bin/rails db:rollback STEP=$(STEP)

## ⬇️ Откатить конкретную миграцию по VERSION
db-down:
	docker compose --env-file $(ENV_FILE_DEV) exec web bin/rails db:migrate:down VERSION=$(VERSION)

## 🌱 Заполнить тестовыми данными из seeds.rb (db:seed)
db-seed:
	docker compose --env-file $(ENV_FILE_DEV) exec web bin/rails db:seed

## 💣 Полный сброс базы данных и повторный запуск миграций + seed
db-reset:
	docker compose --env-file $(ENV_FILE_DEV) exec web bin/rails db:reset

## 🧬 Проверить статус миграций (db:migrate:status)
db-status:
	docker compose --env-file $(ENV_FILE_DEV) exec web bin/rails db:migrate:status

## 💬 Открыть Rails-консоль внутри контейнера
console:
	docker compose --env-file $(ENV_FILE_DEV) exec web bin/rails console

## 🎮 Генерация API-контроллера (например: make controller NAME=api/v1/users)
controller:
	@if [ -z "$(NAME)" ]; then \
	  echo "❌ Пожалуйста, укажи NAME (например, NAME=api/v1/users)"; \
	else \
	  docker compose --env-file $(ENV_FILE_DEV) exec web bin/rails generate controller $(NAME) --skip-template-engine --no-assets --api; \
	fi

## Просмотр всех существующих роутов
routes:
	docker compose --env-file $(ENV_FILE_DEV) exec web bin/rails routes



# ========================
# 🚀 PRODUCTION
# ========================

## 📦 Применить миграции в продакшене
db-migrate-prod:
	docker compose -f docker-compose.yml -f docker-compose.prod.yml --env-file $(ENV_FILE_PROD) exec web bin/rails db:migrate

## 🛠 Сборка production-образа без запуска контейнеров
build-prod:
	docker compose -f docker-compose.yml -f docker-compose.prod.yml --env-file $(ENV_FILE_PROD) build

## 🚀 Запустить production (без volume и открытых портов)
up-prod:
	docker compose -f docker-compose.yml -f docker-compose.prod.yml --env-file $(ENV_FILE_PROD) up --build -d

## 🧹 Остановить и удалить продакшн контейнеры + volumes
clean-prod:
	docker compose -f docker-compose.yml -f docker-compose.prod.yml --env-file $(ENV_FILE_PROD) down -v

## 🐛 Логи продакшн-контейнеров
logs-prod:
	docker compose -f docker-compose.yml -f docker-compose.prod.yml --env-file $(ENV_FILE_PROD) logs -ft

## 🐛 Логи бекенд контейнера
logs-backend:
	docker logs -f fastyshop-backend

## 🔧 Создание БД, миграции и сиды (db:prepare)
db-prepare-prod:
	docker compose -f docker-compose.yml -f docker-compose.prod.yml --env-file $(ENV_FILE_PROD) exec web bin/rails db:prepare

## 🌱 Заполнить тестовыми данными из seeds.rb (db:seed)
db-seed-prod:
	docker compose -f docker-compose.yml -f docker-compose.prod.yml --env-file .env.production exec web bin/rails db:seed

# Запуск консоли в контейнере продакшена
rails-c-prod:
	docker compose -f docker-compose.yml -f docker-compose.prod.yml --env-file .env.production exec web bin/rails console

sidekiq:
	docker compose up sidekiq
