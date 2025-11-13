#!/bin/bash

# ---
# UNHARDENING Script for CIS 3.1.2
#
# This script re-enables all wireless interfaces by running 'rfkill unblock all'.
# ---

echo "Reverting CIS 3.1.2: Enabling all wireless interfaces..."

# 1. Check if rfkill is installed
if ! command -v rfkill &> /dev/null; then
    echo "rfkill command not found. Nothing to unblock."
    exit 1
fi

# 2. Unblock all wireless devices
echo "Unblocking all wireless devices..."
rfkill unblock all

echo "---"
echo "CIS 3.1.2 unhardening complete."
echo "All wireless devices have been unblocked."
echo "---"
