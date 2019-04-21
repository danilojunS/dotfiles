local return_status="%{$fg[red]%}%(?..⏎)%{$reset_color%}"

function pyenv_prompt_info () {
  if which pyenv &> /dev/null; then
    echo "%{$fg[yellow]%}%B⑀ %b%{$reset_color%}$(pyenv version-name)%{$reset_color%}"
  fi
}

function rvm_prompt_info () {
  if which rvm &> /dev/null; then
    echo "%{$fg[red]%}%B◇ %b%{$reset_color%}$(rvm current)%{$reset_color%}"
  fi
}

MODE_INDICATOR="%{$fg_bold[red]%}❮%{$reset_color%}%{$fg[red]%}❮❮%{$reset_color%}"

PROMPT='%{$fg[blue]%}%c$(git_prompt_info)$(git_prompt_status) %(!.%{$fg_bold[red]%}#.%{$fg_bold[yellow]%}🍌  ❯%{$reset_color%} '

RPROMPT='${return_status}%{$reset_color%} $(rvm_prompt_info) $(pyenv_prompt_info) $(nvm_prompt_info) %{$fg[cyan]%}[%*]%{$reset_color%}'

ZSH_THEME_GIT_PROMPT_PREFIX=" %{$fg[red]%}\uE0A0%{$reset_color%} %{$fg[red]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_DIRTY=" %{$fg[red]%}✗%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_CLEAN=" %{$fg[green]%}✔%{$reset_color%}"

ZSH_THEME_GIT_PROMPT_ADDED="%{$fg[green]%} ✚"
ZSH_THEME_GIT_PROMPT_MODIFIED="%{$fg[blue]%} ✹"
ZSH_THEME_GIT_PROMPT_DELETED="%{$fg[red]%} ✖"
ZSH_THEME_GIT_PROMPT_RENAMED="%{$fg[magenta]%} ➜"
ZSH_THEME_GIT_PROMPT_UNMERGED="%{$fg[yellow]%} ═"
ZSH_THEME_GIT_PROMPT_UNTRACKED="%{$fg[cyan]%} ✭"

ZSH_THEME_NVM_PROMPT_PREFIX="%{$fg[green]%}%B⬡ %b%{$reset_color%}"
ZSH_THEME_NVM_PROMPT_SUFFIX=""
