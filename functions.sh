#!/usr/bin/env bash
# WARNING: don't call this script directly, include it via the `source` command.

# ============================================================================ #
# Boolean literals and friends
# ============================================================================ #

bool() {
    case "$1" in
    true)
        return 0
        ;;
    false)
        return 1
        ;;
    *)
        fail "Boolean value must be either 'true' or 'false', but got: '$1'"
        ;;
    esac
}

xor() {
    if [ "$(
        bool "$1"
        echo $?
    )" != "$(
        bool "$2"
        echo $?
    )" ]; then
        return 0
    else
        return 1
    fi
}

# ============================================================================ #
# Logging
# ============================================================================ #

print_color_text() {
    local color="$1"
    local text="$2"
    local no_color='\033[0m'
    printf "%b%s%b " "${color}" "${text}" "${no_color}"
}

print_color_text_ln() {
    print_color_text "$@" && echo ""
}

message_ongoing() {
    local blue='\033[0;34m'
    print_color_text "${blue}" ''
    echo "$@"
}

message_success() {
    local green='\033[0;32m'
    print_color_text "${green}" '✔'
    echo "$@"
}

message_fail() {
    local red='\033[0;31m'
    print_color_text "${red}" '✘'
    echo "$@" >&2
}

do_logging() {
    LOG_MESSAGES+=("$1")
    message_ongoing "$1"
}

fail() {
    if [ "${#LOG_MESSAGES[@]}" != 0 ]; then
        local last_index=$((${#LOG_MESSAGES[@]} - 1))
        if [ -n "$1" ]; then
            echo -n '  ' && message_fail "$1"
        fi
        message_fail "${LOG_MESSAGES[${last_index}]} - fail"
        LOG_MESSAGES=("${LOG_MESSAGES[@]:0:${last_index}}")
    elif [ -n "$1" ]; then
        message_fail "$1"
    else
        message_fail "fail (no message was provided)"
    fi
    exit 1
}

done_logging() {
    local last_index=$((${#LOG_MESSAGES[@]} - 1))
    message_success "${LOG_MESSAGES[${last_index}]} - done"
    LOG_MESSAGES=("${LOG_MESSAGES[@]:0:${last_index}}")
}

# ============================================================================ #
# Predicates
# ============================================================================ #

requires_sudo() {
    if [ "$(id -u)" -ne 0 ]; then
        cat >&2 <<END
Running the script requires the superuser privilege.
!!! MAKE SURE THIS IS WHAT YOU *WANT* AND YOU *TRUST* THE SCRIPT
Enter the code below to re-run the script with the necessary privilege:

  sudo !!

END
        exit 1
    fi
}

does_command_exist() {
    if [ "$(command -v "$1")" ]; then
        return 0
    else
        return 1
    fi
}

requires_commands() {
    local is_failed=false
    do_logging 'Checking required commands'
    for command_name in "$@"; do
        if ! does_command_exist "${command_name}"; then
            is_failed=true
            echo -n '  ' && message_fail "Error: ${command_name} is not found"
            continue
        fi
    done
    if bool "${is_failed}"; then
        echo -n '  ' && message_fail 'Summary: some commands are not set'
        fail
    fi
    done_logging
}

requires_variables() {
    local is_failed=false
    do_logging 'Checking required variables'
    for var_name in "$@"; do
        if [ -z "${!var_name+x}" ]; then
            is_failed=true
            echo -n '  ' && message_fail "Error: ${var_name} is not set"
            continue
        fi
        if [ -z "${!var_name}" ]; then
            is_failed=true
            echo -n '  ' && message_fail "Error: ${var_name} is empty"
            continue
        fi
    done
    if bool "${is_failed}"; then
        echo -n '  ' && message_fail 'Summary: some variables are empty or not set'
        fail
    fi
    done_logging
}
