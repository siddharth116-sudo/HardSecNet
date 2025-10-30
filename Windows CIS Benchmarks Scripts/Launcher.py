#!/usr/bin/env python3
"""
HardSecNet Launcher - Final Recursive + Auto Pair Version
─────────────────────────────────────────────────────────────
- Scans all subfolders for .ps1 scripts
- Auto-detects paired Audit.ps1 + Harden.ps1
- Runs Audit → Harden → Audit automatically
- Saves before/after JSON reports in Reports/
"""

import os
import subprocess
import time
import re
from datetime import datetime

# ──────────────────────────────────────────────
# Color setup (auto-install colorama if missing)
# ──────────────────────────────────────────────
try:
    from colorama import Fore, Style, init
except Exception:
    print("colorama not found. Installing...")
    subprocess.check_call([os.sys.executable, "-m", "pip", "install", "colorama"])
    from colorama import Fore, Style, init
init(autoreset=True)

# ──────────────────────────────────────────────
HEADER = r"""
██╗  ██╗ █████╗ ██████╗ ██████╗ ███████╗███████╗ ██████╗███╗   ██╗███████╗████████╗
██║  ██║██╔══██╗██╔══██╗██╔══██╗██╔════╝██╔════╝██╔════╝████╗  ██║██╔════╝╚══██╔══╝
███████║███████║██████╔╝██║  ██║███████╗█████╗  ██║     ██╔██╗ ██║█████╗     ██║   
██╔══██║██╔══██║██╔══██╗██║  ██║╚════██║██╔══╝  ██║     ██║╚██╗██║██╔══╝     ██║   
██║  ██║██║  ██║██║  ██║██████╔╝███████║███████╗╚██████╗██║ ╚████║███████╗   ██║   
╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝ ╚══════╝╚══════╝ ╚═════╝╚═╝  ╚═══╝╚══════╝   ╚═╝   

        ░░░░░░░░░░░ H A R D S E C N E T ░░░░░░░░░░░
   ░ System Hardening | Audit | Network Recon ░
   ░------------------------------------------------░
"""
# ──────────────────────────────────────────────

def run_powershell(script_path):
    """Run a PowerShell script with ExecutionPolicy Bypass."""
    subprocess.run([
        "powershell", "-ExecutionPolicy", "Bypass", "-File", script_path
    ], check=True)

def find_latest_json(reports_dir, exclude_prefixes=None):
    """Find the latest JSON file in Reports or report folder."""
    exclude_prefixes = exclude_prefixes or []
    search_dirs = []
    # Support both folder names
    if os.path.isdir(reports_dir):
        search_dirs.append(reports_dir)
    alt = os.path.join(os.path.dirname(reports_dir), "report")
    if os.path.isdir(alt):
        search_dirs.append(alt)

    jsons = []
    for d in search_dirs:
        for f in os.listdir(d):
            if f.lower().endswith(".json") and not any(f.lower().startswith(p.lower()) for p in exclude_prefixes):
                path = os.path.join(d, f)
                jsons.append((os.path.getmtime(path), path))
    return max(jsons, default=(None, None))[1]


def run_audit_sequence(harden_script):
    """Run Audit.ps1 → Harden.ps1 → Audit.ps1 sequence automatically."""
    folder = os.path.dirname(harden_script)
    audit_script = os.path.join(folder, "Audit.ps1")

    if not os.path.exists(audit_script):
        print(Fore.RED + "[✘] Audit.ps1 not found beside " + harden_script)
        input(Fore.CYAN + "Press ENTER to continue...")
        return

    reports = os.path.join(folder, "Reports")
    os.makedirs(reports, exist_ok=True)
    base = os.path.splitext(os.path.basename(harden_script))[0]
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    before_json = os.path.join(reports, f"before_{base}_{ts}.json")
    after_json = os.path.join(reports, f"after_{base}_{ts}.json")

    try:
        print(Fore.CYAN + "\n[1/3] Running initial audit...")
        run_powershell(audit_script)
        latest = find_latest_json(reports, ["before_", "after_"])
        if latest: os.rename(latest, before_json)
        print(Fore.GREEN + f"[✔] Saved → {before_json}")

        print(Fore.YELLOW + "\n[2/3] Running hardening script...")
        run_powershell(harden_script)
        print(Fore.GREEN + "[✔] Hardening complete.")

        print(Fore.CYAN + "\n[3/3] Running final audit...")
        run_powershell(audit_script)
        latest = find_latest_json(reports, ["before_", "after_"])
        if latest: os.rename(latest, after_json)
        print(Fore.GREEN + f"[✔] Saved → {after_json}")

        print(Fore.GREEN + f"\n[✓] Sequence complete.\nReports in {reports}")
        print(Fore.CYAN + f"→ Before: {before_json}\n→ After:  {after_json}")
    except subprocess.CalledProcessError as e:
        print(Fore.RED + f"[✘] PowerShell failed: {e}")
    input(Fore.CYAN + "\nPress ENTER to return to menu...")

# ──────────────────────────────────────────────
# Utility helpers
# ──────────────────────────────────────────────

def read_manual_title(path):
    """Extract '# Title:' from a .ps1 file if exists."""
    try:
        with open(path, encoding='utf-8', errors='ignore') as f:
            for _ in range(20):
                line = f.readline()
                if line.startswith("# Title:"):
                    return line.split(":", 1)[1].strip()
    except Exception:
        return None
    return None

def pretty_name(file):
    name = os.path.splitext(os.path.basename(file))[0]
    name = re.sub(r'\b\d+(\.\d+)+\b', '', name)
    name = name.replace("_", " ").replace("-", " ")
    return re.sub(r'\s+', ' ', name).title()

# ──────────────────────────────────────────────
# Main recursive scanner and menu
# ──────────────────────────────────────────────

def list_scripts(folder):
    """List all ps1 files recursively and show auto Audit+Harden pairing."""
    pairs = []      # [(audit_path, harden_path, display_name)]
    singles = []    # [(path, display_name)]

    for root, dirs, files in os.walk(folder):
        audits = [os.path.join(root, f) for f in files if f.lower() == "audit.ps1"]
        hardens = [os.path.join(root, f) for f in files if "harden" in f.lower() and f.lower().endswith(".ps1")]

        for harden in hardens:
            audit = os.path.join(root, "Audit.ps1")
            if os.path.exists(audit):
                display = pretty_name(os.path.basename(root))
                pairs.append((audit, harden, display))
            else:
                singles.append((harden, pretty_name(harden)))

        for audit in audits:
            if not any(audit == p[0] for p in pairs):
                singles.append((audit, pretty_name(audit)))

    if not pairs and not singles:
        print(Fore.YELLOW + "[!] No PowerShell scripts found.")
        input(Fore.CYAN + "Press ENTER to return...")
        return

    while True:
        print(Fore.GREEN + f"\nHardSecNet — Category: {os.path.basename(folder)}")
        idx = 1
        mapping = {}

        # Display paired Audit+Harden scripts
        for audit, harden, name in pairs:
            print(f"{idx}. {name}  [Auto Audit + Harden Sequence]")
            mapping[idx] = ("pair", audit, harden)
            idx += 1

        # Display single scripts
        for path, name in singles:
            print(f"{idx}. {name}  [{os.path.basename(path)}]")
            mapping[idx] = ("single", path)
            idx += 1

        print("\nb. Back to Categories")
        print("q. Quit\n")

        choice = input(Fore.YELLOW + "Enter script number: ").strip().lower()
        if choice == 'q':
            exit()
        elif choice == 'b':
            return
        elif choice.isdigit() and int(choice) in mapping:
            kind, *paths = mapping[int(choice)]
            if kind == "pair":
                audit, harden = paths
                run_audit_sequence(harden)
            else:
                script_path = paths[0]
                try:
                    print(Fore.YELLOW + f"\n[Running] {script_path}")
                    run_powershell(script_path)
                    print(Fore.GREEN + "[✔] Done.")
                except subprocess.CalledProcessError as e:
                    print(Fore.RED + f"[✘] Failed: {e}")
                input(Fore.CYAN + "\nPress ENTER to return...")
        else:
            print(Fore.RED + "Invalid choice. Try again.")

def main():
    print(Fore.GREEN + HEADER)
    root = os.path.dirname(os.path.abspath(__file__))

    while True:
        cats = [f for f in os.listdir(root) if os.path.isdir(os.path.join(root, f))]
        if not cats:
            print(Fore.RED + "[!] No folders found.")
            break

        print(Fore.CYAN + "\nAvailable Categories:\n")
        for i, c in enumerate(sorted(cats), 1):
            print(f"{i}. {c}")
        print("\nq. Quit\n")

        choice = input(Fore.YELLOW + "Enter category number: ").strip().lower()
        if choice == 'q':
            break
        elif choice.isdigit() and 1 <= int(choice) <= len(cats):
            selected = sorted(cats)[int(choice) - 1]
            list_scripts(os.path.join(root, selected))
        else:
            print(Fore.RED + "Invalid choice. Try again.")

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nExiting HardSecNet...")
