#!/usr/bin/env bash

current_dir=$(dirname "${BASH_SOURCE[0]}")

source "$current_dir/lib/colors.sh"
source "$current_dir/lib/docker_utils.sh"

# Ukrywanie i pokazywanie kursora
cursor_hide() { printf "\033[?25l"; }
cursor_show() { printf "\033[?25h"; }
clear_screen() { printf "\033[H\033[J"; }

# Rysowanie opcji menu
print_option() { printf "   %s\n" "$1"; }
print_selected() { printf "  \033[7m %s \033[27m\n" "$1"; }

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

# Wczytywanie kategorii z folderów w `commands/`
get_categories() {
    local categories=()
    while IFS= read -r category; do
        categories+=("$category")
    done <<< "$(find "$current_dir/commands" -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)"

    printf "%s\n" "${categories[@]}"
}


# Wczytywanie komend z plików w danej kategorii
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
    local category="$1"
    local commands=($(get_commands "$category"))

    if [[ ${#commands[@]} -eq 0 ]]; then
        echo "${RED}Brak komend w kategorii ${category}.${NO_COLOR}"
        sleep 1
        return
    fi

    local options=()
    local scripts=()

    for command_file in "${commands[@]}"; do
        source "$current_dir/commands/$category/$command_file"
        options+=("$COMMAND_NAME")
        scripts+=("$current_dir/commands/$category/$command_file")
    done

    options+=("Wstecz") # Dodanie opcji powrotu

    while true; do
        select_option "${options[@]}"
        local choice=$?

        if [[ $choice -eq $((${#options[@]} - 1)) ]]; then
            break
        else
            echo "Uruchamianie: ${options[$choice]}"
            source "${scripts[$choice]}"
            run_command
        fi
    done
}

# Główna pętla menu
cursor_hide
trap cursor_show EXIT

while true; do
    categories=()
    while IFS= read -r category; do
        categories+=("$category")
    done <<< "$(get_categories)"
    categories+=("Wyjdź") # Dodanie opcji Wyjdź

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
