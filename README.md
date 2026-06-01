# 🔒 Wi-Fi Security Auditor

<p align="center">
  A Bash-based Wi-Fi security audit tool with AI-assisted analysis and the Aircrack-ng suite.
</p>

## ✨ Features

- **Fully automated AI Wi-Fi security audit**: Select either your connected network or another nearby Wi-Fi and collect security telemetry automatically.
- **Automated reconnaissance**: Uses `airmon-ng`/`airodump-ng` to gather wireless access point data and capture packets.
- **AI-powered security scoring**: Sends all collected data to Google Gen AI and returns a security score, vulnerability findings, and remediation guidance.
- **Report generation**: Saves the complete audit and AI analysis as a `.txt` report in `reports/`.

---

## 🚀 Requirements

To run this tool, you need a **Linux** environment with the following packages installed:

- `dialog`
- `jq`
- `curl`
- `aircrack-ng`
- `iw`
- `wireless-tools`
- `nmap`
- `dnsutils` (or `bind-utils`)
- `net-tools`
- `iproute2`

*Note: The main script can attempt to install missing dependencies automatically if your package manager is supported.*

---

## 🛠️ Setup & Installation

1. **Clone the repository:**
   ```bash
   git clone <your-repository-url>
   cd AI-Network-Analyzer
   ```

2. **Make scripts executable:**
   ```bash
   chmod +x analyzer.sh tools/*.sh ai/*.sh ui/*.sh
   ```

3. **Configure your API Key:**
   - Copy the example config file:
     ```bash
     cp config.example.sh config.sh
     ```
   - Open `config.sh` and add your Google API key:
     ```bash
     export GOOGLE_API_KEY="your-google-api-key-here"
     ```

---

## 🎮 Usage

Run the main auditor script from your terminal:

```bash
./analyzer.sh
```

### Main Menu Options:
1. **Automated Wi-Fi Security Audit:** Choose either your connected Wi-Fi or another nearby network, gather reconnaissance and capture data, then send everything to AI for a security score and audit report.

---

## ⚠️ Important Notes

- Handshake capture requires root privileges and may temporarily disrupt your wireless connection.
- Use this tool only on networks you own or have explicit permission to audit.
- Cracking a handshake is only effective if the capture contains a valid WPA/WPA2 handshake and the wordlist includes the correct passphrase.

---

## 📁 Project Structure

```text
AI-Network-Analyzer/
├── analyzer.sh          # Main entry script
├── config.sh            # API keys and environment variables (Not tracked in Git)
├── config.example.sh    # Example config template
├── tools/               # Wi-Fi audit helper scripts
├── ai/                  # Google Gen AI integration and prompt handling
├── ui/                  # Dialog-based terminal interface
└── reports/             # Auto-generated audit reports
```

---

## 🤝 Contributing
Feel free to open issues or submit pull requests to add more Wi-Fi assessment features or improve the AI analysis prompts.
