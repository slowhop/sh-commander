#!/usr/bin/env bash

COMMAND_NAME="Reindex:Products"

get_processed_count() {
    grep -o "ProductToIndexMessage was handled successfully" "$indexer_logs_file" | wc -l
}

update_processed_count() {
    local no_cursor_control=false  # Domyślnie zapisujemy i przywracamy kursor
    local new_count=$(get_processed_count)

    # Sprawdzanie, czy przekazano parametr, który wyłącza zapisywanie kursora
    if [ "$1" == "no_cursor" ]; then
        no_cursor_control=true
    fi

    # Zaktualizowany warunek, który uwzględnia także no_cursor_control
    if [ "$new_count" -ne "$processed_count" ] || [ "$no_cursor_control" = true ]; then
        if [ "$no_cursor_control" = false ]; then
            tput sc  # Zapisz pozycję kursora
            printf "${YELLOW}[Commander] ${GREEN}Przetworzono produktów:${NO_COLOR} %d\r" "$new_count"
            tput rc  # Przywróć pozycję kursora
        else
            echo "${YELLOW}[Commander] ${GREEN}Przetworzono produktów:${NO_COLOR} $new_count"
        fi

        processed_count=$new_count
    fi
}

run_command() {
    echo "${YELLOW}[Commander] ${GREEN}Uruchamianie reindeksacji produktów...${NO_COLOR}"

    local can_run_script=true
    local indexer_logs_file="$logs_dir/reindex_products_indexer.log"
    local legacy_logs_file="$logs_dir/reindex_products_legacy.log"
    local processed_count=0

    # Usunięcie plików z logami (jeśli istnieją)
    rm -f "$indexer_logs_file" "$legacy_logs_file"

    # Sprawdzenie istnienia kontenera legacy
    local legacy_container_id=$(get_legacy_container_id)
    if [ -z "$legacy_container_id" ]; then
        echo "${RED}Nie znaleziono kontenera legacy.${NO_COLOR}"
        can_run_script=false
    fi

    # Sprawdzenie istnienia kontenera indexer
    local index_container_id=$(get_indexer_container_id)
    if [ -z "$index_container_id" ]; then
        echo "${RED}Nie znaleziono kontenera indexer.${NO_COLOR}"
        can_run_script=false
    fi

    # Uruchomienie skryptów, jeśli oba kontenery istnieją
    if [ "$can_run_script" = true ]; then
        # Czyszczenie indeksu w kontenerze indexer
        docker exec "$index_container_id" bin/console slowhop:index:recreate -i product_accommodation -e docker
        echo "${YELLOW}[Commander] ${GREEN}Indeks wyczyszczony w kontenerze indexer.${NO_COLOR}"

        # Uruchomienie komendy reindeksacji w kontenerze legacy (logowanie do pliku)
        docker exec "$legacy_container_id" php -d memory_limit=1G bin/console slowhop:products:reindex -f -e docker -n > "$legacy_logs_file" 2>&1 &
        local legacy_pid=$!
        echo "${YELLOW}[Commander] ${GREEN}Reindeksacja produktów uruchomiona w kontenerze legacy.${NO_COLOR}"

        # Utworzenie folderu logs, jeśli nie istnieje
        mkdir -p "$logs_dir"

        # Uruchomienie komendy w kontenerze indexer i przekierowanie wyjścia do pliku
        docker exec "$index_container_id" bin/console messenger:consume --env=staging -- product > "$indexer_logs_file" 2>&1 &
        local indexer_pid=$!
        echo "${YELLOW}[Commander] ${GREEN}Konsumowanie wiadomości uruchomione w kontenerze indexer.${NO_COLOR}"
        echo ""

        # Oczekiwanie na pierwszy log w legacy
        echo "${YELLOW}[Commander] ${GREEN}Oczekiwanie na informacje o liczbie produktów do reindeksacji...${NO_COLOR}"
        while [ ! -s "$legacy_logs_file" ]; do
            sleep 1
        done

        # Analiza pliku legacy w poszukiwaniu liczby produktów
        local total_products
        while read -r line; do
            echo "$line" | grep -q "\[Command\] [0-9]\+ products to reindex" && {
                total_products=$(echo "$line" | grep -o "[0-9]\+ products to reindex" | grep -o "[0-9]\+")
                echo "${YELLOW}[Commander] ${GREEN}Ilość produktów do przetworzenia:${NO_COLOR} $total_products"
                break
            }

            # Jeśli nie pasuje do wzorca, wyświetlamy w konsoli
            echo "$line"
        done < "$legacy_logs_file"

        # Czekanie na zakończenie procesu reindeksacji
        while kill -0 $legacy_pid 2> /dev/null; do
            update_processed_count
            sleep 1
        done

        wait $legacy_pid

        echo "${YELLOW}[Commander] ${GREEN}Reindeksacja produktów uruchomiona w kontenerze legacy zakończona.${NO_COLOR}"

        # Monitorowanie wiadomości konsumpcji w kontenerze indexer
        echo "${YELLOW}[Commander] ${GREEN}Monitorowanie konsumpcji wiadomości w kontenerze indexer przez 10 sekund...${NO_COLOR}"
        local end_time=$((SECONDS + 10))
        local last_count=$(get_processed_count)

        while [ $SECONDS -lt $end_time ]; do
            local new_count=$(get_processed_count)

            if [ "$new_count" -ne "$last_count" ]; then
                echo "${YELLOW}[Commander] ${GREEN}Wykryto nowe wiadomości. Resetowanie czasu oczekiwania.${NO_COLOR}"
                end_time=$((SECONDS + 10))
                last_count=$new_count
            fi

            sleep 1
        done

        update_processed_count "no_cursor"

        echo "${YELLOW}[Commander] ${GREEN}Konsumowanie wiadomości zakończone.${NO_COLOR}"

        # Zakończenie procesu indexera, jeśli jeszcze istnieje
        if kill -0 $indexer_pid 2> /dev/null; then
            kill $indexer_pid 2>> "$legacy_logs_file"
            echo "${YELLOW}[Commander] ${GREEN}Proces indexera został zakończony.${NO_COLOR}"
        fi

        # Usunięcie plików z logami
        rm -f "$indexer_logs_file" "$legacy_logs_file"
        echo "${YELLOW}[Commander] ${GREEN}Pliki z logami zostały usunięte.${NO_COLOR}"
    fi

    read -p "Naciśnij Enter, aby kontynuować..."
}
