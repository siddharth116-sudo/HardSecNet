# 🚀 HardSecNet — Dual-OS Adaptive Security Framework
HEADER = r"""
\033[96m██╗  ██╗ █████╗ ██████╗ ██████╗ ███████╗███████╗ ██████╗███╗   ██╗███████╗████████╗
██║  ██║██╔══██╗██╔══██╗██╔══██╗██╔════╝██╔════╝██╔════╝████╗  ██║██╔════╝╚══██╔══╝
███████║███████║██████╔╝██║  ██║███████╗█████╗  ██║     ██╔██╗ ██║█████╗     ██║   
██╔══██║██╔══██║██╔══██╗██║  ██║╚════██║██╔══╝  ██║     ██║╚██╗██║██╔══╝     ██║   
██║  ██║██║  ██║██║  ██║██████╔╝███████║███████╗╚██████╗██║ ╚████║███████╗   ██║   
╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝ ╚══════╝╚══════╝ ╚═════╝╚═╝  ╚═══╝╚══════╝   ╚═╝   
\033[92m
                         HARDSECNET – Dual-OS Adaptive Security Framework
\033[0m
"""

**Cross-Platform • AI-Driven • CIS-Aligned • Fully Offline • Production Ready**

<p align="center">
  <img src="https://img.shields.io/badge/Platform-Linux%20%7C%20Windows-blue?style=for-the-badge">
  <img src="https://img.shields.io/badge/Security-CIS%20Level%201-green?style=for-the-badge">
  <img src="https://img.shields.io/badge/AI-Ollama%20Phi--3-purple?style=for-the-badge">
  <img src="https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge">
  <img src="https://img.shields.io/badge/Status-Production%20Ready-success?style=for-the-badge">
</p>

HardSecNet is a **complete, production-ready, dual-OS security automation framework** that performs:

✔️ System Auditing
✔️ CIS Level-1 Hardening
✔️ Drift Detection & Comparison
✔️ Snapshot & Rollback
✔️ AI-Driven Security Recommendations
✔️ Cross-Platform Dashboard Visualization

It runs **fully offline**, integrates a **local AI engine** (Ollama + Phi-3), and supports **Ubuntu 24.04** and **Windows 11** with a unified user experience.

---

## 📌 Table of Contents

* Features
* Tech Stack
* Architecture Overview
* Installation
* Usage
* Folder Structure
* Dashboard & API
* AI Explainability Engine
* Screenshots
* Roadmap
* Contributing
* License

---

## 🚀 Features

### 🔐 **1. Automated CIS Level-1 Hardening**

* Ubuntu 24.04 Desktop L1
* Windows 11 Desktop L1

Includes:
✔️ UFW / Windows Firewall enforcement
✔️ Password policies
✔️ SSH/RDP restrictions
✔️ Service & port lockdown
✔️ File permission hardening
✔️ Kernel security (ASLR, ICMP rules, etc.)

---

### 📊 **2. System Audit Engine**

Generates detailed JSON reports containing:

* Ports
* Users & groups
* Services
* Screen lock status
* Firewall rules
* Password & account policies

---

### 📁 **3. Snapshot & Rollback System**

Safe testing with:

* Snapshot Before
* Snapshot After
* Full automatic restore
* No data loss guarantees

---

### 🧩 **4. Drift Detection (Before vs After)**

Compares audit JSONs and highlights:

* Added/removed services
* Opened/closed ports
* Changed policies
* User account changes

---

### 🤖 **5. AI-Driven Security Explanations (Local)**

Powered by **Ollama + Phi-3**, completely offline.

Outputs:

* Risk severity
* Human-readable explanation
* Exact fix steps
* Mapping to CIS & NIST controls

---

### 🖥️ **6. Cross-Platform Interfaces**

| Platform  | Interface         | Status                   |
| --------- | ----------------- | ------------------------ |
| Linux     | Bash TUI (dialog) | ✔️ Complete              |
| Windows   | Rust GUI          | ✔️ Complete              |
| Dashboard | React + Flask     | ✔️ Full Version Complete |
| AI Engine | Ollama            | ✔️ Integrated            |

---

## 🧰 Tech Stack

### **Backend & System Automation**

* Bash 5.2
* PowerShell 5.1
* Python + Flask
* jq / ss / UFW
* Windows CMD utilities

### **Frontend**

* Rust (eframe + egui) – Windows GUI
* Dialog TUI – Linux
* React + Vite
* Tailwind CSS
* Chart.js

### **AI Engine**

* Ollama + Phi-3 mini
* Completely offline inference

---

## 🏗 Architecture Overview

```
                    ┌──────────────────────────┐
                    │     React Dashboard       │
                    └────────────┬─────────────┘
                                 │ REST API
                      ┌──────────┴───────────┐
                      │     Flask Backend    │
                      └───────┬─────┬────────┘
                 Snapshot/AI  │     │ Audit/Drift
       ┌──────────────────────┘     └─────────────────────────┐
       │                                                      │
┌──────▼───────┐                                     ┌────────▼────────┐
│  Linux TUI   │                                     │  Windows GUI    │
│  Bash + TUI  │                                     │  Rust + PS      │
└──────┬───────┘                                     └────────┬────────┘
       │ Scripts                                              │ Scripts
       │                                                      │
┌──────▼─────────┐                                 ┌──────────▼─────────┐
│ Linux Scripts  │                                 │ Windows Scripts    │
│ auditor.sh     │                                 │ Auditor.ps1        │
│ hardener.sh    │                                 │ Hardener.ps1       │
│ snapshot.sh    │                                 │ Snapshot.ps1       │
└────────────────┘                                 └────────────────────┘
```

---

## ⚙ Installation

### **1. Clone the Repository**

```
git clone https://github.com/<your-username>/HardSecNet.git
cd HardSecNet
```

---

### **2. Install Dependencies**

#### **Linux**

```
sudo apt install dialog jq ufw curl
```

#### **Windows**

* Install Rust
* Run `Install-Ollama.ps1`
* Enable script execution:

```
Set-ExecutionPolicy Bypass -Scope Process
```

#### **Backend**

```
pip install -r backend/requirements.txt
```

#### **Frontend**

```
cd dashboard
npm install
```

---

## ▶ Usage

### **Linux TUI**

```
cd linux/
./run.sh
```

### **Windows GUI**

```
cd windows/GUI
cargo run
```

### **Dashboard**

```
cd dashboard
npm run dev
```

### **Backend API**

```
cd backend
python app.py
```

---

## 📂 Folder Structure

```
HardSecNet/
│
├── linux/
│   ├── auditor.sh
│   ├── hardener.sh
│   ├── dehardener.sh
│   ├── snapshot.sh
│   └── comparison.sh
│
├── windows/
│   ├── scripts/
│   │   ├── Auditor.ps1
│   │   ├── Hardener.ps1
│   │   ├── Dehardener.ps1
│   │   ├── Snapshot.ps1
│   │   └── Compare.ps1
│   └── gui/
│       └── rust-app/
│
├── backend/
│   └── app.py
│
├── dashboard/
│   ├── src/
│   └── package.json
│
├── ai/
│   └── prompts/
│
└── README.md
```

---

## 🧠 AI Explainability Engine

HardSecNet uses **Ollama + Phi-3** to generate:

* Risk analysis
* Human-readable explanation
* Mapping to CIS/NIST controls
* Recommended commands to fix issues
* Severity scoring

Runs offline using:

```
ollama run phi3
```

---

## 📸 Screenshots

(Add your actual screenshots)

```
[ Linux TUI ]
[ Windows GUI ]
[ Dashboard Charts ]
[ JSON Audit Output ]
```

---

## 🗺 Roadmap

### ✅ Completed

* Linux TUI
* Windows GUI
* Automation Engine
* Drift Detection
* Snapshot System
* Local AI Integration
* Dashboard & API
* Unified JSON format

### 🔜 Future (v2.0)

* Multi-node support
* Enterprise reporting
* Live monitoring (Prometheus)
* Container hardening

---

## 🤝 Contributing

1. Fork the repo
2. Create your feature branch
3. Commit changes
4. Submit pull request

---

## 👥 Contributors

* Rahul Nawale
* Tushar Satpute
* Siddharth Magdum

## 📄 License

MIT License
