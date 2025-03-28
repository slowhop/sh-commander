#!/usr/bin/env bash

COMMAND_NAME="Grunt:run"

run_command() {
    printf "${YELLOW}[Commander] ${GREEN}Uruchamianie komendy grunt...${NO_COLOR}\n"

    CONTAINER_ID=$(get_legacy_container_id)
    if [ -z "$CONTAINER_ID" ]; then
        printf "${RED}Nie znaleziono kontenera legacy.${NO_COLOR}\n"
    else
        docker exec --user root "$CONTAINER_ID" grunt
        printf "${YELLOW}[Commander] ${GREEN}Wykonuwanie komendy grunt zakończone.${NO_COLOR}\n"
    fi

    read -p "Naciśnij Enter, aby kontynuować..."
}
