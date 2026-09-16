## Per-host terminal colours for SSH.
##
## `ssh my-server` repaints the terminal background while the session is up and
## puts it back on exit, so a remote shell never looks like a local one. Hosts
## with no theme declared are left completely alone -- nothing is sent to the
## terminal at all, so the current background stays exactly as it is.
##
## The map lives in ~/.ssh/themes (override with $SSH_THEMES_FILE), unversioned
## for the same reason ~/.ssh/config.local is: machine names stay off GitHub.
## Format is one host per line, first match wins:
##
##   # <pattern>          <background>  [foreground]
##   my-server            mocha                  # a named flavour
##   build-box            gruvbox
##   my-desktop           foxpuccin
##   *.prod.example.com   ff5555        ffffff   # 6 hex digits, no leading #
##   default              121212                 # optional, see _ssh_theme_reset
##
## <pattern> is a glob matched first against the name as typed (`my-server`),
## then against the hostname ssh resolves it to, so an alias and its FQDN share
## one entry. Colours are either a flavour name from the table below or six hex
## digits WITHOUT a leading `#` -- `#` starts a comment anywhere on the line.
##
## The other half of this file declares a colour for the machine it runs ON,
## rather than for the machines it connects to. One line in ~/.ssh/host-theme
## (or /etc/ssh/host-theme, for every user on the box), same colour syntax
## minus the host pattern:
##
##   gruvbox
##   282828 ebdbb2
##
## That colour is the machine's, so it goes on the window in both directions:
##
##   - over SSH, announced to whoever connects. It reaches a client with none
##     of this installed, because it is just an escape sequence the login shell
##     prints. A client that has its own entry for the host wins: it tells the
##     server to keep quiet by sending LC_SSH_THEME=client (an LC_* name
##     because that is what sshd accepts by default), so the two halves never
##     fight over the same window.
##
##   - locally, on a terminal sitting at the machine itself. `ssh fox` from a
##     laptop and fox's own iTerm then open on one background instead of two,
##     without the colour being written down twice -- both sides resolve the
##     same flavour name through the table below.
##
## Declaring a colour for clients but not for local windows: set
## DOTFILES_NO_LOCAL_THEME=1 on that machine.
##
## Escape hatch if this ever misbehaves: DOTFILES_NO_SSH_THEME=1

_ssh_theme_file="${SSH_THEMES_FILE:-$HOME/.ssh/themes}"
_ssh_theme_host_file="${SSH_HOST_THEME_FILE:-$HOME/.ssh/host-theme}"

# Named themes, as background:foreground. A flavour name sets the foreground
# too, which matters for latte: the profile's grey-on-dark foreground is
# unreadable on it. Anything not listed here can still be given as raw hex.
_ssh_theme_flavour() {
  case "$1" in
    # Catppuccin
    latte)         echo "eff1f5:4c4f69" ;;
    frappe)        echo "303446:c6d0f5" ;;
    macchiato)     echo "24273a:cad3f5" ;;
    mocha)         echo "1e1e2e:cdd6f4" ;;
    # Gruvbox dark, in its three contrast levels (bg0 hard/medium/soft)
    gruvbox)       echo "282828:ebdbb2" ;;
    gruvbox-hard)  echo "1d2021:ebdbb2" ;;
    gruvbox-soft)  echo "32302f:ebdbb2" ;;
    # Catppuccin's pastels rotated warm; matches ~/.tmux.conf.local
    foxpuccin)     echo "1c1612:f3e5da" ;;
    *)             return 1 ;;
  esac
}

_ssh_theme_is_hex() {
  case "$1" in
    [0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]) return 0 ;;
    *) return 1 ;;
  esac
}

# Resolve a (background, foreground) pair from the file into "bg:fg".
_ssh_theme_colours() {
  local bg="$1" fg="$2" flavour

  # Strip an inline comment and keep only the first word: anything that is not
  # exactly six hex digits is not a colour.
  fg="${fg%%[[:space:]]*}"
  case "$fg" in '#'*) fg="" ;; esac
  _ssh_theme_is_hex "$fg" || fg=""

  # Tested for emptiness rather than exit status on purpose: this runs from a
  # shell exit hook, and zsh fires those in subshells too, so the status of a
  # command substitution there is the hook's, not the function's.
  flavour=$(_ssh_theme_flavour "$bg")
  if [ -n "$flavour" ]; then
    [ -n "$fg" ] && flavour="${flavour%%:*}:$fg"
    echo "$flavour"
    return 0
  fi

  if _ssh_theme_is_hex "$bg"; then
    echo "$bg:$fg"
    return 0
  fi

  return 1
}

# Look one name up in the themes file. Echoes "bg:fg" (fg may be empty).
#
# `default` is the restore colour, not a host, so it never matches here -- which
# also means a host actually called `default` cannot be themed.
_ssh_theme_match() {
  local name="$1" pat bg fg

  # zsh does not treat the result of an expansion as a pattern unless
  # GLOB_SUBST is on, so without this `work-*` in the file would only ever
  # match a host literally named `work-*`. localoptions keeps it in here.
  if [ -n "$ZSH_VERSION" ]; then
    setopt localoptions glob_subst
  fi

  [ -n "$name" ] || return 1
  [ -r "$_ssh_theme_file" ] || return 1

  while read -r pat bg fg; do
    case "$pat" in ''|'#'*|default) continue ;; esac
    [ -n "$bg" ] || continue
    case "$bg" in '#'*) continue ;; esac

    # Unquoted on purpose: that is what makes $pat a glob rather than a literal.
    case "$name" in
      $pat) ;;
      *) continue ;;
    esac

    _ssh_theme_colours "$bg" "$fg" && return 0

    printf 'ssh: unknown colour "%s" for %s in %s\n' "$bg" "$pat" "$_ssh_theme_file" >&2
    return 1
  done < "$_ssh_theme_file"

  return 1
}

# The `default` line, if there is one. Matched literally, so a catch-all host
# pattern like `*` cannot accidentally become the restore colour.
_ssh_theme_default() {
  local pat bg fg
  [ -r "$_ssh_theme_file" ] || return 1

  while read -r pat bg fg; do
    [ "$pat" = default ] || continue
    _ssh_theme_colours "$bg" "$fg" && return 0
    return 1
  done < "$_ssh_theme_file"

  return 1
}

# Write OSC sequences to the terminal.
#
# Inside tmux they have to be wrapped: tmux consumes a sequence written to the
# pane instead of passing it on, so the outer terminal never sees it. The DCS
# passthrough form hands it over verbatim (every ESC inside doubled), and needs
# `set -g allow-passthrough on`, which tmux.conf sets.
#
# Test that /dev/tty can be OPENED rather than that it is writable: with no
# controlling terminal the permission check still passes and the write fails.
_ssh_theme_send() {
  local body out esc bel
  esc=$(printf '\033')
  bel=$(printf '\007')
  out=""

  for body in "$@"; do
    if [ -n "$TMUX" ]; then
      out="$out$esc""Ptmux;$esc$esc]$body$bel$esc\\"
    else
      out="$out$esc]$body$bel"
    fi
  done

  if { : > /dev/tty; } 2>/dev/null; then
    printf '%s' "$out" > /dev/tty
  else
    printf '%s' "$out"
  fi
}

# OSC 11 is the background, OSC 10 the foreground. Both are the standard xterm
# codes, so this is not iTerm-specific.
_ssh_theme_apply() {
  local bg="$1" fg="$2"
  [ -n "$fg" ] && _ssh_theme_send "11;#$bg" "10;#$fg" && return 0
  _ssh_theme_send "11;#$bg"
}

# Put the colours back. OSC 111/110 mean "reset to the profile's own value", so
# nothing here has to know what that value is. iTerm2's proprietary spelling of
# the same thing goes out alongside them as a belt-and-braces fallback; a
# terminal that honours neither can pin the restore colour explicitly with a
# `default <hex>` line in the themes file.
_ssh_theme_reset() {
  local had_fg="$1" spec bg fg

  # A window this machine painted for itself comes back to that colour, not to
  # the profile's: on a host with its own theme, `ssh elsewhere` and back has
  # to land on the host's background again, and OSC 111 would strip it down to
  # whatever the iTerm profile happens to be. Exported, so an ssh run from a
  # subshell or a tmux pane restores what is actually on screen.
  spec="$_SSH_THEME_SELF"
  [ -n "$spec" ] || spec=$(_ssh_theme_default)

  if [ -n "$spec" ]; then
    bg="${spec%%:*}"
    fg="${spec#*:}"
    _ssh_theme_apply "$bg" "$fg"
    return
  fi

  if [ "$had_fg" = 1 ]; then
    _ssh_theme_send "111" "110" "1337;SetColors=bg=default" "1337;SetColors=fg=default"
  else
    _ssh_theme_send "111" "1337;SetColors=bg=default"
  fi
}

# The destination, straight from ssh itself. Hand-parsing the command line gets
# the corner cases wrong (`-p 2222`, `-oUser=x`, `--`); `ssh -G` runs the real
# parser and prints both the name as typed (`host`) and what it resolves to
# (`hostname`), without touching the network.
_ssh_theme_dest() {
  command ssh -G "$@" 2>/dev/null | awk '
    $1 == "host"     { host = $2 }
    $1 == "hostname" { hostname = $2 }
    END { if (host != "") print host, hostname }
  '
}

# A remote command means a one-shot run, not a session to sit in -- repainting
# the window for the length of `ssh my-server uptime` is just a flash of colour.
_ssh_theme_interactive() {
  local dest="$1" found=0 a
  shift
  for a in "$@"; do
    [ "$found" = 1 ] && return 1
    case "$a" in
      "$dest"|*@"$dest") found=1 ;;
    esac
  done
  return 0
}

ssh() {
  local names name spec bg fg had_fg ret

  # Bail out before forking anything: no map, no tty to paint, or switched off.
  if [ "$#" -eq 0 ] || [ -n "$DOTFILES_NO_SSH_THEME" ] || [ ! -t 1 ] ||
     [ ! -r "$_ssh_theme_file" ]; then
    command ssh "$@"
    return
  fi

  # One line, two fields: the name as typed and what it resolves to. Split by
  # hand rather than looping over $names -- zsh does not word-split unquoted
  # expansions, so `for name in $names` would see a single mangled string.
  names=$(_ssh_theme_dest "$@")
  [ -n "$names" ] || { command ssh "$@"; return; }

  spec=""
  if _ssh_theme_interactive "${names%% *}" "$@"; then
    for name in "${names%% *}" "${names#* }"; do
      spec=$(_ssh_theme_match "$name")
      [ -n "$spec" ] && break
    done
  fi

  if [ -n "$spec" ]; then
    bg="${spec%%:*}"
    fg="${spec#*:}"
    had_fg=0
    [ -n "$fg" ] && had_fg=1
    _ssh_theme_apply "$bg" "$fg"
  fi

  if [ -n "$spec" ]; then
    # SendEnv rather than SetEnv: it predates OpenSSH 7.8, so an older client
    # does not abort with "Bad configuration option". sshd's stock AcceptEnv is
    # `LANG LC_*`, which is why the variable is named like a locale.
    LC_SSH_THEME=client command ssh -o SendEnv=LC_SSH_THEME "$@"
    ret=$?
  else
    command ssh "$@"
    ret=$?
  fi

  [ -n "$spec" ] && _ssh_theme_reset "$had_fg"
  return $ret
}

## ---------------------------------------------------------------------------
## Server side: announce this host's own colours to whoever connects.
## ---------------------------------------------------------------------------

_ssh_theme_host_spec() {
  local f line
  for f in "$_ssh_theme_host_file" /etc/ssh/host-theme; do
    [ -r "$f" ] || continue
    while read -r line; do
      case "$line" in ''|'#'*) continue ;; esac
      # Same two-field syntax as the client map, minus the host pattern.
      _ssh_theme_colours "${line%% *}" "${line#* }" && return 0
      return 1
    done < "$f"
  done
  return 1
}

# Undo the announcement when the login shell ends. Only the shell that made it
# resets: children and tmux panes inherit _SSH_THEME_ANNOUNCED with their
# parent's pid, so exiting one pane cannot strip the colour from the rest.
_ssh_theme_unannounce() {
  local spec

  [ "$_SSH_THEME_ANNOUNCED" = "$$" ] || return 0

  # Clear the markers BEFORE resetting. zsh runs zshexit hooks on subshell exit
  # as well, so the command substitutions below re-enter this function; without
  # this they would print a second copy of the escapes into the captured
  # output, corrupting the value being read. Clearing _SSH_THEME_SELF is also
  # what stops _ssh_theme_reset putting back the very colour being taken off.
  spec="$_SSH_THEME_SELF"
  unset _SSH_THEME_ANNOUNCED _SSH_THEME_SELF

  # A spec always carries the separator, so an empty tail means "no foreground
  # was set" and only the background needs resetting.
  if [ -n "${spec#*:}" ]; then
    _ssh_theme_reset 1
  else
    _ssh_theme_reset 0
  fi
}

_ssh_theme_announce() {
  local spec bg fg remote=0

  # Only an interactive shell on a real terminal, and only one that no ancestor
  # already painted the window for.
  case $- in *i*) ;; *) return 0 ;; esac
  [ -n "$_SSH_THEME_SELF" ] && return 0
  [ -n "$DOTFILES_NO_SSH_THEME" ] && return 0
  [ -n "$TERM" ] && [ "$TERM" != dumb ] || return 0
  [ -t 1 ] || return 0

  if [ -n "$SSH_CONNECTION" ]; then
    # The client has an entry for this host and has already painted the window
    # from it; announcing over the top would only fight it.
    [ "$LC_SSH_THEME" = client ] && return 0
    remote=1
  else
    [ -n "$DOTFILES_NO_LOCAL_THEME" ] && return 0
  fi

  spec=$(_ssh_theme_host_spec)
  [ -n "$spec" ] || return 0
  bg="${spec%%:*}"
  fg="${spec#*:}"

  _ssh_theme_apply "$bg" "$fg"
  export _SSH_THEME_SELF="$spec"

  # Only a session that ends with the window still standing has a colour to
  # hand back. A local shell exits with the window, and registering the hook
  # anyway would be actively wrong under tmux: panes started after this one do
  # not inherit the marker, so each would match its own pid and the first pane
  # to close would strip the background off all the rest.
  [ "$remote" = 1 ] || return 0

  export _SSH_THEME_ANNOUNCED="$$"

  # add-zsh-hook rather than defining zshexit(), so this does not quietly
  # replace an exit hook something else installed.
  if [ -n "$ZSH_VERSION" ]; then
    autoload -Uz add-zsh-hook
    add-zsh-hook zshexit _ssh_theme_unannounce
  elif [ -n "$BASH_VERSION" ]; then
    trap _ssh_theme_unannounce EXIT
  fi
}

_ssh_theme_announce
