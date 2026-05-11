# nelibi se macos, mozna pouzit tu coreutils verzi?
#alias diff='diff --color=auto'
alias grep='grep --color=auto --exclude-dir={.bzr,CVS,.git,.hg,.svn}'
alias g="grep"
alias gi="grep -i"
alias -g G='| grep -i'
alias svim="sudo vim"
alias reload="source ~/.zshrc"
alias ls='ls --color=auto'
alias ping='prettyping'
alias p="ping www.google.com"
alias fuck='sudo $(fc -ln -1)'
alias genpass='openssl rand -base64 16'
#alias genspecpass='LC_ALL=C tr -dc \'A-Za-z0-9!\"#$%&\'\'\'()*+,-./:;<=>?@[\\]^_\`{|}~\' </dev/urandom | head -c 13 ; echo'

alias ti='terraform import'
alias tf='terraform'
alias tg='terragrunt'

alias kubectl=kubecolor
compdef kubecolor=kubectl
alias ku=kubectl
alias ki=kubie


