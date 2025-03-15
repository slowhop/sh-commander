#!/usr/bin/env bash

COMMAND_NAME="ExchangeRates:Update"

run_command() {
    printf "${YELLOW}[Commander] ${GREEN}Uruchamianie aktualizacji kursów walut...${NO_COLOR}\n"

    CONTAINER_ID=$(get_legacy_container_id)
    if [ -z "$CONTAINER_ID" ]; then
        printf "${RED}Nie znaleziono kontenera legacy.${NO_COLOR}\n"
    else
        currencies=("pln" "eur" "czk" "usd" "huf" "chf" "gbp" "uah" "dkk" "nok" "sek")
        for currency in "${currencies[@]}"; do
            printf "${YELLOW}[Commander] ${GREEN}Aktualizuję: ${NO_COLOR}%s ${GREEN}...\n" "$currency"

            RESULT=$(docker exec "$CONTAINER_ID" bin/console slowhop:pricing:currency:update-exchange-rates "$currency" -e docker --pretty 2>&1)

            if [[ $? -eq 0 ]]; then
                printf "${YELLOW}[Commander] ${NO_COLOR}%s ${GREEN}zaktualizowano pomyślnie.${NO_COLOR}\n" "$currency"
            else
                printf "${RED}[Commander] Błąd podczas aktualizacji: %s.${NO_COLOR}\n" "$currency"
            fi
        done
        wait
        printf "${YELLOW}[Commander] ${GREEN}Aktualizacja zakończona${NO_COLOR}\n"
    fi

    read -p "Naciśnij Enter, aby kontynuować..."
}
