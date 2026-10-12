ui_has_dialog() {
    command -v dialog &>/dev/null
}

ui_success() {
    local title="${1:-Success}" message="$2"
    if ui_has_dialog && [ -t 1 ]; then
        dialog --title "$title" --msgbox "$message" 6 50
    else
        echo "$title: $message"
    fi
}

ui_error() {
    local title="${1:-Error}" message="$2"
    if ui_has_dialog && [ -t 1 ]; then
        dialog --title "$title" --msgbox "$message" 6 50
    else
        echo "$title: $message" >&2
    fi
}

ui_info() {
    local title="${1:-Info}" message="$2"
    if ui_has_dialog && [ -t 1 ]; then
        dialog --title "$title" --msgbox "$message" 6 50
    else
        echo "$title: $message"
    fi
}

ui_warn() {
    local title="${1:-Warning}" message="$2"
    if ui_has_dialog && [ -t 1 ]; then
        dialog --title "$title" --msgbox "$message" 7 50
    else
        echo "$title: $message" >&2
    fi
}
