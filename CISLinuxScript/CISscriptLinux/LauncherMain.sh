#!/bin/bash

# ---
# HARDSECNET - Main Menu Script
#
# This script provides a TUI to navigate and run hardening,
# auditing, and unhardening scripts.
#
# Run this script with sudo: sudo ./main_menu.sh
# ---

# --- Color Definitions ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# --- Check for Root ---
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Error: This script must be run as root.${NC}"
  echo "Please run with: sudo $0"
  exit 1
fi

# --- Function Definitions ---

# Renders the main banner
# --- Superior Hacker-Themed Banner ---
show_banner() {
    clear
    # Optional: ensure proper colors/fonts support
    export TERM="${TERM:-xterm-256color}"
    export LANG="${LANG:-en_US.UTF-8}"

    GREEN='\033[0;32m'
    CYAN='\033[0;36m'
    MAGENTA='\033[0;35m'
    YELLOW='\033[1;33m'
    DIM='\033[2m'
    NC='\033[0m'

    # Top border
    echo -e "${DIM}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
    echo

    # Title (HARDSECNET) – prefer figlet or toilet
    if command -v figlet &> /dev/null; then
        echo -e "${GREEN}"
        figlet -f slant -w $(tput cols) "HARDSECNET"
        echo -e "${NC}"
    elif command -v toilet &> /dev/null; then
        echo -e "${GREEN}"
        toilet -f mono12 -F metal "HARDSECNET"
        echo -e "${NC}"
    else
        # Fallback ASCII
        echo -e "${GREEN}"
        echo "██╗  ██╗ █████╗ ██████╗ ██████╗ ███████╗███████╗███╗   ██╗███████╗████████╗"
        echo "██║  ██║██╔══██╗██╔══██╗██╔══██╗██╔════╝██╔════╝████╗  ██║██╔════╝╚══██╔══╝"
        echo "███████║███████║██║  ██║██║  ██║███████╗█████╗  ██╔██╗ ██║███████╗   ██║   "
        echo "██╔══██║██╔══██║██║  ██║██║  ██║╚════██║██╔══╝  ██║╚██╗██║╚════██║   ██║   "
        echo "██║  ██║██║  ██║██████╔╝██████╔╝███████║███████╗██║ ╚████║███████║   ██║   "
        echo "╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝ ╚═════╝ ╚══════╝╚══════╝╚═╝  ╚═══╝╚══════╝   ╚═╝   "
        echo -e "${NC}"
    fi

    echo
    echo -e "   ${CYAN}|| System Hardening  •  Audit Automation  •  Recon Toolkit ||${NC}"
    echo

    echo -e "${DIM}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"
    echo
}


# Pauses execution until user presses Enter
function pause() {
    echo
    read -p "Press [Enter] to continue..."
}

# Handles the sub-menu for a specific category
function handle_category() {
    local category_name="$1"
    local category_dir="$2"

    # Check if the directory exists
    if [ ! -d "$category_dir" ]; then
        echo -e "${RED}Error: Directory '$category_dir' not found.${NC}"
        pause
        return
    fi

    # Sub-menu loop
    while true; do
        show_banner
        echo -e "${YELLOW}--- Category: $category_name ---${NC}"
        echo
        echo "   a. Run Audit (Before/After)"
        echo "   h. Run Hardening Script"
        echo "   u. Run Unhardening Script"
        echo
        echo "   b. Back to Main Menu"
        echo
        read -p "Enter choice (a, h, u, b): " sub_choice

        case $sub_choice in
            a)
                echo -e "${YELLOW}--- Running Audit ---${NC}"
                
                # 1. Define and create the report directory
                local report_dir="reportJSON"
                mkdir -p "$report_dir"
                
                read -p "Enter a filename for the report (e.g., report_before.json): " report_file
                
                if [ -z "$report_file" ]; then
                    echo -e "${RED}Invalid filename. Aborting.${NC}"
                else
                    # 2. Construct the full path for the report
                    local full_report_path="$report_dir/$report_file"
                    
                    if [ -f "$category_dir/audit.sh" ]; then
                        echo "Executing: ./$category_dir/audit.sh $full_report_path"
                        echo -e "${GREEN}Report will be saved to: $full_report_path${NC}"
                        # The audit script is run without sudo, as the main script is already root
                        ./"$category_dir"/audit.sh "$full_report_path"
                    else
                        echo -e "${RED}Error: '$category_dir/audit.sh' not found.${NC}"
                    fi
                fi
                pause
                ;;
            h)
                echo -e "${YELLOW}--- Running Hardening & Post-Audit ---${NC}"
                
                # Check if the hardening script exists
                if [ ! -f "$category_dir/harden.sh" ]; then
                    echo -e "${RED}Error: '$category_dir/harden.sh' not found.${NC}"
                    pause
                    continue # Go back to the sub-menu loop
                fi

                # 1. Run the hardening script
                echo "Executing: ./$category_dir/harden.sh"
                ./"$category_dir"/harden.sh
                echo -e "${GREEN}Hardening script finished.${NC}"
                echo

                # 2. Run the audit script automatically
                echo -e "${YELLOW}Running automatic post-hardening audit...${NC}"

                # Check if the audit script exists
                if [ ! -f "$category_dir/audit.sh" ]; then
                    echo -e "${RED}Error: '$category_dir/audit.sh' not found. Cannot run post-audit.${NC}"
                    pause
                    continue # Go back to the sub-menu loop
                fi

                # 3. Define and create the report directory
                local report_dir="reportJSON"
                mkdir -p "$report_dir"
                
                # 4. Create a dynamic filename for the post-hardening report
                #    (e.g., "Warning_Banners_post_harden_20251030-123000.json")
                local report_file="${category_name// /_}_post_harden_$(date +%Y%m%d-%H%M%S).json"
                local full_report_path="$report_dir/$report_file"

                # 5. Execute the audit
                echo "Executing: ./$category_dir/audit.sh $full_report_path"
                ./"$category_dir"/audit.sh "$full_report_path"
                
                echo -e "${GREEN}Post-hardening audit complete. Report saved to: $full_report_path${NC}"
                pause
                ;;
            u)
                echo -e "${YELLOW}--- Running Unhardening ---${NC}"
                if [ -f "$category_dir/unharden.sh" ]; then
                    echo "Executing: ./$category_dir/unharden.sh"
                    ./"$category_dir"/unharden.sh
                else
                    echo -e "${RED}Error: '$category_dir/unharden.sh' not found.${NC}"
                fi
                pause
                ;;
            b)
                return # Exits this function, goes back to the main loop
                ;;
            *)
                echo -e "${RED}Invalid option. Please try again.${NC}"
                pause
                ;;
        esac
    done
}

# --- Main Application Loop ---

while true; do
    show_banner
    echo -e "${YELLOW}Available Categories:${NC}"
    
    # --- !!! EDIT THIS SECTION !!! ---
    # List your 9 categories here
    # Format: "Number. Menu Title"
    
    echo "   1. Cammand Line Warning"
    echo "   2. File System"
    echo "   3. Warning Banners"
    echo "   4. GDM (Graphical Login)"
    echo "   5. UFW (Firewall)"
    echo "   6. Network Devices (Wireless)"
    echo "   7. Mandetory Access Control"
    echo "   8. Package Management"
    echo "   9. Server Services"
    
    # ---
    
    echo
    echo "   q. Quit"
    echo
    read -p "Enter category number: " main_choice

    case $main_choice in
    
        # --- !!! EDIT THIS SECTION !!! ---
        # Link your categories to their directory names
        # Format: handle_category "Menu Title" "DirectoryName"
        
        1)
            handle_category "Cammand Line Warning" "CammandLineWarnning"
            ;;
        2)
            handle_category "File System" "Filesystem"
            ;;
        3)
            handle_category "Warning Banners" "WarningBanners"
            ;;
        4)
            handle_category "GDM (Graphical Login)" "GDM"
            ;;
        5)
            handle_category "UFW (Firewall)" "UFW"
            ;;
        6)
            handle_category "Network Devices (Wireless)" "Networking"
            ;;
        7)
            handle_category "Mandetory Access Control" "MandetoryAccessControl"
            ;;
        8)
            handle_category "Package Management" "PackageManagement"
            ;;
        9)
            handle_category "Server Services" "ServerServices"
            ;;
            
        # ---
            
        q)
            clear
            echo -e "${GREEN}Exiting HARDSECNET.${NC}"
            break
            ;;
        *)
            echo -e "${RED}Invalid option. Please try again.${NC}"
            pause
            ;;
    esac
done
