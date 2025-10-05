#!/bin/bash

# Color definitions
RESET="\033[0m"
BOLD="\033[1m"
DIM="\033[2m"

# Foreground colors
BLACK="\033[30m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
MAGENTA="\033[35m"
CYAN="\033[36m"
WHITE="\033[37m"

# Background colors
BG_RED="\033[41m"
BG_GREEN="\033[42m"
BG_YELLOW="\033[43m"
BG_BLUE="\033[44m"

# Combined styles
SUCCESS="${GREEN}${BOLD}"
ERROR="${RED}${BOLD}"
WARNING="${YELLOW}${BOLD}"
INFO="${CYAN}"
DEBUG="${DIM}"
