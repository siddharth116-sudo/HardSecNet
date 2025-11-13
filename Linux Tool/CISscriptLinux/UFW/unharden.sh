#!/bin/bash

# ---
# UNHARDENING Script for CIS 4.2.7
#
# This script reverts the hardening by completely resetting UFW.
# It will disable the firewall, delete all rules, and return
# the system to a default "allow all" state (by being inactive).
# ---

echo "Reverting CIS 4.2.7: Disabling firewall and resetting policies..."

# 1. Check if UFW is installed
if ! command -v ufw &> /dev/null; then
    echo "ufw command not found. Nothing to revert."
    echo "---"
    echo "Unhardening complete. System is already in a non-UFW state."
    echo "---"
    exit 0
fi

# 2. Reset UFW to its factory defaults
#    The 'reset' command disables the firewall, deletes all rules,
#    and sets policies back to their defaults.
echo "Resetting UFW to its default state (disabling and deleting all rules)..."
yes | ufw reset

echo "---"
echo "UFW unhardening complete."
echo "Firewall is now inactive and all rules have been removed."
echo "Your internet connection should now be fully restored."
echo "Run 'sudo ufw status' to verify (it should say 'Status: inactive')."
echo "---"
