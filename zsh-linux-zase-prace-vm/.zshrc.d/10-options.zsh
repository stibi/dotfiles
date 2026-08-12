# Core shell behaviour.

setopt AUTO_CD              # `cd` is implied when a bare directory is typed.
setopt AUTO_PUSHD           # Every cd pushes onto the dir stack, so `cd -<TAB>` works.
setopt PUSHD_IGNORE_DUPS    # ...without filling that stack with repeats.
setopt PUSHD_SILENT         # Don't print the stack on every cd.

setopt EXTENDED_GLOB        # ^, ~ and (#qual) glob syntax.
setopt GLOB_DOTS            # Globs match dotfiles too.
setopt NO_NOMATCH           # Pass through unmatched globs instead of erroring.

setopt INTERACTIVE_COMMENTS # Allow `# comments` when typing interactively.
setopt LONG_LIST_JOBS       # Verbose job table.
setopt NO_FLOW_CONTROL      # Free up ctrl-s / ctrl-q for keybindings.

unsetopt BEEP               # No terminal bell.
