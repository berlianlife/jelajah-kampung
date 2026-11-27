#!/bin/bash
# Jelajah-Kampung: auto-update from GitHub + serve on localhost/LAN.
# Jalankan sekali:  bash tools/run_mac.sh
# - Tiap 30 detik cek versi baru (git pull). Kalau ada, cukup reload browser.
# - Server tetap jalan; Ctrl+C untuk berhenti semuanya.
cd "$(dirname "$0")/.." || exit 1

update_loop() {
  while true; do
    before=$(git rev-parse HEAD 2>/dev/null)
    git pull --ff-only --quiet 2>/dev/null
    after=$(git rev-parse HEAD 2>/dev/null)
    if [ "$before" != "$after" ]; then
      echo "[$(date +%H:%M)] Versi baru terpasang: $(git log -1 --pretty=%s). Reload browser (Cmd+Shift+R)."
      osascript -e 'display notification "Versi baru terpasang. Reload browser." with title "Jelajah-Kampung"' 2>/dev/null
    fi
    sleep 30
  done
}

update_loop &
UPD=$!
trap 'kill $UPD 2>/dev/null; exit 0' INT TERM
echo "Auto-update aktif (cek tiap 30 detik)."
python3 tools/serve_web.py --lan
kill $UPD 2>/dev/null
