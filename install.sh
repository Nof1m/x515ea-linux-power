#!/usr/bin/env bash
#
# install.sh — instala o plano de energia do ASUS VivoBook X515EA.
# Rode com: sudo ./install.sh
#
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Rode com sudo: sudo ./install.sh" >&2
    exit 1
fi

DIR=$(cd "$(dirname "$0")" && pwd)

if [ -e /etc/asus-power-plan.conf ]; then
    cp -a /etc/asus-power-plan.conf "/etc/asus-power-plan.conf.bak.$(date +%Y%m%d%H%M%S)"
    echo "Configuração anterior salva em /etc/asus-power-plan.conf.bak.*"
fi

install -Dm755 "$DIR/files/usr/local/bin/asus-power-plan" /usr/local/bin/asus-power-plan
install -Dm644 "$DIR/files/etc/asus-power-plan.conf" /etc/asus-power-plan.conf
install -Dm644 "$DIR/files/etc/systemd/system/asus-power-plan.service" /etc/systemd/system/asus-power-plan.service
install -Dm644 "$DIR/files/etc/udev/rules.d/99-asus-power-plan.rules" /etc/udev/rules.d/99-asus-power-plan.rules
install -Dm755 "$DIR/files/usr/lib/systemd/system-sleep/90-asus-power-plan" /usr/lib/systemd/system-sleep/90-asus-power-plan

systemctl daemon-reload
systemctl enable --now asus-power-plan.service
udevadm control --reload-rules
udevadm trigger --action=change --subsystem-match=platform-profile || true

echo
echo "Instalado. Estado atual:"
/usr/local/bin/asus-power-plan status

echo
echo "Agora escolha o plano pelo ícone de energia do KDE (ou powerprofilesctl):"
echo "  Economia de energia -> 12 W / 2,4 GHz / 80 °C"
echo "  Equilibrado         -> 15 W / 3,0 GHz / 85 °C"
echo "  Desempenho          -> 22 W / 3,2 GHz / 85 °C"
echo
echo "Valide com carga:  ./verify.sh --stress 60"
