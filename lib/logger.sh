#!/bin/bash

LOG_FILE=""
ERROR_LOG=""

setup_logging() {
    LOG_FILE="$1"
    ERROR_LOG="$2"
    
    # Create log files
    touch "$LOG_FILE" "$ERROR_LOG"
}

log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [[ -n "$LOG_FILE" ]] && [[ "$DEBUG" == true ]]; then
        echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    fi
}

log_error_to_file() {
    local message=$1
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [[ -n "$ERROR_LOG" ]]; then
        echo "[$timestamp] $message" >> "$ERROR_LOG"
    fi
}

log_success() {
    echo -e "${GREEN}[✓]${RESET} $1"
    log_message "SUCCESS" "$1"
}

log_error() {
    echo -e "${RED}[✗]${RESET} $1" >&2
    log_message "ERROR" "$1"
    log_error_to_file "$1"
}

log_warning() {
    echo -e "${YELLOW}[!]${RESET} $1"
    log_message "WARNING" "$1"
}

log_info() {
    echo -e "${CYAN}[*]${RESET} $1"
    log_message "INFO" "$1"
}

log_debug() {
    if [[ "$DEBUG" == true ]]; then
        echo -e "${DIM}[DEBUG]${RESET} $1"
        log_message "DEBUG" "$1"
    fi
}

log_section() {
    echo ""
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${BOLD}${CYAN}$1${RESET}"
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    log_message "SECTION" "$1"
}

log_phase() {
    local phase_num=$1
    local phase_name=$2
    
    echo ""
    echo -e "${GREEN}[+]${RESET} ${BOLD}Phase $phase_num/5: $phase_name${RESET}"
    log_message "PHASE" "Phase $phase_num/5: $phase_name"
}

log_task() {
    local task_name=$1
    echo -e "    ${CYAN}[>]${RESET} $task_name"
    log_message "TASK" "$task_name"
}

log_result() {
    local result=$1
    echo -e "    ${GREEN}[✓]${RESET} $result"
    log_message "RESULT" "$result"
}
