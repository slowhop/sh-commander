#!/usr/bin/env bash

COMMAND_NAME="Flush all"

run_command() {
  echo "${GREEN}[Commander] Uruchamianie czyszczenia redisa ...${NO_COLOR}"

  CONTAINER_ID=$(get_redis_container_id)
  if [ -z "$CONTAINER_ID" ]; then
      echo "${RED}Nie znaleziono kontenera redisa.${NO_COLOR}"
  else
      docker exec "$CONTAINER_ID" redis-cli flushall
      echo "${GREEN}[Commander] Czyszczenie redisa zakończone.${NO_COLOR}"
  fi

  read -p "Naciśnij Enter, aby kontynuować..."
}
