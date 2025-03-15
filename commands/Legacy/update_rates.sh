#!/usr/bin/env bash

COMMAND_NAME="ExchangeRates:Update"

run_command() {
    printf "${GREEN}[Commander] Uruchamianie aktualizacji kursów walut...${NO_COLOR}\n"

    CONTAINER_ID=$(get_legacy_container_id)
    if [ -z "$CONTAINER_ID" ]; then
        printf "${RED}Nie znaleziono kontenera legacy.${NO_COLOR}\n"
    else
        currencies=("pln" "eur" "czk" "usd" "huf" "chf" "gbp" "uah" "dkk" "nok" "sek")
        for currency in "${currencies[@]}"; do
            docker exec "$CONTAINER_ID" bin/console slowhop:pricing:currency:update-exchange-rates "$currency" -e docker --pretty &
        done
        wait
        printf "${GREEN}[Commander] Aktualizacja zakończona${NO_COLOR}\n"
    fi

    read -p "Naciśnij Enter, aby kontynuować..."
}
