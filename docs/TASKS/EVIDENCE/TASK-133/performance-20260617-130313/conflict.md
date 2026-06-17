# Conflict runtime gate

Status: NOT_RUN / REVIEW_REQUIRED.

Required by TASK-133:
- Same product + type + effectiveAt with different price must create conflict/protected state.
- Remote deleted + local edited must create conflict/protected state.
- No silent overwrite and no automatic resurrect.

Evidence currently available:
- Targeted policy tests cover conflict/fail-closed behavior in code.
- Clean no-push and parity gates passed after cleanup.

Reason this is not PASS:
- The strict live conflict fixture was not implemented/run in the current harness.

