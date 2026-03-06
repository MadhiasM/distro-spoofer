#!/bin/bash

# Resolve the directory where this script lives, regardless of where it is called from
SCRIPT_DIR=$(dirname "$(realpath "$0")")

# Konstante
SECONDS_PER_MINUTE=60
BAR_LENGTH=20  # Progress bar length

# Cleanup-Funktion
cleanup() {
    echo -e "\n⚠️  Script aborted – restoring original file..."
    sudo cp "$SCRIPT_DIR/os-release.orig" /etc/os-release 2>/dev/null || true
    exit
}

# Trap on abort (Strg+C) or exit
trap cleanup SIGINT SIGTERM

read -p "Enter duration for spoofing the OS in minutes: " delay
delay=${delay:-10}

# time conversion
total=$((delay * SECONDS_PER_MINUTE))

# Check that the spoof file exists before making any changes
if [ ! -f "$SCRIPT_DIR/os-release.spoof" ]; then
    echo "❌ Error: Spoof file '$SCRIPT_DIR/os-release.spoof' not found. Aborting." >&2
    exit 1
fi

# backup original os-release for later restoration
sudo mv /etc/os-release "$SCRIPT_DIR/os-release.orig"

# Copy the spoof file; restore the original if this fails
if ! sudo cp "$SCRIPT_DIR/os-release.spoof" /etc/os-release; then
    echo "❌ Error: Failed to copy spoof file. Restoring original..." >&2
    sudo mv "$SCRIPT_DIR/os-release.orig" /etc/os-release
    exit 1
fi

sudo systemctl start intune-daemon.service

echo "⏳ Spoofing started for $delay minutes..."

# progress bar
for ((i=1; i<=delay; i++)); do

    percent=$(( (i * 100) / delay ))
    filled=$(( (i * BAR_LENGTH) / delay ))
    empty=$((BAR_LENGTH - filled))

    bar=$(printf "%0.s█" $(seq 1 $filled))
    spaces=$(printf "%0.s░" $(seq 1 $empty))

    echo -ne " ${bar}${spaces} ${percent} %  (${i}/${delay} min)\r"
    sleep "$SECONDS_PER_MINUTE"
done

sudo cp "$SCRIPT_DIR/os-release.orig" /etc/os-release

echo -e "\n✅ Spoofing finished, original file restored."


# Colored Progress bar:
# echo -e "\033[31m██████████████████░░░░░░░░░░░░░░░░░░\033[0m"

