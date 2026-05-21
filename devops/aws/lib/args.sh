#!/usr/bin/env sh
# Parse CLI args: key=value, --key=value, --key value
# Normalizes keys to shell names (aws-region -> aws_region).

load_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      -h|--help)
        return 0
        ;;
      --*=*)
        _arg_key="${1#--}"
        _arg_key="${_arg_key%%=*}"
        _arg_val="${1#*=}"
        _arg_key=$(printf '%s' "$_arg_key" | tr '-' '_')
        eval "${_arg_key}=\"\${_arg_val}\""
        ;;
      --*)
        _arg_key="${1#--}"
        _arg_key=$(printf '%s' "$_arg_key" | tr '-' '_')
        shift
        _arg_val="${1:-}"
        eval "${_arg_key}=\"\${_arg_val}\""
        ;;
      *=*)
        _arg_key="${1%%=*}"
        _arg_val="${1#*=}"
        _arg_key=$(printf '%s' "$_arg_key" | tr '-' '_')
        eval "${_arg_key}=\"\${_arg_val}\""
        ;;
      *)
        echo "Unknown argument: $1" >&2
        return 1
        ;;
    esac
    shift
  done
  return 0
}
