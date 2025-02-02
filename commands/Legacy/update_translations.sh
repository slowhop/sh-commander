#!/usr/bin/env bash

COMMAND_NAME="Translations:Update"

run_command() {
    echo "${GREEN}[Commander] Uruchamianie aktualizacji tłumaczeń...${NO_COLOR}"

    CONTAINER_ID=$(docker ps --filter "name=sh-legacy-legacy" --format "{{.ID}}")
    if [ -z "$CONTAINER_ID" ]; then
        echo "${RED}Nie znaleziono kontenera legacy.${NO_COLOR}"
        exit 1
    fi

    docker exec "$CONTAINER_ID" bin/console slowhop:system:translations:refresh -e docker
    echo "${GREEN}[Commander] Aktualizacja tłumaczeń zakończona.${NO_COLOR}"
    read -p "Naciśnij Enter, aby kontynuować..."
}
