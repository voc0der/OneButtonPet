#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
addon_name="OneButtonPet"
toc_file="${repo_root}/${addon_name}.toc"
package_dir="${1:?usage: stage-addon.sh <package-dir>}"
implicit_runtime_files=(
  "Bindings.xml"
)

copy_runtime_path() {
  local relative_path="${1}"
  local source_path="${repo_root}/${relative_path}"
  local target_path="${package_dir}/${relative_path}"

  if [[ ! -e "${source_path}" ]]; then
    echo "Missing runtime file: ${relative_path}" >&2
    exit 1
  fi

  mkdir -p "$(dirname "${target_path}")"
  cp -R "${source_path}" "${target_path}"
}

rm -rf "${package_dir}"
mkdir -p "${package_dir}"

declare -A staged_paths=()

copy_runtime_path "${addon_name}.toc"
staged_paths["${addon_name}.toc"]=1

while IFS= read -r raw_line || [[ -n "${raw_line}" ]]; do
  line="${raw_line%$'\r'}"

  case "${line}" in
    ""|\#*)
      continue
      ;;
  esac

  copy_runtime_path "${line}"
  staged_paths["${line}"]=1
done < "${toc_file}"

for path in "${implicit_runtime_files[@]}"; do
  if [[ -n "${staged_paths[${path}]:-}" ]]; then
    continue
  fi

  if [[ -e "${repo_root}/${path}" ]]; then
    copy_runtime_path "${path}"
  fi
done
