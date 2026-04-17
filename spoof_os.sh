#!/bin/bash

# Resolve the directory where this script lives, regardless of where it is called from
SCRIPT_DIR=$(dirname "$(realpath "$0")")

# Constants
SECONDS_PER_MINUTE=60
BAR_LENGTH=20  # Progress bar length
LOCK_FILE="$SCRIPT_DIR/spoof.lock"

# Cleanup function
cleanup() {
    echo -e "\n⚠️  Script aborted – restoring original file..."
    if ! sudo cp "$SCRIPT_DIR/os-release.orig" /etc/os-release; then
        echo "❌ Error: Failed to restore original /etc/os-release. Manual intervention required." >&2
    fi
    sudo systemctl stop intune-daemon.service 2>/dev/null || true
    rm -f "$LOCK_FILE"
    exit
}

# Trap on abort (Ctrl+C) or exit
trap cleanup SIGINT SIGTERM

# Cache sudo credentials upfront to avoid repeated password prompts during execution
sudo -v || { echo "❌ Error: Failed to acquire sudo privileges. Aborting." >&2; exit 1; }

# --- Lock file / crash recovery ---

if [ -f "$LOCK_FILE" ]; then
    stored_pid=$(cat "$LOCK_FILE" 2>/dev/null)
    if [ -n "$stored_pid" ] && kill -0 "$stored_pid" 2>/dev/null; then
        echo "❌ Error: Another instance of this script is already running (PID $stored_pid). Aborting." >&2
        exit 1
    else
        echo "⚠️  Stale lock detected (PID ${stored_pid:-unknown} is not running). Recovering from possible crash..."
        # Restore /etc/os-release if it is still in the spoof state
        if [ -f "$SCRIPT_DIR/os-release.spoof" ] && cmp -s /etc/os-release "$SCRIPT_DIR/os-release.spoof"; then
            echo "🔄 Restoring original /etc/os-release from backup..."
            if [ -f "$SCRIPT_DIR/os-release.orig" ]; then
                sudo cp "$SCRIPT_DIR/os-release.orig" /etc/os-release
                echo "✅ Original /etc/os-release restored."
            else
                echo "⚠️  Backup '$SCRIPT_DIR/os-release.orig' not found. Cannot restore automatically." >&2
            fi
        else
            echo "ℹ️  /etc/os-release is not in spoof state. No restoration needed."
        fi
        rm -f "$LOCK_FILE"
        echo "🔓 Stale lock removed. Continuing with normal execution..."
    fi
fi

# Acquire lock atomically using noclobber to prevent race condition
if ! (set -C; echo $$ > "$LOCK_FILE") 2>/dev/null; then
    echo "❌ Error: Cannot acquire lock file '$LOCK_FILE'. Another instance may have just started." >&2
    exit 1
fi

read -p "Enter duration for spoofing the OS in minutes: " delay
delay=${delay:-10}

# Validate that delay is a positive integer
if ! [[ "$delay" =~ ^[0-9]+$ ]] || [ "$delay" -le 0 ]; then
    echo "❌ Error: Duration must be a positive integer (got: '$delay'). Aborting." >&2
    rm -f "$LOCK_FILE"
    exit 1
fi

# time conversion
total=$((delay * SECONDS_PER_MINUTE))

# Check that the spoof file exists before making any changes
if [ ! -f "$SCRIPT_DIR/os-release.spoof" ]; then
    echo "❌ Error: Spoof file '$SCRIPT_DIR/os-release.spoof' not found. Aborting." >&2
    rm -f "$LOCK_FILE"
    exit 1
fi

# backup original os-release for later restoration
if ! sudo mv /etc/os-release "$SCRIPT_DIR/os-release.orig"; then
    echo "❌ Error: Failed to move /etc/os-release to backup. Aborting." >&2
    rm -f "$LOCK_FILE"
    exit 1
fi

# Copy the spoof file; restore the original if this fails
if ! sudo cp "$SCRIPT_DIR/os-release.spoof" /etc/os-release; then
    echo "❌ Error: Failed to copy spoof file. Restoring original..." >&2
    sudo mv "$SCRIPT_DIR/os-release.orig" /etc/os-release
    rm -f "$LOCK_FILE"
    exit 1
fi

sudo systemctl start intune-daemon.service

echo "⏳ Spoofing started for $delay minutes... (press +/- to adjust by 5 min)"

# progress bar – tracks elapsed seconds; re-reads total each iteration so
# +/- adjustments are reflected immediately in both the bar and the ETA
elapsed=0
while [ $elapsed -lt $total ]; do

    elapsed_min=$(( elapsed / SECONDS_PER_MINUTE ))
    total_min=$(( total / SECONDS_PER_MINUTE ))
    percent=$(( (elapsed * 100) / total ))
    filled=$(( (elapsed * BAR_LENGTH) / total ))
    empty=$((BAR_LENGTH - filled))

    bar=$(printf "%0.s█" $(seq 1 $filled))
    spaces=$(printf "%0.s░" $(seq 1 $empty))

    echo -ne " ${bar}${spaces} ${percent}%  (${elapsed_min}/${total_min} min) [+/-: ±5 min]\r"

    # Wait up to 1 s (-t 1); don't echo the character (-s); read exactly 1 char (-n 1)
    if read -r -t 1 -s -n 1 key 2>/dev/null; then
        if [ "$key" = "+" ]; then
            total=$((total + 5 * SECONDS_PER_MINUTE))
        elif [ "$key" = "-" ]; then
            new_total=$((total - 5 * SECONDS_PER_MINUTE))
            total=$(( new_total > elapsed ? new_total : elapsed ))
        fi
    fi

    elapsed=$((elapsed + 1))
done

if ! sudo cp "$SCRIPT_DIR/os-release.orig" /etc/os-release; then
    echo "❌ Error: Failed to restore original /etc/os-release. Manual intervention required." >&2
fi

if ! sudo systemctl stop intune-daemon.service; then
    echo "❌ Error: Failed to stop intune-daemon.service." >&2
fi

rm -f "$LOCK_FILE"
echo -e "\n✅ Spoofing finished, original file restored."


# Colored Progress bar:
# echo -e "\033[31m██████████████████░░░░░░░░░░░░░░░░░░\033[0m"
