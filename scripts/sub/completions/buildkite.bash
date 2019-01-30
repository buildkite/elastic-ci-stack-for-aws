_buildkite() {
  COMPREPLY=()
  local word="${COMP_WORDS[COMP_CWORD]}"

  if [ "$COMP_CWORD" -eq 1 ]; then
    COMPREPLY=( $(compgen -W "$(buildkite commands)" -- "$word") )
  else
    local command="${COMP_WORDS[1]}"
    local completions="$(buildkite completions "$command")"
    COMPREPLY=( $(compgen -W "$completions" -- "$word") )
  fi
}

complete -F _buildkite buildkite
