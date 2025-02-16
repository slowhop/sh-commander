#!/usr/bin/env bash

COMMAND_NAME="Reindex:Products"

update_processed_count() {
    local new_count=$(grep -o "ProductToIndexMessage was handled successfully" "$logs_file" | wc -l)

    if [ "$new_count" -ne "$processed_count" ]; then
        tput sc
        printf "${GREEN}[Commander] Przetworzono produktów: %d${NO_COLOR}\r" "$new_count"
        tput rc
        processed_count=$new_count
    fi
}

run_command() {
    echo "${GREEN}[Commander] Uruchamianie reindeksacji produktów...${NO_COLOR}"

    local can_run_script=true
    local logs_file="$logs_dir/reindex_products.log"
    local processed_count=0

    # Usunięcie pliku z logami (jeśli istnieje)
    rm -f "$logs_file"

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
        echo "${GREEN}[Commander] Indeks wyczyszczony w kontenerze indexer.${NO_COLOR}"

        # Uruchomienie komendy reindeksacji w kontenerze legacy
        docker exec "$legacy_container_id" php -d memory_limit=1G bin/console slowhop:products:reindex -f -e docker -n &
        local legacy_pid=$!
        echo "${GREEN}[Commander] Reindeksacja produktów uruchomiona w kontenerze legacy.${NO_COLOR}"

        # Utworzenie folderu logs, jeśli nie istnieje
        mkdir -p "$logs_dir"

        # Uruchomienie komendy w kontenerze indexer i przekierowanie wyjścia do pliku w folderze logs
        docker exec "$index_container_id" bin/console messenger:consume --env=staging -- product > "$logs_file" 2>&1 &
        local indexer_pid=$!
        echo "${GREEN}[Commander] Konsumowanie wiadomości uruchomione w kontenerze indexer.${NO_COLOR}"
        echo ""

        # Czekanie na zakończenie procesu reindeksacji
        while kill -0 $legacy_pid 2> /dev/null; do
            update_processed_count
            sleep 1
        done

        wait $legacy_pid

        # Monitorowanie wiadomości konsumpcji w kontenerze indexer
        echo "${GREEN}[Commander] Monitorowanie konsumpcji wiadomości w kontenerze indexer przez 10 sekund...${NO_COLOR}"
        local end_time=$((SECONDS + 10))
        while [ $SECONDS -lt $end_time ]; do
            update_processed_count
            if grep -q "ProductToIndexMessage" "$logs_file"; then
                echo "${GREEN}[Commander] Wykryto nowe wiadomości. Resetowanie czasu oczekiwania.${NO_COLOR}"
                end_time=$((SECONDS + 10))
                > "$logs_file"  # Czyszczenie pliku logów
            fi
            sleep 1
        done

        echo "${GREEN}[Commander] Konsumowanie wiadomości zakończone.${NO_COLOR}"

        # Zakończenie procesu indexera, jeśli jeszcze istnieje
        if kill -0 $indexer_pid 2> /dev/null; then
            kill $indexer_pid
            echo "${GREEN}[Commander] Proces indexera został zakończony.${NO_COLOR}"
        fi

        # Usunięcie pliku z logami
        rm -f "$logs_file"
        echo "${GREEN}[Commander] Plik z logami został usunięty.${NO_COLOR}"
    fi

    read -p "Naciśnij Enter, aby kontynuować..."
}
