# TASK-127 Evidence 38 - README Command Catalog

Date: 2026-05-27

`tools/agent/README.md` now includes one-line TASK-127 command examples for Codex/Cursor/Claude:

- preflight and head consistency;
- iOS summary tests;
- iOS Options performance smoke;
- Android Options performance audit;
- scanner self-tests;
- top-level TASK-127 scanner gates;
- final gate scan.

The README explicitly states that TASK-127 scanners are top-level `scan` commands and must not be invoked as `ios scan`.

