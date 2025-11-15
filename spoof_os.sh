#!/bin/bash

# Konstante
SECONDS_PER_MINUTE=60
BAR_LENGTH=20  # Länge der Fortschrittsleiste (z. B. 20 Zeichen)

# Cleanup-Funktion
cleanup() {
    echo -e "\n⚠️  Script abborted – restoring original file..."
    sudo cp ./os-release.orig /etc/os-release 2>/dev/null || true
    exit
}

# Trap auf Abbruch (Strg+C) oder Exit
trap cleanup SIGINT SIGTERM

read -p "Enter duration for spoofing the OS in minutes: " delay
delay=${delay:-10}

# Minuten in Sekunden umrechnen
total=$((delay * SECONDS_PER_MINUTE))


sudo mv /etc/os-release ./os-release.orig
sudo cp ./os-release.spoof /etc/os-release
sudo systemctl start intune-daemon.service

echo "⏳ Spoofing started for $delay minutes..."

# Fortschrittsanzeige pro Minute
for ((i=1; i<=delay; i++)); do

    percent=$(( (i * 100) / delay ))
    filled=$(( (i * BAR_LENGTH) / delay ))
    empty=$((BAR_LENGTH - filled))

    bar=$(printf "%0.s█" $(seq 1 $filled))
    spaces=$(printf "%0.s░" $(seq 1 $empty))

    echo -ne " ${bar}${spaces} ${percent} %  (${i}/${delay} min)\r"
    sleep "$SECONDS_PER_MINUTE"
done

#sudo mv /etc/os-release.orig /etc/os-release
sudo cp ./os-release.orig /etc/os-release

echo -e "\n✅ Spoofing finished, original file restored."


# Colored Progress bar:
# echo -e "\033[31m██████████████████░░░░░░░░░░░░░░░░░░\033[0m"

