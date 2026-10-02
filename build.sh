#!/usr/bin/env bash
# Build the watch face and optionally run it in the simulator.
#   ./build.sh [device]          build bin/<device>.prg (default fenix8pro47mm)
#   ./build.sh [device] --run    build, start the simulator if needed, and load the face
#   ./build.sh --package         build the Connect IQ Store package bin/zweizonen.iq
#                                (release build for every device in manifest.xml)
set -euo pipefail
cd "$(dirname "$0")"

CIQ="$APPDATA/Garmin/ConnectIQ"
SDK="$(cygpath -u "$(tr -d '\r\n' < "$CIQ/current-sdk.cfg")")"
SDK="${SDK%/}"
KEY="${GARMIN_DEVELOPER_KEY:-$HOME/.garmin/developer_key.der}"

if ! command -v java >/dev/null; then
    JDK="$(ls -d "/c/Program Files/Microsoft/jdk-"* 2>/dev/null | tail -1)"
    export PATH="$JDK/bin:$PATH"
fi

mkdir -p bin

if [ "${1:-}" = "--package" ]; then
    "$SDK/bin/monkeyc.bat" -e -r -f monkey.jungle -o bin/zweizonen.iq -y "$KEY" -w
    exit
fi

DEVICE="${1:-fenix8pro47mm}"
"$SDK/bin/monkeyc.bat" -d "$DEVICE" -f monkey.jungle -o "bin/$DEVICE.prg" -y "$KEY" -w

if [ "${2:-}" = "--run" ]; then
    if ! tasklist //FI "IMAGENAME eq simulator.exe" | grep -qi simulator.exe; then
        "$SDK/bin/connectiq.bat" &
        sleep 8
    fi
    "$SDK/bin/monkeydo.bat" "bin/$DEVICE.prg" "$DEVICE"
fi
