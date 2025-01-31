#!/usr/bin/env bash
current_dir=$(dirname "${BASH_SOURCE[0]}")

source "$current_dir/lib/colors.sh"
source "$current_dir/lib/docker_utils.sh"

# Ukrywanie i pokazywanie kursora
cursor_hide() { printf "\033[?25l"; }
cursor_show() { printf "\033[?25h"; }
clear_screen() { printf "\033[H\033[J"; } # Reset ekranu

# Rysowanie opcji menu
print_option() { printf "   %s\n" "$1"; }
print_selected() { printf "  \033[7m %s \033[27m\n" "$1"; }

# Obsługa strzałek i enter
key_input() {
    read -rsn1 key
    if [[ $key == $'\033' ]]; then
        read -rsn2 rest
        case "$rest" in
            "[A") echo "up" ;;    # Strzałka w górę
            "[B") echo "down" ;;  # Strzałka w dół
        esac
    elif [[ $key == "" ]]; then
        echo "enter" # Klawisz Enter
    fi
}

# Funkcja wyboru opcji
select_option() {
    local options=("$@")
    local selected=0

    while true; do
        clear_screen
        echo "${GREEN}=== Menu ===${NO_COLOR}"
        for i in "${!options[@]}"; do
            if [[ $i -eq $selected ]]; then
                print_selected "${options[$i]}"
            else
                print_option "${options[$i]}"
            fi
        done

        case $(key_input) in
            up)    ((selected--)); [[ $selected -lt 0 ]] && selected=$((${#options[@]} - 1)) ;;
            down)  ((selected++)); [[ $selected -ge ${#options[@]} ]] && selected=0 ;;
            enter) break ;;
        esac
    done

    return $selected
}

# Funkcja do aktualizacji kursów walut
update_exchange_rates() {
    echo "${GREEN}[Commander] Uruchamianie aktualizacji kursów walut...${NO_COLOR}"
    currencies=("pln" "eur" "czk" "usd" "huf" "chf" "gbp" "uah" "dkk" "nok" "sek")
    for currency in "${currencies[@]}"; do
        docker exec sh-legacy-legacy-1 bin/console slowhop:pricing:currency:update-exchange-rates "$currency" -e docker --pretty &
    done
    wait
    echo "${GREEN}[Commander] Aktualizacja kursów walut zakończona${NO_COLOR}"
    echo "Wciśnij Enter, aby kontynuować."
    read
}

update_legacy_translations() {
    echo "${GREEN}[Commander] Uruchamianie aktualizacji tłumaczeń legacy...${NO_COLOR}"

    CONTAINER_ID=$(get_container_id)
    docker exec "$CONTAINER_ID" bin/console slowhop:system:translations:refresh -e docker

    echo "${GREEN}[Commander] Aktualizacja tłumaczeń zakończona${NO_COLOR}"
    echo "Wciśnij Enter, aby kontynuować."
    read
}

# Obsługa podmenu
handle_submenu() {
    local submenu=("$@")
    local options=()
    local actions=()

    for entry in "${submenu[@]}"; do
        IFS="|" read -r name action <<< "$entry"
        options+=("$name")
        actions+=("$action")
    done

    while true; do
        select_option "${options[@]}"
        local choice=$?

        if [[ $choice -eq $((${#options[@]} - 1)) ]]; then
            echo "Powrót do menu głównego."
            break
        else
            echo "Wybrano opcję: ${options[$choice]}"
            if [[ -n ${actions[$choice]} ]]; then
                ${actions[$choice]} # Uruchom powiązaną funkcję
            fi
        fi
    done
}

# Konfiguracja menu
main_options=("Ogólne" "Legacy" "Consumer" "Webapp" "Wyjdź")
ogolne_options=("Opcja A|" "Opcja B|" "Opcja C|" "Wstecz|")
legacy_options=("ExchangeRates:Update|update_exchange_rates" "Translations:Update|update_legacy_translations" "Legacy 3|" "Wstecz|")
consumer_options=("Consumer X|" "Consumer Y|" "Consumer Z|" "Wstecz|")
webapp_options=("Webapp Foo|" "Webapp Bar|" "Webapp Baz|" "Wstecz|")

# Główna pętla menu
cursor_hide
trap cursor_show EXIT

while true; do
    select_option "${main_options[@]}"
    main_choice=$?

    case $main_choice in
        0) handle_submenu "${ogolne_options[@]}" ;;
        1) handle_submenu "${legacy_options[@]}" ;;
        2) handle_submenu "${consumer_options[@]}" ;;
        3) handle_submenu "${webapp_options[@]}" ;;
        4) echo "Zakończono działanie skryptu."; break ;;
        *) echo "Nieprawidłowy wybór." ;;
    esac
done

cursor_show


# TODO: Buildowanie frontów w legacy
# TODO: Odpalanie Unitów z parametrami