# 🌐 AI Network Analyzer

<p align="center">
  A powerful Bash-based network diagnostic tool powered by Groq's ultra-fast LLaMA 3 AI.
</p>

## ✨ Features

- **Interactive UI**: Fully terminal-based UI using `dialog` with progress bars and menus.
- **Multiple Diagnostic Tools**: Built-in scripts for Ping, Traceroute, DNS Lookups, Port Scanning, Netstat, and Speed Testing.
- **AI-Powered Analysis**: Feeds the raw diagnostic data into Groq's API to analyze security risks, performance issues, and suggests exact fix commands.
- **Streaming Output**: Watch the AI analyze your network word-by-word right inside your terminal.
- **Automated Reporting**: Every analysis is automatically saved as a `.txt` report for future review.

---

## 🚀 Requirements

To run this tool, you need a **Linux** environment (or WSL on Windows). Ensure you have the following packages installed:

- `dialog`
- `jq`
- `curl`
- `nmap`
- `dnsutils` (or `bind-utils`)
- `net-tools`
- `iproute2`

*Note: The script will automatically attempt to install any missing dependencies on first run.*

---

## 🛠️ Setup & Installation

1. **Clone the repository:**
   ```bash
   git clone <your-repository-url>
   cd ai-network-analyzer
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
   - Open `config.sh` and add your [Groq API Key](https://console.groq.com/keys):
     ```bash
     export GROQ_API_KEY="your-groq-api-key-here"
     ```

---

## 🎮 Usage

Simply run the main analyzer script from your terminal:

```bash
./analyzer.sh
```

### Main Menu Options:
1. **Quick Scan:** Runs a fast Ping, DNS, and Port scan on the default host.
2. **Full Network Analysis:** Runs all diagnostic tools for a comprehensive system check.
3. **Check Specific Host:** Allows you to input any IP or Domain (e.g., `google.com`) to analyze.
4. **View Saved Reports:** Read previously generated analysis reports.

---

## 📁 Project Structure

```text
ai-network-analyzer/
├── analyzer.sh          # Main entry script
├── config.sh            # API keys and environment variables (Not tracked in Git)
├── config.example.sh    # Example config template
├── tools/               # Network diagnostic scripts
├── ai/                  # Groq API integration and prompt handling
├── ui/                  # Dialog-based terminal interface
└── reports/             # Auto-generated analysis reports
```

---

## 🤝 Contributing
Feel free to open issues or submit pull requests if you want to add more network tools or improve the AI prompts!
