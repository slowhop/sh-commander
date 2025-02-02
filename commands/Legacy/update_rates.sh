#!/usr/bin/env bash

COMMAND_NAME="ExchangeRates:Update"

run_command() {
    echo "${GREEN}[Commander] Uruchamianie aktualizacji kursów walut...${NO_COLOR}"
    currencies=("pln" "eur" "czk" "usd" "huf" "chf" "gbp" "uah" "dkk" "nok" "sek")
    for currency in "${currencies[@]}"; do
        docker exec sh-legacy-legacy-1 bin/console slowhop:pricing:currency:update-exchange-rates "$currency" -e docker --pretty &
    done
    wait
    echo "${GREEN}[Commander] Aktualizacja zakończona${NO_COLOR}"
    read -p "Naciśnij Enter, aby kontynuować..."
}
