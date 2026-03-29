#!/usr/bin/env bash

set -euo pipefail

REFERENCE_DIR="/Users/yuyu_liao/personal/kaleidoscope-tools/reference_opensource"
TARGET_BASE_DIR="/Users/yuyu_liao/opensource"

if [[ ! -d "${REFERENCE_DIR}" ]]; then
  echo "Reference directory not found: ${REFERENCE_DIR}" >&2
  exit 1
fi

if [[ ! -d "${TARGET_BASE_DIR}" ]]; then
  echo "Target base directory not found: ${TARGET_BASE_DIR}" >&2
  exit 1
fi

for reference_path in "${REFERENCE_DIR}"/*; do
  if [[ ! -d "${reference_path}" ]]; then
    continue
  fi

  folder_name="$(basename "${reference_path}")"
  target_path="${TARGET_BASE_DIR}/${folder_name}"

  if [[ ! -d "${target_path}" ]]; then
    echo "Skip (missing target folder): ${target_path}"
    continue
  fi

  if [[ ! -d "${target_path}/.git" ]]; then
    echo "Skip (not a git repo): ${target_path}"
    continue
  fi

  echo "Updating ${target_path}"
  (
    cd "${target_path}"
    if git branch --list main >/dev/null 2>&1; then
      git checkout main >/dev/null 2>&1
      git pull --ff-only
    elif git branch --list master >/dev/null 2>&1; then
      git checkout master >/dev/null 2>&1
      git pull --ff-only
    else
      echo "  No main/master branch found in ${target_path}" >&2
    fi
  )

done
