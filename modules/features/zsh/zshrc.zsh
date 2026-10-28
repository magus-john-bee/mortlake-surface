zvm_after_init() {
  autoload -Uz compinit && compinit

  eval "$(@atuin@ init zsh --disable-up-arrow)"

  # IntelliShell setup (config symlink: tmpfiles in intellishell.nix)
  export GIST_TOKEN="$(cat /run/secrets/gh-gist-token 2>/dev/null || true)"
  eval "$(@intelli_shell@ init zsh)"

  source @zsh_fzf_tab@/share/fzf-tab/fzf-tab.plugin.zsh

  zstyle ':completion:*' list-dirs-first true
  zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
  zstyle ':fzf-tab:*' fzf-flags --height=50% --layout=reverse --border
  zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color=always $realpath'
  zstyle ':completion:*' group-name ''
  zstyle ':completion:*:descriptions' format '%F{green}-- %d --%f'
  zstyle ':completion:*:messages' format '%F{purple}-- %d --%f'
  zstyle ':completion:*:warnings' format '%F{red}-- no matches found --%f'
  zstyle ':completion:*:corrections' format '%F{yellow}-- %d (errors: %e) --%f'

  source @zsh_autosuggestions@/share/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh

  eval "$(@zoxide@ init zsh)"
}

alias gaa='git add .'
alias gcb='git checkout -b'
alias gcm='git commit -m'
alias gco='git checkout'
alias gcom='git checkout main'
alias gp='git push'
alias gl='git pull'
alias gsv='git status -vv'
alias glg='git lg'
alias gd='git diff'
alias cht='cht.sh'
alias iig='intelli-shell import gist && intelli-shell export gist'
alias ieg='intelli-shell export gist'
alias ouroboros='uvx --from "ouroboros-ai[mcp]" ouroboros'
alias ooo='uvx --from "ouroboros-ai[mcp]" ouroboros'
alias chub='npx @aisuite/chub'
alias gh-axi='npx gh-axi'
alias chrome-devtools-axi='npx chrome-devtools-axi'
alias zld='zellij --layout dev'
alias ll='ls -al'
alias codegraph='npx @colbymchenry/codegraph'

get_cht() {
  PATH_DIR="$HOME/.local/bin"
  mkdir -p "$PATH_DIR"
  curl https://cht.sh/:cht.sh > "$PATH_DIR/cht.sh"
  chmod +x "$PATH_DIR/cht.sh"
}

tre() { command tre "$@" -e && source "/tmp/tre_aliases_$USER" 2>/dev/null; }

eval "$(@starship@ init zsh)"
source @zsh_syntax_highlighting@/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source @zsh_vi_mode@/share/zsh-vi-mode/zsh-vi-mode.plugin.zsh
