#!/usr/bin/env bash
cat <<'JSON'
{"schema_version":"1.1","commands":[{"argv":["help-json"]}],"exit_codes":{"0":"PASS","1":"FAIL","2":"BLOCKED_EXTERNAL","3":"MISCONFIGURED","4":"UNSAFE_OPERATION_REFUSED"}}
JSON
