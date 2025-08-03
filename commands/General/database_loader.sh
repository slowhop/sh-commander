#!/usr/bin/env bash

COMMAND_NAME="Database:LoadProdDump"

# === Ścieżki ===
DEST_DIR=~/Downloads/mysql-backups
DEST_DIR_UNPACKED="$DEST_DIR/unpacked"
UNPACKED_SQL_FILE="$DEST_DIR_UNPACKED/backup.sql"
SKIP_FETCH=false

# Funkcja pomocnicze
require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf "${RED}❌ Błąd: Brakuje wymaganej komendy: ${1}${NO_COLOR}\n"
    MISSING_DEPS=true
  fi
}

check_dependencies() {
  MISSING_DEPS=false
  for cmd in aws awk grep sort tail jq tar mysql pv; do
    require_command "$cmd"
  done

  if [ "$MISSING_DEPS" = true ]; then
    printf "${RED}Zainstaluj brakujące zależności i spróbuj ponownie.${NO_COLOR}\n"
    exit 1
  fi
}

check_existing_backup() {
  if [ -f "$UNPACKED_SQL_FILE" ]; then
    printf "${YELLOW}⚠️  Plik $UNPACKED_SQL_FILE już istnieje.${NO_COLOR}\n"
    read -p "❓ Czy chcesz go pobrać i rozpakować ponownie? (y/N): " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
      printf "${GREEN}✅ Używam istniejącego pliku. Pomijam pobieranie i rozpakowanie.${NO_COLOR}\n"
      SKIP_FETCH=true
    fi
  fi
}

ensure_directory() {
  local dir="$1"

  if [ -d "$dir" ]; then
    printf "📁 Folder już istnieje: $dir\n"
    return
  fi

  if mkdir -p "$dir"; then
    printf "📁 Utworzono folder: $dir\n"
  else
    printf "${RED}❌ Nie udało się utworzyć folderu: $dir${NO_COLOR}\n"
    exit 1
  fi
}

create_directories() {
  ensure_directory "$DEST_DIR"
  ensure_directory "$DEST_DIR_UNPACKED"
}

is_sso_logged_in() {
  aws sts get-caller-identity &> /dev/null
  return $?
}

ensure_aws_login() {
  if is_sso_logged_in; then
    printf "✅ AWS SSO już aktywne.\n"
  else
    printf "🔐 Logowanie do AWS SSO...\n"
    aws sso login || exit 1
  fi
}

find_latest_backup() {
  printf "🔍 Szukam najnowszego dumpa (bez -stripped)...\n"
  LATEST_FILE=$(aws s3 ls s3://slowhop-prod/mysql-backups --recursive | grep -v stripped | sort | tail -n 1 | awk '{print $4}')

  if [ -z "$LATEST_FILE" ]; then
    printf "${RED}❌ Nie znaleziono pliku backupu.${NO_COLOR}\n"
    exit 1
  fi
}


download_backup() {
  printf "⬇️  Pobieram: $LATEST_FILE\n"
  aws s3 cp "s3://slowhop-prod/$LATEST_FILE" "$DEST_DIR/" || {
    printf "${RED}❌ Błąd podczas pobierania pliku.${NO_COLOR}\n"
    exit 1
  }

  printf "${GREEN}✅ Plik został pobrany: $DEST_DIR/$LATEST_FILE${NO_COLOR}\n"
}

unpack_backup() {
  BASENAME=$(basename "$LATEST_FILE")
  printf "📦 Wypakowuję archiwum: $BASENAME\n"
  tar -xzvf "$DEST_DIR/$BASENAME" -C "$DEST_DIR_UNPACKED"

  printf "🧹 Usuwam archiwum: $BASENAME\n"
  rm -f "$DEST_DIR/$BASENAME"
}

import_database() {
  local DB_NAME="slowhop_dev"
  local DOCKER_DB_USER="slowhop"
  local DB_USER="root"
  local DB_PASS="root"
  local DB_HOST="127.0.0.1"
  local DB_PORT="3306"

  printf "${YELLOW}🛠️  Przygotowuję bazę danych: $DB_NAME${NO_COLOR}\n"

  mysql -u "$DB_USER" -h "$DB_HOST" -P "$DB_PORT" -p"$DB_PASS" -e "DROP DATABASE IF EXISTS $DB_NAME;"
  mysql -u "$DB_USER" -h "$DB_HOST" -P "$DB_PORT" -p"$DB_PASS" -e "CREATE DATABASE $DB_NAME;"
  mysql -u "$DB_USER" -h "$DB_HOST" -P "$DB_PORT" -p"$DB_PASS" -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DOCKER_DB_USER}'@'%';"

  printf "${GREEN}📥 Importuję plik SQL do bazy $DB_NAME...${NO_COLOR}\n"

  time pv "$UNPACKED_SQL_FILE" | mysql -u "$DB_USER" -h "$DB_HOST" -P "$DB_PORT" -p"$DB_PASS" "$DB_NAME" || {
    printf "${RED}❌ Import bazy danych nie powiódł się.${NO_COLOR}\n"
    exit 1
  }

  printf "${GREEN}✅ Baza danych została zaimportowana.${NO_COLOR}\n"
}

run_command() {
  printf "${YELLOW}[Commander] ${GREEN}Uruchamianie procesu ładowania bazy danych...${NO_COLOR}\n"

  check_dependencies
  create_directories
  check_existing_backup

  if [ "$SKIP_FETCH" = false ]; then
      ensure_aws_login
      find_latest_backup
      download_backup
      unpack_backup
    fi

  import_database

   read -p "Naciśnij Enter, aby kontynuować..."
}
