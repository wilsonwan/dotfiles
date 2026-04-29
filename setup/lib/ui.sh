#!/usr/bin/env bash

terminal_available() {
  [[ -t 0 ]] || [[ -r /dev/tty && -w /dev/tty ]]
}

read_prompt_line() {
  local prompt_text="$1"
  local answer

  if [[ -t 0 ]]; then
    read -r -p "$prompt_text" answer || return 1
  elif [[ -r /dev/tty && -w /dev/tty ]]; then
    printf '%s' "$prompt_text" >/dev/tty
    IFS= read -r answer </dev/tty || return 1
  else
    return 1
  fi

  printf '%s\n' "$answer"
}

prompt_with_default() {
  local prompt="$1"
  local default_value="${2:-}"
  local answer

  if [[ "$AUTO_YES" -eq 1 ]]; then
    printf '%s\n' "$default_value"
    return 0
  fi

  if [[ -n "$default_value" ]]; then
    answer="$(read_prompt_line "${prompt} [${default_value}]: ")" ||
      die "Interactive input for '${prompt}' requires a terminal."
    printf '%s\n' "${answer:-$default_value}"
  else
    answer="$(read_prompt_line "${prompt}: ")" ||
      die "Interactive input for '${prompt}' requires a terminal."
    printf '%s\n' "$answer"
  fi
}

confirm() {
  local prompt="$1"
  local default_answer="${2:-Y}"
  local answer

  if [[ "$AUTO_YES" -eq 1 ]]; then
    return 0
  fi

  answer="$(read_prompt_line "${prompt} [${default_answer}/n]: ")" ||
    die "Interactive confirmation for '${prompt}' requires a terminal."
  answer="${answer:-$default_answer}"
  [[ "$answer" =~ ^[Yy]$ ]]
}

select_default_sections_fzf() {
  local -n ids_ref="$1"
  local -n labels_ref="$2"
  local -n enabled_ref="$3"
  local -n reasons_ref="$4"
  local -a default_lines=()
  local -a optional_lines=()
  local -a selected_ids=()
  local idx line id tmp_file

  for idx in "${!ids_ref[@]}"; do
    if [[ "${enabled_ref[$idx]}" == "1" ]]; then
      default_lines+=("${ids_ref[$idx]}"$'\t'"${labels_ref[$idx]}"$'\t'"default")
      selected_ids+=("${ids_ref[$idx]}")
    else
      optional_lines+=("${ids_ref[$idx]}"$'\t'"${labels_ref[$idx]}"$'\t'"${reasons_ref[$idx]}")
    fi
  done

  if ((${#default_lines[@]})); then
    tmp_file="$(mktemp)"
    mapfile -t default_lines < <(
      printf '%s\n' "${default_lines[@]}" |
        fzf --multi \
            --delimiter=$'\t' \
            --with-nth=2,3 \
            --prompt="Disable defaults > " \
            --header="Tab to disable default sections, Enter to continue" \
            --bind='tab:toggle+down,btab:toggle+up' \
            --bind="enter:execute-silent(sh -c 'if [ -n \"\$1\" ] && [ -f \"\$1\" ]; then cat \"\$1\" > \"\$2\"; else : > \"\$2\"; fi' sh '{+f}' '$tmp_file')+abort" || true
    )
    mapfile -t default_lines <"$tmp_file"
    rm -f "$tmp_file"

    for line in "${default_lines[@]}"; do
      id="${line%%$'\t'*}"
      selected_ids=("${selected_ids[@]/$id}")
      selected_ids=("${selected_ids[@]}")
    done
  fi

  if ((${#optional_lines[@]})); then
    tmp_file="$(mktemp)"
    mapfile -t optional_lines < <(
      printf '%s\n' "${optional_lines[@]}" |
        fzf --multi \
            --delimiter=$'\t' \
            --with-nth=2,3 \
            --prompt="Enable more > " \
            --header="Tab to enable optional or skipped sections, Enter to continue" \
            --bind='tab:toggle+down,btab:toggle+up' \
            --bind="enter:execute-silent(sh -c 'if [ -n \"\$1\" ] && [ -f \"\$1\" ]; then cat \"\$1\" > \"\$2\"; else : > \"\$2\"; fi' sh '{+f}' '$tmp_file')+abort" || true
    )
    mapfile -t optional_lines <"$tmp_file"
    rm -f "$tmp_file"

    for line in "${optional_lines[@]}"; do
      id="${line%%$'\t'*}"
      selected_ids+=("$id")
    done
  fi

  printf '%s\n' "${selected_ids[@]}"
}

select_default_sections_text() {
  local -n ids_ref="$1"
  local -n labels_ref="$2"
  local -n enabled_ref="$3"
  local -n reasons_ref="$4"
  local -a selected_ids=()
  local idx answer number

  echo "Default sections:"
  for idx in "${!ids_ref[@]}"; do
    if [[ "${enabled_ref[$idx]}" == "1" ]]; then
      printf '  %d. %s\n' "$((idx + 1))" "${labels_ref[$idx]}"
      selected_ids+=("${ids_ref[$idx]}")
    fi
  done

  echo
  echo "Not selected by default:"
  for idx in "${!ids_ref[@]}"; do
    if [[ "${enabled_ref[$idx]}" != "1" ]]; then
      printf '  %d. %s (%s)\n' "$((idx + 1))" "${labels_ref[$idx]}" "${reasons_ref[$idx]}"
    fi
  done

  echo
  answer="$(read_prompt_line "Enter numbers to disable from the default set (space-separated, Enter to keep all): ")" ||
    die "Interactive section selection requires a terminal. Re-run in a terminal, or pass --yes/--sections."
  for number in $answer; do
    idx=$((number - 1))
    if [[ "${enabled_ref[$idx]:-0}" == "1" ]]; then
      selected_ids=("${selected_ids[@]/${ids_ref[$idx]}}")
      selected_ids=("${selected_ids[@]}")
    fi
  done

  answer="$(read_prompt_line "Enter numbers to enable from the skipped set (space-separated, Enter to keep as-is): ")" ||
    die "Interactive section selection requires a terminal. Re-run in a terminal, or pass --yes/--sections."
  for number in $answer; do
    idx=$((number - 1))
    if [[ "${enabled_ref[$idx]:-1}" != "1" ]]; then
      selected_ids+=("${ids_ref[$idx]}")
    fi
  done

  printf '%s\n' "${selected_ids[@]}"
}

choose_sections() {
  local ids_name="$1"
  local labels_name="$2"
  local enabled_name="$3"
  local reasons_name="$4"
  local -n ids_ref="$1"
  local -n labels_ref="$2"
  local -n enabled_ref="$3"
  local -n reasons_ref="$4"

  if ((${#SECTIONS_OVERRIDE[@]})); then
    printf '%s\n' "${SECTIONS_OVERRIDE[@]}"
    return 0
  fi

  if [[ "$AUTO_YES" -eq 1 ]]; then
    local idx
    for idx in "${!ids_ref[@]}"; do
      [[ "${enabled_ref[$idx]}" == "1" ]] && printf '%s\n' "${ids_ref[$idx]}"
    done
    return 0
  fi

  terminal_available || die "Interactive section selection requires a terminal. Re-run in a terminal, or pass --yes/--sections."

  if command_exists fzf; then
    select_default_sections_fzf "$ids_name" "$labels_name" "$enabled_name" "$reasons_name"
  else
    select_default_sections_text "$ids_name" "$labels_name" "$enabled_name" "$reasons_name"
  fi
}
