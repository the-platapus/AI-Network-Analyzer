# AI Network Analyzer

A powerful Bash-based network diagnostic tool powered by Groq's LLaMA 3 70B AI.

## Requirements
- Linux or WSL environment
- `dialog`, `jq`, `curl`, `nmap`, `dnsutils` (or `bind-utils`), `net-tools`, `iproute2`

## Setup
1. Clone or download this repository.
2. Ensure all scripts are executable:
   ```bash
   chmod +x analyzer.sh tools/*.sh ai/*.sh ui/*.sh
   ```
3. Open `config.sh` and add your Groq API key:
   ```bash
   GROQ_API_KEY="your-groq-api-key-here"
   ```

## Usage
Run the main analyzer script:
```bash
./analyzer.sh
```

Follow the on-screen menus to perform quick scans, full network analysis, or check specific hosts.

## Features
- Interactive terminal UI using `dialog`
- Multiple network diagnostic tools built-in
- AI analysis of network data using Groq's ultra-fast inference
- Streaming AI output effect in terminal
- Auto-generated reports in the `reports` directory
