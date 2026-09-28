_p() { B=$(git symbolic-ref --short HEAD 2>/dev/null); }
PROMPT_COMMAND='printf "\e[6 q";_p; PS1="\[\e[38;5;114m\]\w\[\e[0m\]${B:+ \[\e[38;5;170m\]($B)\[\e[0m\]} \$ "'

[ -f ~/.bash_aliases ] && source ~/.bash_aliases
[ -f ~/.bash_aliases.local ] && source ~/.bash_aliases.local
alias ls='ls --color=auto'
alias grep='grep --color=auto'
