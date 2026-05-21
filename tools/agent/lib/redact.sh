#!/usr/bin/env bash
# Privacy-safe redaction for mc-agent logs and reports.

mc_redact_text() {
  local text="${1:-}"
  if [[ "${MC_REDACT_EMAILS:-1}" == "1" ]]; then
    text="$(printf '%s' "$text" | sed -E 's/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/<REDACTED_EMAIL>/g')"
  fi
  text="$(printf '%s' "$text" | sed -E 's#(https?://[^[:space:]]*[?&](access_token|refresh_token|token|api_key|apikey)=)[^&[:space:]]+#\1<REDACTED>#gi')"
  text="$(printf '%s' "$text" | sed -E 's/(Bearer[[:space:]]+)[A-Za-z0-9._~+\/=-]{8,}/\1<REDACTED_TOKEN>/gi')"
  text="$(printf '%s' "$text" | sed -E 's/eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9._-]+\.[A-Za-z0-9._-]+/<REDACTED_JWT>/g')"
  text="$(printf '%s' "$text" | sed -E 's/(service[_-]?role|refresh_token|access_token|anon[_-]?key)[[:space:]]*[:=][[:space:]]*[^[:space:]"'\''`]+/\1=<REDACTED_SECRET>/gi')"
  text="$(printf '%s' "$text" | sed -E 's/(cli_login_postgres\.|postgres\.|supabase_admin\.|authenticator\.)[a-z0-9]{20}/\1<REDACTED_PROJECT_REF>/g')"
  text="$(printf '%s' "$text" | sed -E 's/(project[_-]?ref[[:space:]:=]+)[a-z0-9]{20}/\1<REDACTED_PROJECT_REF>/gi')"
  text="$(printf '%s' "$text" | sed -E 's/sb_secret_[A-Za-z0-9_-]+/<REDACTED_SUPABASE_SECRET>/gi')"
  text="$(printf '%s' "$text" | sed -E 's/sbp_[A-Za-z0-9]+/<REDACTED_SUPABASE_TOKEN>/g')"
  text="$(printf '%s' "$text" | sed -E 's/[0-9a-f]{48,}/<REDACTED_HEX>/gi')"
  if [[ "${MC_REDACT_PATHS:-1}" == "1" ]]; then
    text="$(printf '%s' "$text" | sed -E "s#/Users/[^/[:space:]'\"]+#<HOME_REDACTED>#g")"
  fi
  if [[ -n "${MC_ANDROID_DEVICE_SERIAL:-}" && "$MC_ANDROID_DEVICE_SERIAL" != "REDACTED_SERIAL" && "$MC_ANDROID_DEVICE_SERIAL" != "<REDACTED_SERIAL>" ]]; then
    text="$(printf '%s' "$text" | sed -E "s/${MC_ANDROID_DEVICE_SERIAL}/<REDACTED_SERIAL>/g")"
  fi
  if [[ -n "${MC_SUPABASE_PROJECT_REF:-}" && "$MC_SUPABASE_PROJECT_REF" != "REDACTED" && "$MC_SUPABASE_PROJECT_REF" != "<REDACTED>" ]]; then
    text="$(printf '%s' "$text" | sed -E "s/${MC_SUPABASE_PROJECT_REF}/<REDACTED_PROJECT_REF>/g")"
  fi
  printf '%s' "$text"
}

mc_redact_file_to_stdout() {
  local file="$1"
  mc_redact_text "$(cat "$file")"
}

mc_redact_file_inplace() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  local tmp
  tmp="$(mktemp)"
  mc_redact_file_to_stdout "$file" > "$tmp"
  mv "$tmp" "$file"
}

mc_scan_sensitive_patterns() {
  cat <<'PATTERNS'
eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9._-]+\.[A-Za-z0-9._-]+
Bearer[[:space:]]+[A-Za-z0-9._~+\/=-]{20,}
(access_token|refresh_token|anon[_-]?key)[[:space:]]*[:=][[:space:]]*[^[:space:]"'`]+
service[_-]?role[[:space:]]*[:=][[:space:]]*[^[:space:]"'`]+
cli_login_postgres\.[a-z0-9]{20}
(project[_-]?ref[[:space:]:=]+)[a-z0-9]{20}
sb_secret_[A-Za-z0-9_-]+
sbp_[A-Za-z0-9]+
[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}
PATTERNS
}
