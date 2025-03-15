#!/usr/bin/env bash

COMMAND_NAME="Translations:Update"

run_command() {
    printf "${GREEN}[Commander] Uruchamianie aktualizacji tłumaczeń...${NO_COLOR}\n"

    CONTAINER_ID=$(get_legacy_container_id)
    if [ -z "$CONTAINER_ID" ]; then
        printf "${RED}Nie znaleziono kontenera legacy.${NO_COLOR}\n"
    else
        docker exec "$CONTAINER_ID" bin/console slowhop:system:translations:refresh -e docker
        printf "${GREEN}[Commander] Aktualizacja tłumaczeń zakończona.${NO_COLOR}\n"
    fi

    read -p "Naciśnij Enter, aby kontynuować..."
}
