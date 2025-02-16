#!/usr/bin/env bash

COMMAND_NAME="Reindex:Products"

run_command() {
    echo "${GREEN}[Commander] Uruchamianie reindeksacji produktów...${NO_COLOR}"

    can_run_script=true
    logs_file="$logs_dir/reindex_products.log"

    # Sprawdzenie istnienia kontenera legacy
    legacy_container_id=$(get_legacy_container_id)
    if [ -z "$legacy_container_id" ]; then
        echo "${RED}Nie znaleziono kontenera legacy.${NO_COLOR}"
        can_run_script=false
    fi

    # Sprawdzenie istnienia kontenera indexer
    index_container_id=$(get_indexer_container_id)
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
        legacy_pid=$!
        echo "${GREEN}[Commander] Reindeksacja produktów uruchomiona w kontenerze legacy.${NO_COLOR}"

        # Utworzenie folderu logs, jeśli nie istnieje
        mkdir -p "$logs_dir"

        # Uruchomienie komendy w kontenerze indexer i przekierowanie wyjścia do pliku w folderze logs
        docker exec "$index_container_id" bin/console messenger:consume --env=staging -- product > "$logs_file" 2>&1 &
        indexer_pid=$!
        echo "${GREEN}[Commander] Konsumowanie wiadomości uruchomione w kontenerze indexer.${NO_COLOR}"

        # Czekanie na zakończenie procesu reindeksacji
        wait $legacy_pid

        # Monitorowanie wiadomości konsumpcji w kontenerze indexer
        echo "${GREEN}[Commander] Monitorowanie konsumpcji wiadomości w kontenerze indexer przez 10 sekund...${NO_COLOR}"
        end_time=$((SECONDS + 10))
        while [ $SECONDS -lt $end_time ]; do
            if grep -q "ProductToIndexMessage" "$logs_file"; then
                echo "${GREEN}[Commander] Wykryto nowe wiadomości. Resetowanie czasu oczekiwania.${NO_COLOR}"
                end_time=$((SECONDS + 10))
                > "$logs_file"  # Czyszczenie pliku logów
            fi
            sleep 1
        done

        echo "${GREEN}[Commander] Konsumowanie wiadomości zakończone.${NO_COLOR}"

        # Zakończenie procesu indexera
        kill $indexer_pid
        echo "${GREEN}[Commander] Proces indexera został zakończony.${NO_COLOR}"

        # Usunięcie pliku z logami
        rm -f "$logs_file"
        echo "${GREEN}[Commander] Plik z logami został usunięty.${NO_COLOR}"
    fi

    read -p "Naciśnij Enter, aby kontynuować..."
}
