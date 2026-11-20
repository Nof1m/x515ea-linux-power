#!/usr/bin/env bash
#
# verify.sh — mostra o estado do plano e, opcionalmente, faz um teste de carga.
#
#   ./verify.sh              só mostra o estado atual
#   ./verify.sh --stress 60  roda 60 s de carga em todos os threads e mede
#
# Não precisa de root.
#
set -u

DURATION=60
MODE=status
if [ "${1:-}" = "--stress" ]; then
    MODE=stress
    DURATION=${2:-60}
fi

RAPL=/sys/class/powercap/intel-rapl:0

rf() { [ -r "$1" ] && cat "$1" 2>/dev/null || true; }

pkg_temp() {
    local z v
    for z in /sys/class/thermal/thermal_zone*; do
        [ "$(rf "$z/type")" = "x86_pkg_temp" ] || continue
        v=$(rf "$z/temp")
        [ -n "$v" ] && echo $(( v / 1000 )) && return
    done
    echo 0
}

max_core_temp() {
    local h f v max=0
    for h in /sys/class/hwmon/hwmon*; do
        [ "$(rf "$h/name")" = "coretemp" ] || continue
        for f in "$h"/temp*_input; do
            [ -e "$f" ] || continue
            v=$(rf "$f")
            [ -n "$v" ] || continue
            v=$(( v / 1000 ))
            [ "$v" -gt "$max" ] && max=$v
        done
    done
    echo "$max"
}

avg_mhz() {
    awk '/cpu MHz/{s+=$4;n++} END{if(n) printf "%d", s/n; else print 0}' /proc/cpuinfo
}

fan_rpm() {
    local f
    for f in /sys/devices/platform/asus-nb-wmi/hwmon/hwmon*/fan1_input; do
        [ -e "$f" ] && rf "$f" && return
    done
    echo "?"
}

tcc_file() {
    local f
    for f in /sys/bus/pci/devices/*/tcc_offset_degree_celsius; do
        [ -e "$f" ] && echo "$f" && return
    done
}

show_state() {
    local pl1 pl2 tcc maxpct curmax profile ac

    profile=$(rf /sys/firmware/acpi/platform_profile)
    ac=$(rf /sys/class/power_supply/AC0/online)
    pl1=$(rf "$RAPL/constraint_0_power_limit_uw")
    pl2=$(rf "$RAPL/constraint_1_power_limit_uw")
    [ -n "$pl1" ] && pl1=$(( pl1 / 1000000 ))
    [ -n "$pl2" ] && pl2=$(( pl2 / 1000000 ))
    tcc=$(tcc_file)
    [ -n "$tcc" ] && tcc=$(rf "$tcc")
    maxpct=$(rf /sys/devices/system/cpu/intel_pstate/max_perf_pct)
    curmax=$(rf /sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq)
    [ -n "$curmax" ] && curmax=$(( curmax / 1000 ))

    echo "Perfil ACPI .......: ${profile:-?}"
    echo "Fonte .............: $([ "$ac" = 0 ] && echo bateria || echo 'rede elétrica')"
    echo "PL1 / PL2 .........: ${pl1:-?} W / ${pl2:-?} W"
    echo "TCC offset ........: ${tcc:-?} (throttle em ~$(( 100 - ${tcc:-8} )) °C)"
    echo "max_perf_pct ......: ${maxpct:-?} %"
    echo "scaling_max_freq ..: ${curmax:-?} MHz"
    echo "Temp pacote / core : $(pkg_temp) °C / $(max_core_temp) °C"
    echo "Frequência média ..: $(avg_mhz) MHz"
    echo "Ventoinha .........: $(fan_rpm) RPM"
}

if [ "$MODE" = "status" ]; then
    show_state
    exit 0
fi

echo "Teste de carga: ${DURATION}s em $(nproc) threads"
echo "Pressione Ctrl+C para interromper."
echo
show_state
echo
echo "tempo_s,pkg_C,core_C,freq_media_MHz,fan_RPM"

pids=()
cleanup() {
    for p in "${pids[@]:-}"; do
        kill "$p" 2>/dev/null || true
    done
}
trap cleanup EXIT INT TERM

for _ in $(seq 1 "$(nproc)"); do
    yes > /dev/null &
    pids+=("$!")
done

start=$(date +%s)
peak=0
last_freq=""
while :; do
    now=$(date +%s)
    t=$(( now - start ))
    [ "$t" -ge "$DURATION" ] && break
    p=$(pkg_temp)
    c=$(max_core_temp)
    f=$(avg_mhz)
    rpm=$(fan_rpm)
    [ "$p" -gt "$peak" ] && peak=$p
    [ "$c" -gt "$peak" ] && peak=$c
    last_freq=$f
    echo "$t,$p,$c,$f,$rpm"
    sleep 2
done

cleanup
trap - EXIT INT TERM

echo
echo "Resumo: pico=${peak} °C | frequência no fim=${last_freq} MHz | ventoinha=$(fan_rpm) RPM"
tcc=$(tcc_file)
if [ -n "$tcc" ]; then
    tcc=$(rf "$tcc")
    tcc=${tcc:-8}
    limit=$(( 100 - tcc ))
    if [ "$peak" -ge $(( limit - 1 )) ]; then
        echo "Atenção: o pico encostou no limite do TCC (${limit} °C)."
        echo "Se isso ocorrer em jogos, reduza PERF_PL1_W ou PERF_MAX_MHZ."
    else
        echo "OK: o pico ficou abaixo do limite do TCC (${limit} °C)."
    fi
fi
