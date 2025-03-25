#!/bin/bash

# Überprüfung, ob das Skript mit sudo ausgeführt wird
if [ "$EUID" -ne 0 ]; then
    echo "Dieses Skript muss mit sudo ausgeführt werden!"
    echo "Verwendung: sudo $0"
    exit 1
fi

# Funktion zur Überprüfung der benötigten Tools
check_tools() {
    local tools=("lshw" "lspci" "lsusb" "dmidecode" "udevadm" "apt" "grep" "awk" "sort" "uniq" "curl")
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            echo "Fehler: $tool ist nicht installiert. Dieses Skript benötigt standardmäßige Debian-Tools."
            exit 1
        fi
    done
}

# Funktion zur Dateiauswahl
select_file() {
    read -p "Bitte geben Sie den vollständigen Pfad für die Ausgabedatei ein (z.B. /home/user/system_report.txt): " file_path
    
    # Überprüfen, ob das Verzeichnis existiert
    local dir=$(dirname "$file_path")
    if [ ! -d "$dir" ]; then
        echo "Das Verzeichnis $dir existiert nicht. Möchten Sie es erstellen? (j/n)"
        read -r answer
        if [ "$answer" = "j" ]; then
            mkdir -p "$dir" || { echo "Konnte Verzeichnis nicht erstellen"; exit 1; }
        else
            exit 1
        fi
    fi
    
    # Überprüfen, ob Datei existiert
    if [ -f "$file_path" ]; then
        echo "Die Datei existiert bereits. Möchten Sie sie überschreiben? (j/n)"
        read -r answer
        if [ "$answer" != "j" ]; then
            exit 1
        fi
    fi
    
    echo "$file_path"
}

# Funktion zur Treiberanalyse
analyze_drivers() {
    echo -e "\n=== Treiberanalyse ===\n"
    
    # 1. Hardware mit vorhandenen Treibern
    echo "=== Hardware mit vorhandenen Treibern ==="
    echo -e "Kernel-Module:\n$(lsmod | awk '{print $1}' | sort | uniq)\n"
    
    # 2. Unbekannte Hardware
    echo "=== Unbekannte Hardware ==="
    echo -e "PCI-Geräte ohne Treiber:\n$(lspci -k | grep -A 2 -i "Kernel modules:.*$" | grep -B 1 -i "Kernel modules: $\|Kernel driver in use: $")\n"
    echo -e "USB-Geräte ohne Treiber:\n$(lsusb -v 2>/dev/null | grep -B 2 -i "couldn't get")\n"
    
    # 3. Analyse möglicher Treiber aus Repositories
    echo "=== Mögliche Treiber aus Debian Repositories ==="
    local unknown_devices=$(lspci -nn | awk -F'\\[' '{print $2}' | awk -F']' '{print $1}')
    for device in $unknown_devices; do
        echo "Analyse für Gerät: $device"
        apt search "$device" 2>/dev/null | head -5
        echo
    done
    
    # 4. Analyse möglicher Treiber aus Internetquellen
    echo "=== Mögliche Treiber aus Internetquellen ==="
    echo "Hinweis: Diese Analyse erfordert Internetverbindung und ist nicht vollständig automatisiert"
    for device in $unknown_devices; do
        echo "Suche nach Treibern für $device:"
        echo "1. Debian Wiki: https://wiki.debian.org/DeviceDatabase"
        echo "2. Linux Hardware Database: https://linux-hardware.org"
        echo "3. Ubuntu Community: https://help.ubuntu.com/community/HardwareSupport"
        echo "4. Herstellerseite (manuelle Suche empfohlen)"
        echo
    done
}

# Hauptskript
check_tools

# Dateiauswahl durch Benutzer
output_file=$(select_file)

# Systeminformationen sammeln
{
    echo "=== Systemanalyse erstellt am $(date) ==="
    echo "=== Erstellt mit $0 ==="
    
    # Abschnitt 1: Ausführliche PC-Übersicht
    echo -e "\n=== Abschnitt 1: Systemübersicht ===\n"
    echo "=== Betriebssystem ==="
    lsb_release -a 2>/dev/null || cat /etc/os-release
    echo -e "\n=== Kernel-Version ==="
    uname -a
    echo -e "\n=== Uptime ==="
    uptime
    echo -e "\n=== CPU-Auslastung ==="
    top -bn1 | head -5
    echo -e "\n=== Speicherbelegung ==="
    free -h
    echo -e "\n=== Mount-Punkte ==="
    df -h
    echo -e "\n=== Netzwerkkonfiguration ==="
    ip a
    
    # Abschnitt 2: Hardware-Übersicht
    echo -e "\n=== Abschnitt 2: Hardwareübersicht ===\n"
    echo "=== CPU-Informationen ==="
    lscpu || cat /proc/cpuinfo
    echo -e "\n=== RAM-Informationen ==="
    dmidecode --type memory || cat /proc/meminfo
    echo -e "\n=== PCI-Geräte ==="
    lspci -vvv
    echo -e "\n=== USB-Geräte ==="
    lsusb -v 2>/dev/null || lsusb
    echo -e "\n=== Blockgeräte ==="
    lsblk -a
    echo -e "\n=== Grafikkarte ==="
    lspci | grep -i vga
    echo -e "\n=== Audio-Geräte ==="
    lspci | grep -i audio
    echo -e "\n=== Netzwerkgeräte ==="
    lspci | grep -i network
    
    # Detaillierte Hardware-Analyse
    echo -e "\n=== Detaillierte Hardware-Informationen (lshw) ==="
    lshw -short
    
    # Treiberanalyse
    analyze_drivers
    
    echo -e "\n=== Analyse abgeschlossen ==="
} > "$output_file"

# Berechtigungen setzen
chmod 644 "$output_file"

echo -e "\nAnalyse wurde erfolgreich in $output_file gespeichert."
echo "Sie können die Datei mit einem Texteditor oder mit 'less $output_file' anzeigen."
