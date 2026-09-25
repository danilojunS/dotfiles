#!/bin/sh

# One line for herdr's tab bar status area (tab_bar_right in config.toml), in
# the spirit of tmux2k's cpu/ram/battery segments. herdr strips colour codes, so
# it is plain text with Nerd Font glyphs for labels. A segment the machine can't
# report (no battery on a desktop) is left out.

# Nerd Font glyphs, as octal UTF-8 so plain /bin/sh printf can emit them
cpu_icon=$(printf '\357\213\233')     # nf-fa-microchip
ram_icon=$(printf '\363\260\215\233') # nf-md-memory
bat_icon=$(printf '\357\211\200')     # nf-fa-battery_full

# Same separator as tab_bar_right_separator in config.toml
sep="  "

parts=

add() { parts="${parts:+$parts$sep}$1"; }

case $(uname) in
Darwin)
  ncpu=$(sysctl -n hw.ncpu)
  add "$cpu_icon $(ps -A -o %cpu= | awk -v n="$ncpu" '{ s += $1 } END { printf "%d%%", s / n }')"

  total=$(sysctl -n hw.memsize)
  add "$ram_icon $(vm_stat | awk -v total="$total" '
    /page size of/            { page = $8 }
    /Pages active/            { used += $3 }
    /Pages wired down/        { used += $4 }
    /occupied by compressor/  { used += $5 }
    END { printf "%d%%", used * page * 100 / total }')"

  batt=$(pmset -g batt 2>/dev/null)
  pct=$(printf '%s\n' "$batt" | grep -o '[0-9]*%' | head -1)
  [ -n "$pct" ] && add "$bat_icon $pct"
  ;;
Linux)
  add "$cpu_icon $(cut -d' ' -f1 /proc/loadavg)"

  add "$ram_icon $(awk '
    /^MemTotal:/     { t = $2 }
    /^MemAvailable:/ { a = $2 }
    END { printf "%d%%", (t - a) * 100 / t }' /proc/meminfo)"

  for b in /sys/class/power_supply/BAT*; do
    [ -r "$b/capacity" ] && add "$bat_icon $(cat "$b/capacity")%" && break
  done
  ;;
esac

echo "$parts"
