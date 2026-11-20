#!/usr/bin/env bash
#
# uninstall.sh — remove o plano e devolve os limites de fábrica.
# Rode com: sudo ./uninstall.sh
#
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Rode com sudo: sudo ./uninstall.sh" >&2
    exit 1
fi

systemctl disable --now asus-power-plan.service 2>/dev/null || true

if [ -x /usr/local/bin/asus-power-plan ]; then
    /usr/local/bin/asus-power-plan restore || true
fi

rm -f /etc/systemd/system/asus-power-plan.service
rm -f /etc/udev/rules.d/99-asus-power-plan.rules
rm -f /usr/lib/systemd/system-sleep/90-asus-power-plan
rm -f /usr/local/bin/asus-power-plan

systemctl daemon-reload
udevadm control --reload-rules

echo "Removido. O arquivo /etc/asus-power-plan.conf foi mantido (apague se quiser)."
echo "Reative o gerenciamento padrão do KDE/PPD se necessário."
