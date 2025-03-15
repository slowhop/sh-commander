#!/usr/bin/env bash

COMMAND_NAME="Flush all"

run_command() {
  printf "${YELLOW}[Commander] ${GREEN}Uruchamianie czyszczenia redisa ...${NO_COLOR}\n"

  CONTAINER_ID=$(get_redis_container_id)
  if [ -z "$CONTAINER_ID" ]; then
      printf "${RED}Nie znaleziono kontenera redisa.${NO_COLOR}\n"
  else
      docker exec "$CONTAINER_ID" redis-cli flushall
      printf "${YELLOW}[Commander] ${GREEN}Czyszczenie redisa zakończone.${NO_COLOR}\n"
  fi

  read -p "Naciśnij Enter, aby kontynuować..."
}
