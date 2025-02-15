#!/usr/bin/env bash

COMMAND_NAME="ExchangeRates:Update"

run_command() {
    echo "${GREEN}[Commander] Uruchamianie aktualizacji kursów walut...${NO_COLOR}"

    CONTAINER_ID=$(get_container_id)
    if [ -z "$CONTAINER_ID" ]; then
        echo "${RED}Nie znaleziono kontenera legacy.${NO_COLOR}"
    else
        currencies=("pln" "eur" "czk" "usd" "huf" "chf" "gbp" "uah" "dkk" "nok" "sek")
        for currency in "${currencies[@]}"; do
            docker exec "$CONTAINER_ID" bin/console slowhop:pricing:currency:update-exchange-rates "$currency" -e docker --pretty &
        done
        wait
        echo "${GREEN}[Commander] Aktualizacja zakończona${NO_COLOR}"
    fi

    read -p "Naciśnij Enter, aby kontynuować..."
}
