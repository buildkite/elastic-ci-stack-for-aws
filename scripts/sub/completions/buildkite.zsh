if [[ ! -o interactive ]]; then
    return
fi

compctl -K _buildkite buildkite

_buildkite() {
  local word words completions
  read -cA words
  word="${words[2]}"

  if [ "${#words}" -eq 2 ]; then
    completions="$(buildkite commands)"
  else
    completions="$(buildkite completions "${word}")"
  fi

  reply=("${(ps:\n:)completions}")
}
