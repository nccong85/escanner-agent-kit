# Common Pitfalls — the project's defect corpus

Each entry records a defect class that actually happened, so reviewers cite it (`R-PIT-<n>.<m>`) instead of
re-deriving it. Number sections `## <n>.` and entries `### <n>.<m>`; never renumber an existing entry.

## 1. <Area>

### 1.1 <One-line symptom>
- **Symptom:** <what was observed, with the measured number or error text>
- **Cause:** <the root cause, verified>
- **Rule:** <what every future change must do or avoid>
- **Guard:** <the test or lint that now enforces it, or "none yet">
