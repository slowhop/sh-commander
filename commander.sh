#!/usr/bin/env bash

current_dir=$(dirname "${BASH_SOURCE[0]}")
logs_dir="$current_dir/logs"

source "$current_dir/lib/colors.sh"
source "$current_dir/lib/docker_utils.sh"

# Ukrywanie i pokazywanie kursora
cursor_hide() { printf "\033[?25l"; }
cursor_show() { printf "\033[?25h"; }
clear_screen() { printf "\033[H\033[J"; }

# Rysowanie opcji menu
print_option() {
    local text="$1"

    if [[ "$text" == 📂* ]]; then
        printf " ${GREEN}%s${NO_COLOR}\n" "$text"
    elif [[ "$text" == ⚡* ]]; then
        printf " ${YELLOW}%s${NO_COLOR}\n" "$text"
    elif [[ "$text" == ⬅️* || "$text" == 🚪* ]]; then
        printf " ${RED}%s${NO_COLOR}\n" "$text"
    else
        printf " %s\n" "$text"
    fi
}

print_selected() { printf "\033[7m %s \033[27m\n" "$1"; }

# Obsługa strzałek i enter
key_input() {
    read -rsn1 key
    if [[ $key == $'\033' ]]; then
        read -rsn2 rest
        case "$rest" in
            "[A") echo "up" ;;
            "[B") echo "down" ;;
        esac
    elif [[ $key == "" ]]; then
        echo "enter"
    fi
}

# Funkcja wyboru opcji
select_option() {
    local options=("$@")
    local selected=0

    while true; do
        clear_screen
        echo "${GREEN}========= Menu =========${NO_COLOR}"
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

# Wczytywanie kategorii (folderów) i zapisanie ich prawdziwych nazw
get_categories() {
    local categories=()
    local raw_categories=()

    while IFS= read -r category; do
        categories+=("📂 $category")  # Dodajemy ikonę tylko do wyświetlania
        raw_categories+=("$category") # Surowe nazwy do ścieżek
    done <<< "$(find "$current_dir/commands" -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)"

    printf "%s\n" "${categories[@]}" # Zwracamy wersję z ikonami
}

# Wczytywanie komend w danej kategorii
get_commands() {
    local category="$1"
    local commands=()
    while IFS= read -r command; do
        commands+=("$command")
    done <<< "$(find "$current_dir/commands/$category" -mindepth 1 -maxdepth 1 -type f -name "*.sh" -exec basename {} \;)"

    printf "%s\n" "${commands[@]}"
}

# Obsługa podmenu
handle_submenu() {
    local category_display="$1"                  # To, co wybrał użytkownik (z ikoną)
    local category="${category_display:2}"       # Usunięcie pierwszych 2 znaków (ikony i spacji)

    local commands=($(get_commands "$category")) # Pobranie listy komend (z ikonami)
    local raw_commands=($(find "$current_dir/commands/$category" -mindepth 1 -maxdepth 1 -type f -name "*.sh" -exec basename {} \;))

    if [[ ${#commands[@]} -eq 0 ]]; then
        echo "${RED}Brak komend w kategorii ${category}.${NO_COLOR}"
        sleep 1
        return
    fi

    local options=()
    local scripts=()

    for command_file in "${raw_commands[@]}"; do
        source "$current_dir/commands/$category/$command_file"
        options+=("⚡ $COMMAND_NAME")
        scripts+=("$current_dir/commands/$category/$command_file")
    done


    options+=("⬅️ Wstecz")  # Dodanie opcji powrotu

    while true; do
        select_option "${options[@]}"
        local choice=$?

        if [[ $choice -eq $((${#options[@]} - 1)) ]]; then
            break
        else
            clear_screen
            echo "Uruchamianie: ${options[$choice]}"
            source "${scripts[$choice]}"
            run_command
        fi
    done
}

# Funkcja zatrzymująca procesy w tle
cleanup() {
    echo "Zatrzymywanie wszystkich procesów w tle..."
    jobs -p | xargs -r kill
    cursor_show
    exit 0
}

# Główna pętla menu
cursor_hide
trap cursor_show EXIT
trap cleanup SIGINT

while true; do
    categories=()
    while IFS= read -r category; do
        categories+=("$category")
    done <<< "$(get_categories)"
    categories+=("🚪 Wyjdź") # Dodanie opcji Wyjdź

    select_option "${categories[@]}"
    main_choice=$?

    if [[ $main_choice -eq $((${#categories[@]} - 1)) ]]; then
        echo "Zakończono działanie skryptu."
        break
    else
        handle_submenu "${categories[$main_choice]}"
    fi
done

cursor_show
