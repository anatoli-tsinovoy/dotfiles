#!/usr/bin/env bash
# docker shim to make `docker container ls --all --format json`
# look like Docker's JSON (JSON Lines, flat strings, etc.) using Podman + jq

set -euo pipefail

docker_like_ps() {
  podman container ls "$@" --format json |
    jq -r -c '
    # ----- helpers that act on "." and are used via piping -----
    def short12:
      tostring | (if (.|length) >= 12 then .[0:12] else . end);

    def to_str:
      ( . // "" ) | (if type=="number" then tostring else . end);

    def ports_to_string:
      if . == null then ""
      elif type=="string" then .
      elif type=="array" then
        (map(
          if type=="string" then .
          elif type=="object" then
            ((.host_ip // .HostIp // .IP // "")) as $ip
            | ((.host_port // .HostPort // .PublicPort) | tostring?) as $hp
            | ((.container_port // .ContainerPort // .PrivatePort) | tostring?) as $cp
            | ((.protocol // .Proto // .Type // "tcp") | tostring)   as $proto
            | (if ($hp//"") == "" or ($cp//"") == "" then empty
               else (if $ip != "" then "\($ip):\($hp)->\($cp)/\($proto)" else "\($hp)->\($cp)/\($proto)" end)
              end)
          else empty end
        ) | join(", "))
      else "" end;

    def labels_to_string:
      if . == null or . == {} then ""
      elif type=="string" then .
      elif type=="object" then (to_entries | map("\(.key)=\(.value)") | join(","))
      else "" end;

    def mounts_to_string:
      if . == null then ""
      elif type=="string" then .
      elif type=="array" then (map(tostring) | join(", "))
      else "" end;

    def first_name:
      if . == null then ""
      elif type=="string" then .
      elif type=="array" then (.[0] // "")
      else "" end;

    def networks_to_string:
      if . == null then ""
      elif type=="array" then (join(","))
      else (.|to_str)
      end;

    # ----- transform each element from Podman array into JSON Lines -----
    .[] |
    {
      ID:        ((.Id // .ID // "") | short12),
      Names:     (.Names | first_name),
      Image:     (.Image | to_str),
      ImageID:   (.ImageID | to_str),
      Command:   (if (.Command|type)=="array" then (.Command | map(tostring) | join(" ")) else (.Command|to_str) end),
      CreatedAt: (.CreatedAt | to_str),
      RunningFor:(.RunningFor // .CreatedAt | to_str),
      Ports:     (.Ports | ports_to_string),
      State:     (.State | to_str),
      Status:    (.Status | to_str),
      Size:      (.Size | to_str),
      Labels:    (.Labels | labels_to_string),
      Mounts:    (.Mounts | mounts_to_string),
      Networks:  (.Networks | networks_to_string)
    }'
}

# Intercept: docker container ls --all --format json
if [[ "${1-}" == "container" && "${2-}" == "ls" ]]; then
  have_format_json=0
  passthrough=()
  shift 2
  while (("$#")); do
    case "$1" in
    --format)
      shift
      if [[ "${1-}" == "json" ]]; then have_format_json=1; else passthrough+=(--format "$1"); fi
      ;;
    --format=*)
      if [[ "${1#--format=}" == "json" ]]; then have_format_json=1; else passthrough+=("$1"); fi
      ;;
    -a | --all | --no-trunc | --size | -n | --last | --quiet | -q | --since | --before | --filter*)
      # pass through flag (and value if separate)
      if [[ "$1" =~ ^(--filter|-n|--last|--since|--before)$ ]]; then
        flag="$1"
        shift
        passthrough+=("$flag" "${1-}")
      else
        passthrough+=("$1")
      fi
      ;;
    *)
      passthrough+=("$1")
      ;;
    esac
    shift || true
  done

  if [[ $have_format_json -eq 1 ]]; then
    docker_like_ps "${passthrough[@]}"
    exit $?
  fi
fi

# Everything else just delegates to podman
exec podman "$@"
