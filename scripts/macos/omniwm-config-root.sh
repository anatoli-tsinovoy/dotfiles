omniwm_config_root() {
  local config_root="${XDG_CONFIG_HOME:-}"
  if [[ -z "$config_root" || "$config_root" != /* ]]; then
    config_root="$HOME/.config"
  fi
  printf '%s\n' "$config_root"
}
