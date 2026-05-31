#!/bin/bash

DIALOG_CANCEL=1
DIALOG_ESC=255
HEIGHT=20
WIDTH=70

display_result() {
    local title=$1
    local file=$2
    dialog --title "$title" --msgbox "$(cat "$file")" 25 85
}

stream_ai_response() {
    local text="$1"
    clear
    echo -e "\033[1;36m=== AI Network Analysis ===\033[0m\n"
    
    set -f # Disable glob expansion for asterisks
    # Print word by word but preserve newlines
    while IFS= read -r line; do
        for word in $line; do
            echo -n "$word "
            sleep 0.05
        done
        echo ""
    done <<< "$text"
    set +f # Re-enable glob expansion
    
    echo -e "\nPress any key to return to menu..."
    read -n 1 -s
}

run_quick_scan() {
    local host=$1
    local tmp_out=$(mktemp)
    local report_file="$BASE_DIR/$REPORT_DIR/report_$(date +%Y-%m-%d_%H-%M).txt"
    
    echo "Target Host: $host" > "$tmp_out"
    echo "Date: $(date)" >> "$tmp_out"
    echo "----------------------------------------" >> "$tmp_out"
    
    (
        echo "10"; bash "$BASE_DIR/tools/ping_check.sh" "$host" >> "$tmp_out" 2>&1
        echo "40"; bash "$BASE_DIR/tools/dns_lookup.sh" "$host" >> "$tmp_out" 2>&1
        echo "70"; bash "$BASE_DIR/tools/port_scan.sh" "$host" >> "$tmp_out" 2>&1
        echo "100"
    ) | dialog --title "Quick Scan" --gauge "Scanning $host..." 8 70 0
    
    display_result "Quick Scan Results ($host)" "$tmp_out"
    
    dialog --title "AI Analysis" --yesno "Would you like AI to analyze these results?" 8 50
    if [ $? -eq 0 ]; then
        (
            echo "50"
            bash "$BASE_DIR/ai/groq_agent.sh" "$tmp_out" > "${tmp_out}_ai" 2>&1
            echo "100"
        ) | dialog --title "AI Analysis" --gauge "Analyzing results with Google Gen AI..." 8 70 0
        
        AI_OUT=$(cat "${tmp_out}_ai")
        stream_ai_response "$AI_OUT"
        echo -e "\n\n--- AI Analysis ---\n$AI_OUT" >> "$tmp_out"
    fi
    
    cp "$tmp_out" "$report_file"
    dialog --title "Report Saved" --msgbox "Report saved to $report_file" 8 50
    rm -f "$tmp_out" "${tmp_out}_ai"
}

run_full_analysis() {
    local tmp_out=$(mktemp)
    local report_file="$BASE_DIR/$REPORT_DIR/report_$(date +%Y-%m-%d_%H-%M).txt"
    
    echo "Target Host: Local System / Network" > "$tmp_out"
    echo "Date: $(date)" >> "$tmp_out"
    echo "----------------------------------------" >> "$tmp_out"
    
    (
        echo "10"; bash "$BASE_DIR/tools/ping_check.sh" "$DEFAULT_HOST" >> "$tmp_out" 2>&1
        echo "25"; bash "$BASE_DIR/tools/traceroute_check.sh" "$DEFAULT_HOST" >> "$tmp_out" 2>&1
        echo "40"; bash "$BASE_DIR/tools/dns_lookup.sh" "$DEFAULT_HOST" >> "$tmp_out" 2>&1
        echo "55"; bash "$BASE_DIR/tools/port_scan.sh" "$DEFAULT_HOST" >> "$tmp_out" 2>&1
        echo "70"; bash "$BASE_DIR/tools/netstat_check.sh" >> "$tmp_out" 2>&1
        echo "85"; bash "$BASE_DIR/tools/speed_test.sh" >> "$tmp_out" 2>&1
        echo "100"
    ) | dialog --title "Full Network Analysis" --gauge "Running comprehensive scan..." 8 70 0
    
    display_result "Full Network Analysis Results" "$tmp_out"
    
    dialog --title "AI Analysis" --yesno "Would you like AI to analyze these results?" 8 50
    if [ $? -eq 0 ]; then
        (
            echo "50"
            bash "$BASE_DIR/ai/groq_agent.sh" "$tmp_out" > "${tmp_out}_ai" 2>&1
            echo "100"
        ) | dialog --title "AI Analysis" --gauge "Analyzing results with Google Gen AI..." 8 70 0
        
        AI_OUT=$(cat "${tmp_out}_ai")
        stream_ai_response "$AI_OUT"
        echo -e "\n\n--- AI Analysis ---\n$AI_OUT" >> "$tmp_out"
    fi
    
    cp "$tmp_out" "$report_file"
    dialog --title "Report Saved" --msgbox "Report saved to $report_file" 8 50
    rm -f "$tmp_out" "${tmp_out}_ai"
}

check_specific_host() {
    local host=$(dialog --title "Specific Host" --inputbox "Enter hostname or IP address:" 8 40 "$DEFAULT_HOST" 3>&1 1>&2 2>&3)
    local exit_status=$?
    
    if [ $exit_status -eq 0 ] && [ -n "$host" ]; then
        run_quick_scan "$host"
    fi
}

view_saved_reports() {
    if [ ! -d "$BASE_DIR/$REPORT_DIR" ] || [ -z "$(ls -A "$BASE_DIR/$REPORT_DIR")" ]; then
        dialog --title "Saved Reports" --msgbox "No reports found." 8 40
        return
    fi
    
    local files=()
    for f in "$BASE_DIR/$REPORT_DIR"/*.txt; do
        if [ -f "$f" ]; then
            files+=("$(basename "$f")" "")
        fi
    done
    
    if [ ${#files[@]} -eq 0 ]; then
        dialog --title "Saved Reports" --msgbox "No reports found." 8 40
        return
    fi
    
    local choice=$(dialog --title "Saved Reports" --menu "Select a report to view:" 15 60 8 "${files[@]}" 3>&1 1>&2 2>&3)
    if [ $? -eq 0 ]; then
        display_result "Report: $choice" "$BASE_DIR/$REPORT_DIR/$choice"
    fi
}

while true; do
    exec 3>&1
    selection=$(dialog \
        --backtitle "AI Network Analyzer" \
        --title "Main Menu" \
        --clear \
        --cancel-label "Exit" \
        --menu "Please select an option:" $HEIGHT $WIDTH 5 \
        "1" "Quick Scan (ping + DNS + ports)" \
        "2" "Full Network Analysis" \
        "3" "Check Specific Host" \
        "4" "View Saved Reports" \
        "5" "Exit" \
        2>&1 1>&3)
    exit_status=$?
    exec 3>&-

    if [ $exit_status -ne 0 ]; then
        clear
        echo "Exiting..."
        exit
    fi

    case $selection in
        1)
            run_quick_scan "$DEFAULT_HOST"
            ;;
        2)
            run_full_analysis
            ;;
        3)
            check_specific_host
            ;;
        4)
            view_saved_reports
            ;;
        5)
            clear
            echo "Exiting AI Network Analyzer..."
            exit
            ;;
    esac
done
