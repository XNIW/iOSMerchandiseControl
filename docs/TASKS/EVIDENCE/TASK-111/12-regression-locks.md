# TASK-111 — 12 Regression Locks RL-01…RL-10

| Lock | Stato | Evidence |
|---|---|---|
| RL-01 Parser/header no crash | ESEGUITO | Task111 7/7, HTML parser 9/9 |
| RL-02 Numeric/pricing/discount | ESEGUITO | Task111 locale/discount tests |
| RL-03 Duplicate policy | ESEGUITO | Task111 duplicate test |
| RL-04 Row errors non bloccano validi | ESEGUITO | Task111 validation test |
| RL-05 Preview side-effect-free | ESEGUITO | Task111 preview test |
| RL-06 ProductPrice previous/current | ESEGUITO | Task111 history + Task100 medium |
| RL-07 Supplier/category resolver | ESEGUITO | Task111 resolver test |
| RL-08 UX apply explicit/errors excluded | ESEGUITO | Build + ImportAnalysis code + simulator smoke |
| RL-09 Performance/MainActor | ESEGUITO | Task100/105 benchmarks + background audit |
| RL-10 Supabase boundary | ESEGUITO | No Supabase mutation/service_role; TASK-109 not reopened |

## NOT_RUN

- Manual Dynamic Type/VoiceOver lock: NOT_RUN, recorded as review/follow-up candidate.
