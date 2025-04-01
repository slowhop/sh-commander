#!/usr/bin/env bash

COMMAND_NAME="Legacy:MigrateDatabase"

run_command() {
    printf "${YELLOW}[Commander] ${GREEN}Uruchamianie migracji bazy danych...${NO_COLOR}\n"

    CONTAINER_ID=$(get_legacy_container_id)
    if [ -z "$CONTAINER_ID" ]; then
        printf "${RED}Nie znaleziono kontenera legacy.${NO_COLOR}\n"
        return 1
    fi

    # Utworzenie folderu logs, jeśli nie istnieje
    mkdir -p "$logs_dir"
    local migration_logs_file="$logs_dir/database_migration.log"

    # Usunięcie poprzedniego pliku z logami (jeśli istnieje)
    rm -f "$migration_logs_file"

    printf "${YELLOW}[Commander] ${GREEN}Rozpoczynam migrację bazy danych...${NO_COLOR}\n"

    # Uruchomienie komendy migracji w kontenerze legacy i zapisanie wyjścia do pliku
    docker exec "$CONTAINER_ID" php bin/console doctrine:migrations:migrate -n -e docker > "$migration_logs_file" 2>&1 &
    local migration_pid=$!

    # Monitorowanie postępu
    printf "${YELLOW}[Commander] ${GREEN}Migracja w toku. Sprawdzanie statusu...${NO_COLOR}\n"

    # Pętla sprawdzająca logi i status procesu
    while kill -0 $migration_pid 2>/dev/null; do
        # Wyświetl ostatnią linię logów
        if [ -s "$migration_logs_file" ]; then
            tail -1 "$migration_logs_file"
        fi
        sleep 1
    done

    # Sprawdź kod zakończenia procesu
    wait $migration_pid
    local migration_status=$?

    if [ $migration_status -eq 0 ]; then
        printf "${YELLOW}[Commander] ${GREEN}Migracja bazy danych zakończona pomyślnie!${NO_COLOR}\n"

        # Wyświetl podsumowanie z logów
        printf "${YELLOW}[Commander] ${GREEN}Podsumowanie:${NO_COLOR}\n"
        cat "$migration_logs_file" | grep -E "executed|migrated|skipped"
    else
        printf "${RED}[Commander] Błąd podczas migracji bazy danych!${NO_COLOR}\n"
        printf "${YELLOW}[Commander] ${RED}Logi błędów:${NO_COLOR}\n"
        cat "$migration_logs_file"
    fi

    read -p "Naciśnij Enter, aby kontynuować..."
}