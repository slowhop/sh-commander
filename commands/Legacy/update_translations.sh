#!/usr/bin/env bash

COMMAND_NAME="Translations:Update"

run_command() {
    echo "${GREEN}[Commander] Uruchamianie aktualizacji tłumaczeń...${NO_COLOR}"

    CONTAINER_ID=$(get_container_id)
    if [ -z "$CONTAINER_ID" ]; then
        echo "${RED}Nie znaleziono kontenera legacy.${NO_COLOR}"
    else
        docker exec "$CONTAINER_ID" bin/console slowhop:system:translations:refresh -e docker
        echo "${GREEN}[Commander] Aktualizacja tłumaczeń zakończona.${NO_COLOR}"
    fi

    read -p "Naciśnij Enter, aby kontynuować..."
}
