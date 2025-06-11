# syntax=docker/dockerfile:1
# Используем Ruby образ. Версия задается через аргумент
ARG RUBY_VERSION=3.4.2
ARG TARGET_PLATFORM
FROM --platform=$TARGET_PLATFORM ruby:$RUBY_VERSION-slim AS base

# Устанавливаем рабочую директорию внутри контейнера
WORKDIR /app

# Устанавливаем переменные окружения
ENV RAILS_ENV=development \
    BUNDLE_JOBS=4 \
    BUNDLE_RETRY=3 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT=""

# Обновляем систему и устанавливаем нужные библиотеки
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential \
    libpq-dev \
    libvips \
    libyaml-dev \
    git \
    curl \
    nodejs \
    yarn \
    postgresql-client && \
    rm -rf /var/lib/apt/lists/*


# Копируем только Gemfile и Gemfile.lock для кэширования установки зависимостей
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Копируем остальной код приложения
COPY . .

# Порт, который будем проксировать наружу
EXPOSE 3000

# Команда по умолчанию — запуск Rails-сервера
CMD ["bin/rails", "server", "-b", "0.0.0.0"]
