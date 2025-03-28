#!/usr/bin/env bash

COMMAND_NAME="WarmupCache:CatalogPrices"

_get_processed_prices_count() {
    grep -o '\[Pricing\] [0-9]\+ cached' "$legacy_logs_file" | wc -l
}

_get_processed_rate_plans_count() {
    grep -o '\[Pricing\] \[Command\] Fetching rate plans in progress' "$legacy_logs_file" | wc -l
}

_get_processed_fee_plans_count() {
    grep -o 'Cached [0-9]\+ discount plans' "$legacy_logs_file" | awk '{print $2}'
}

_get_processed_discount_plans_count() {
    grep -o 'Cached [0-9]\+ discount plans' "$legacy_logs_file" | awk '{print $2}'
}

_update_processed_prices_count() {
    local no_cursor_control=false  # Domyślnie zapisujemy i przywracamy kursor
    local new_count=$(_get_processed_prices_count)

    # Sprawdzanie, czy przekazano parametr, który wyłącza zapisywanie kursora
    if [ "$1" == "no_cursor" ]; then
        no_cursor_control=true
    fi

    # Zaktualizowany warunek, który uwzględnia także no_cursor_control
    if [ "$new_count" -ne "$processed_count" ] || [ "$no_cursor_control" = true ]; then
        if [ "$no_cursor_control" = false ]; then
            tput sc  # Zapisz pozycję kursora
            printf "${YELLOW}[Commander] ${GREEN}Przetworzono cen posiłków:${NO_COLOR} %d\r" "$new_count"
            tput rc  # Przywróć pozycję kursora
        else
            printf "${YELLOW}[Commander] ${GREEN}Przetworzono cen posiłków:${NO_COLOR} %d\n" "$new_count"
        fi

        processed_count=$new_count
    fi
}

_update_processed_rate_plans_count() {
    local no_cursor_control=false  # Domyślnie zapisujemy i przywracamy kursor
    local new_count=$(_get_processed_rate_plans_count)

    # Sprawdzanie, czy przekazano parametr, który wyłącza zapisywanie kursora
    if [ "$1" == "no_cursor" ]; then
        no_cursor_control=true
    fi

    # Zaktualizowany warunek, który uwzględnia także no_cursor_control
    if [ "$new_count" -ne "$processed_count" ] || [ "$no_cursor_control" = true ]; then
        if [ "$no_cursor_control" = false ]; then
            tput sc  # Zapisz pozycję kursora
            printf "${YELLOW}[Commander] ${GREEN}Przetworzono cen rateplanów:${NO_COLOR} %d\r" "$new_count"
            tput rc  # Przywróć pozycję kursora
        else
            printf "${YELLOW}[Commander] ${GREEN}Przetworzono cen rateplanów:${NO_COLOR} %d\n" "$new_count"
        fi

        processed_count=$new_count
    fi
}


_run_pricing_warmup() {
    rm -f "$legacy_logs_file"
    docker exec "$legacy_container_id" bin/console slowhop:pricing:warmup:meals -e docker --no-debug -n > "$legacy_logs_file" 2>&1 &
    local legacy_pid=$!
    printf "${YELLOW}[Commander] ${GREEN}Rozgrzewanie cen posiłków uruchomione w kontenerze legacy.${NO_COLOR}\n"

    # Czekanie na zakończenie rozgrzewania cen
    while kill -0 $legacy_pid 2> /dev/null; do
        _update_processed_prices_count
        sleep 1
    done

    wait $legacy_pid

    _update_processed_prices_count "no_cursor"
}

_run_rate_plans_warmup() {
    rm -f "$legacy_logs_file"
    docker exec "$legacy_container_id" bin/console slowhop:rateplans:cache:refresh -e docker --no-debug -n > "$legacy_logs_file" 2>&1 &
    local legacy_pid=$!
    printf "${YELLOW}[Commander] ${GREEN}Rozgrzewanie rateplan'ów uruchomione w kontenerze legacy.${NO_COLOR}\n"

    # Czekanie na zakończenie rozgrzewania cen
    while kill -0 $legacy_pid 2> /dev/null; do
        _update_processed_rate_plans_count
        sleep 1
    done

    wait $legacy_pid

    _update_processed_rate_plans_count "no_cursor"
}

_run_fee_plan_warmup() {
    rm -f "$legacy_logs_file"
    docker exec "$legacy_container_id" bin/console slowhop:pricing:fee-plan:cache-refresh -e docker --no-debug -n > "$legacy_logs_file" 2>&1 &
    local legacy_pid=$!
    printf "${YELLOW}[Commander] ${GREEN}Rozgrzewanie planów cenowych uruchomione w kontenerze legacy.${NO_COLOR}\n"

    wait $legacy_pid

    printf "${YELLOW}[Commander] ${GREEN}Przetworzono planów cenowych:${NO_COLOR} %d\n" "$(_get_processed_fee_plans_count)"
}

_run_discount_plan_warmup() {
    rm -f "$legacy_logs_file"
    docker exec "$legacy_container_id" bin/console slowhop:pricing:discount-plan:cache-refresh -e docker --no-debug -n > "$legacy_logs_file" 2>&1 &
    local legacy_pid=$!
    printf "${YELLOW}[Commander] ${GREEN}Rozgrzewanie planów rabatowych uruchomione w kontenerze legacy.${NO_COLOR}\n"

    wait $legacy_pid

    printf "${YELLOW}[Commander] ${GREEN}Przetworzono planów rabatowych:${NO_COLOR} %d\n" "$(_get_processed_discount_plans_count)"
}

run_command() {
    printf "${YELLOW}[Commander] ${GREEN}Uruchamianie procesu rozgrzewania katalogu...${NO_COLOR}\n"

    local can_run_script=true
    local legacy_logs_file="$logs_dir/warmup_catalog_legacy.log"
    local processed_count=0

    # Usunięcie plików z logami (jeśli istnieją)
    rm -f "$legacy_logs_file"

    # Sprawdzenie istnienia kontenera legacy
    local legacy_container_id=$(get_legacy_container_id)
    if [ -z "$legacy_container_id" ]; then
        printf "${RED}Nie znaleziono kontenera legacy.${NO_COLOR}\n"
        can_run_script=false
    fi

    # Uruchomienie skryptów, jeśli kontener legacy istnieje
    if [ "$can_run_script" = true ]; then
        # Utworzenie folderu logs, jeśli nie istnieje
        mkdir -p "$logs_dir"

        # Uruchomienie skryptów
        _run_pricing_warmup
        _run_rate_plans_warmup
        _run_fee_plan_warmup
        _run_discount_plan_warmup

        # Usunięcie plików z logami
        rm -f "$legacy_logs_file"
        printf "${YELLOW}[Commander] ${GREEN}Pliki z logami zostały usunięte.${NO_COLOR}\n"

        printf "${YELLOW}[Commander] ${GREEN}Procesu rozgrzewania katalog zakończony.${NO_COLOR}\n"
    fi

    read -p "Naciśnij Enter, aby kontynuować..."
}
