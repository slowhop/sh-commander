#!/usr/bin/env bash

COMMAND_NAME="Reindex:Lightcards"

get_processed_count() {
    grep -o "LightCardToIndexMessage was handled successfully" "$indexer_logs_file" | wc -l
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
            printf "${YELLOW}[Commander] ${GREEN}Przetwarzanie lightcardów w indexerze [batch]:${NO_COLOR} %d\r" "$new_count"
            tput rc  # Przywróć pozycję kursora
        else
            printf "${YELLOW}[Commander] ${GREEN}Przetwarzanie lightcardów w indexerze [batch]:${NO_COLOR} %d\n" "$new_count"
        fi

        processed_count=$new_count
    fi
}

run_command() {
    printf "${YELLOW}[Commander] ${GREEN}Uruchamianie reindeksacji lightcardów...${NO_COLOR}\n"

    local can_run_script=true
    local indexer_logs_file="$logs_dir/reindex_lightcards_indexer.log"
    local legacy_logs_file="$logs_dir/reindex_lightcards_legacy.log"
    local processed_count=0

    # Usunięcie plików z logami (jeśli istnieją)
    rm -f "$indexer_logs_file" "$legacy_logs_file"

    # Sprawdzenie istnienia kontenera legacy
    local legacy_container_id=$(get_legacy_container_id)
    if [ -z "$legacy_container_id" ]; then
        printf "${RED}Nie znaleziono kontenera legacy.${NO_COLOR}\n"
        can_run_script=false
    fi

    # Sprawdzenie istnienia kontenera indexer
    local index_container_id=$(get_indexer_container_id)
    if [ -z "$index_container_id" ]; then
        printf "${RED}Nie znaleziono kontenera indexer.${NO_COLOR}\n"
        can_run_script=false
    fi

    # Uruchomienie skryptów, jeśli oba kontenery istnieją
    if [ "$can_run_script" = true ]; then
        # Czyszczenie indeksu w kontenerze indexer
        docker exec "$index_container_id" bin/console slowhop:index:recreate -i lightcard -e docker
        printf "${YELLOW}[Commander] ${GREEN}Indeks wyczyszczony w kontenerze indexer.${NO_COLOR}\n"

        # Uruchomienie komendy reindeksacji w kontenerze legacy (logowanie do pliku)
        docker exec "$legacy_container_id" php -d memory_limit=1G bin/console slowhop:light:reindex -e docker -n > "$legacy_logs_file" 2>&1 &
        local legacy_pid=$!
        printf "${YELLOW}[Commander] ${GREEN}Reindeksacja lightcardów uruchomiona w kontenerze legacy.${NO_COLOR}\n"

        # Utworzenie folderu logs, jeśli nie istnieje
        mkdir -p "$logs_dir"

        # Uruchomienie komendy w kontenerze indexer i przekierowanie wyjścia do pliku
        docker exec "$index_container_id" bin/console messenger:consume --env=docker -- lightcard > "$indexer_logs_file" 2>&1 &
        local indexer_pid=$!
        printf "${YELLOW}[Commander] ${GREEN}Konsumowanie wiadomości uruchomione w kontenerze indexer.${NO_COLOR}\n"
        echo ""

        # Czekanie na zakończenie procesu reindeksacji
        while kill -0 $legacy_pid 2> /dev/null; do
            update_processed_count
            sleep 1
        done

        wait $legacy_pid

        # Analiza pliku legacy w poszukiwaniu liczby lightcardów
        local total_lightcards
        while read -r line; do
            if echo "$line" | grep -q "\[Command\] Lightcards reindex finished"; then
                # Wyciągnięcie liczby lightcards precyzyjnie za pomocą awk
                total_lightcards=$(echo "$line" | awk -F'"lightcards":' '{print $2}' | awk -F',' '{print $1}' | tr -d ' ')

                if [[ "$total_lightcards" =~ ^[0-9]+$ ]]; then
                    printf "${YELLOW}[Commander] ${GREEN}Ilość lightcardów przetworzona przez legacy:${NO_COLOR} $total_lightcards\n"
                else
                    printf "${YELLOW}[Commander] ${RED}Błąd: nie udało się odczytać liczby lightcards${NO_COLOR}\n"
                fi

                break
            fi
        done < "$legacy_logs_file"


        printf "${YELLOW}[Commander] ${GREEN}Reindeksacja lightcardów uruchomiona w kontenerze legacy zakończona.${NO_COLOR}\n"

        # Monitorowanie wiadomości konsumpcji w kontenerze indexer
        printf "${YELLOW}[Commander] ${GREEN}Monitorowanie konsumpcji wiadomości w kontenerze indexer przez 10 sekund...${NO_COLOR}\n"
        local end_time=$((SECONDS + 10))
        local last_count=$(get_processed_count)

        while [ $SECONDS -lt $end_time ]; do
            local new_count=$(get_processed_count)

            if [ "$new_count" -ne "$last_count" ]; then
                printf "${YELLOW}[Commander] ${GREEN}Wykryto nowe wiadomości. Resetowanie czasu oczekiwania.${NO_COLOR}\n"
                end_time=$((SECONDS + 10))
                last_count=$new_count
            fi

            sleep 1
        done

        update_processed_count "no_cursor"

        printf "${YELLOW}[Commander] ${GREEN}Konsumowanie wiadomości zakończone.${NO_COLOR}\n"

        # Zakończenie procesu indexera, jeśli jeszcze istnieje
        if kill -0 $indexer_pid 2> /dev/null; then
            kill $indexer_pid 2>> "$legacy_logs_file"
            printf "${YELLOW}[Commander] ${GREEN}Proces indexera został zakończony.${NO_COLOR}\n"
        fi

        # Usunięcie plików z logami
        rm -f "$indexer_logs_file" "$legacy_logs_file"
        printf "${YELLOW}[Commander] ${GREEN}Pliki z logami zostały usunięte.${NO_COLOR}\n"
    fi

    read -p "Naciśnij Enter, aby kontynuować..."
}
