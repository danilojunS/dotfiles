## Cross-SSH clipboard and file transfer.
##
## Over SSH, pbcopy/pbpaste act on the *remote* clipboard, which is useless.
## These reach the machine you are actually sitting at instead.

# Resolve the Tailscale CLI. It is on PATH on Linux, but lives inside the app
# bundle on macOS, where Homebrew does not put it on PATH.
_tailscale_bin() {
  if command -v tailscale >/dev/null 2>&1; then
    echo tailscale
  elif [ -x /Applications/Tailscale.app/Contents/MacOS/Tailscale ]; then
    echo /Applications/Tailscale.app/Contents/MacOS/Tailscale
  else
    return 1
  fi
}

# rtcopy -- put stdin (or the contents of FILEs) on the clipboard of whichever
# machine your terminal is running on, via the OSC 52 escape sequence.
#
# The data rides the terminal connection itself, so it needs no network path
# back to the client, no open port, and no credentials. It therefore works from
# any host, through any number of SSH hops, for any client.
#
#   cat notes.md | rtcopy
#   rtcopy notes.md
#   git log -1 --format=%H | rtcopy
#
# Requires a terminal that honours OSC 52. In iTerm2 that is
#   Settings > General > Selection > "Applications in terminal may access clipboard"
# and inside tmux it needs `set -g set-clipboard on` (set in tmux.conf).
rtcopy() {
  local data b64
  if [ "$#" -gt 0 ]; then
    data=$(cat -- "$@") || return 1
  else
    data=$(cat)
  fi

  b64=$(printf '%s' "$data" | base64 | tr -d '\r\n')

  # Terminals cap OSC 52 payloads. Fail loudly rather than truncating in
  # silence, which looks like the clipboard simply not updating.
  if [ "${#b64}" -gt 74994 ]; then
    printf 'rtcopy: %s bytes of base64 exceeds the usual OSC 52 limit; use `rtsend` instead\n' "${#b64}" >&2
    return 1
  fi

  # Write to the tty rather than stdout, so `cmd | rtcopy` still works and so a
  # redirected stdout does not swallow the escape sequence.
  # Test that /dev/tty can actually be OPENED, not merely that it is writable:
  # with no controlling terminal the permission check still passes and the
  # write then fails with "device not configured".
  if { : > /dev/tty; } 2>/dev/null; then
    printf '\033]52;c;%s\a' "$b64" > /dev/tty
  else
    printf '\033]52;c;%s\a' "$b64"
  fi
}

# _taildrop_ssh_origin -- which of your devices is SSHing into this machine.
#
# SSH_CONNECTION's first field is the client IP, and on a Tailscale network that
# is the peer's tailnet address, so it maps straight to a device name. Taildrop's
# own target list is used as the authority: matching against it guarantees the
# answer is a device that can actually receive files.
#
# Note: inside tmux, panes opened during an earlier connection keep that
# connection's SSH_CONNECTION (tmux only refreshes it for new panes), so a pane
# predating a reconnect from a different client can resolve to the old device.
_taildrop_ssh_origin() {
  local ts ip name
  ts=$(_tailscale_bin) || return 1
  ip="${SSH_CONNECTION%% *}"
  [ -n "$ip" ] || return 1

  name=$("$ts" file cp --targets 2>/dev/null | awk -F'\t' -v ip="$ip" '$1 == ip { print $2; exit }')

  # Fall back to whois, which also resolves IPv6 client addresses. Its first
  # "Name:" is the machine (a later one is the user), and it returns an FQDN.
  # Confirm the result really is a valid target before trusting it.
  if [ -z "$name" ] && "$ts" whois "$ip" >/dev/null 2>&1; then
    name=$("$ts" whois "$ip" 2>/dev/null | awk '/^ *Name:/ { print $2; exit }')
    name="${name%%.*}"
    [ -n "$name" ] && "$ts" file cp --targets 2>/dev/null \
      | awk -F'\t' -v n="$name" '$2 == n { f = 1 } END { exit !f }' || name=""
  fi

  [ -n "$name" ] || return 1
  echo "$name"
}

# rtsend -- push files to another of your machines over Tailscale (Taildrop).
# No size limit, and a file stays a file. Lands in the target's Downloads
# folder (on Windows that is reachable from WSL at /mnt/c/Users/<you>/Downloads).
#
# With no -t, it sends back to whichever device you are SSHed in from, so the
# common case needs no configuration and stays correct from any client.
#
#   rtsend report.md                    # back to the machine you are sitting at
#   rtsend -t my-laptop a.md b.md
#   some-cmd | rtsend -n output.txt     # send stdin under a chosen name
#   rtsend --targets                    # list what you can send to
#
# Target precedence: -t  >  $TAILDROP_TARGET  >  the SSH client device.
rtsend() {
  local ts target name
  ts=$(_tailscale_bin) || {
    printf 'rtsend: tailscale CLI not found\n' >&2
    return 1
  }
  target=""
  name=""

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -t|--to)     target="$2"; shift 2 ;;
      -n|--name)   name="$2"; shift 2 ;;
      --targets)   "$ts" file cp --targets; return ;;
      -h|--help)
        printf 'usage: rtsend [-t TARGET] [-n NAME] [FILE...]   (no FILE = stdin)\n' >&2
        printf '       rtsend --targets\n' >&2
        printf 'default target: $TAILDROP_TARGET, else the device you are SSHed in from\n' >&2
        return ;;
      *) break ;;
    esac
  done

  [ -n "$target" ] || target="$TAILDROP_TARGET"
  [ -n "$target" ] || target=$(_taildrop_ssh_origin)
  if [ -z "$target" ]; then
    printf 'rtsend: no target. Not in an SSH session from a tailnet device, so pass\n' >&2
    printf '      -t TARGET or set TAILDROP_TARGET. Available targets:\n' >&2
    "$ts" file cp --targets >&2
    return 1
  fi

  if [ "$#" -eq 0 ]; then
    [ -n "$name" ] || name="stdin-$(date +%Y%m%d-%H%M%S).txt"
    "$ts" file cp --name "$name" - "${target}:"
  elif [ -n "$name" ]; then
    "$ts" file cp --name "$name" "$1" "${target}:"
  else
    "$ts" file cp "$@" "${target}:"
  fi
}


# rtpaste -- read the clipboard of the machine you are SSHed in from.
#
# TODO: UNVERIFIED end to end. No client currently accepts SSH back from this
# machine (the MacBook has Remote Login off by design), so this has only been
# exercised through its error paths. Before trusting it, enable SSH on the
# client per the notes below and confirm a real round trip.
#
# This is the one direction OSC 52 cannot do here: it has a query form, but
# iTerm2 deliberately does not implement clipboard *reads* (a remote host could
# otherwise silently exfiltrate whatever you had copied). So rtpaste needs a real
# connection back to the client, which means the client must accept SSH:
#   macOS  System Settings > General > Sharing > Remote Login
#   WSL    sudo service ssh start
# and this machine's key must be in the client's authorized_keys.
#
# Host precedence: $RTPASTE_HOST > the SSH client address.
#
#   rtpaste                  # print the client's clipboard
#   rtpaste > notes.txt
#   rtpaste | grep foo
rtpaste() {
  local host
  host="${RTPASTE_HOST:-${SSH_CONNECTION%% *}}"
  if [ -z "$host" ]; then
    printf 'rtpaste: not in an SSH session; set RTPASTE_HOST to the client\n' >&2
    return 1
  fi

  # Try each platform's clipboard reader in turn, so the client can be macOS,
  # Linux (X11 or Wayland) or Windows/WSL without configuration.
  ssh -o BatchMode=yes -o ConnectTimeout=5 "$host" '
    pbpaste 2>/dev/null ||
    xclip -o -selection clipboard 2>/dev/null ||
    xsel -b 2>/dev/null ||
    wl-paste --no-newline 2>/dev/null ||
    powershell.exe -NoProfile -Command Get-Clipboard 2>/dev/null
  ' 2>/dev/null && return 0

  printf 'rtpaste: could not read the clipboard on %s\n' "$host" >&2
  printf '        Is SSH enabled there, and is this host key authorised?\n' >&2
  printf '        Check with: ssh %s true\n' "$host" >&2
  return 1
}
