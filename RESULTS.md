# Results

> **Archive.** These four rows were measured on 3–4 August 2026, before this repo
> was published — while the held-out tests were still private. Tasks 01 and 02 are
> retired examples now, so new rows for them would not be contamination-free. The
> table stays because it shows what a results table should record, and what it
> should refuse to claim.

Each row is one model working one task inside one agent harness.
`completed` means the held-out tests passed, at least the task's minimum number
of tests actually ran, and no compiler suppressions were added — plus a clean
compile for tasks whose `grading.conf` sets `requires_clean_compile=yes`.
`notes` says why a row is not completed, and is empty on a pass.

`run` is the row's link to its evidence — `runs/<run>.diff.log` is what the
model actually wrote, `runs/<run>.test.log` and `.compile.log` are the raw
output. Those live under `runs/`, which is gitignored and gets cleaned up, so
the id may outlive the logs; it still identifies which round produced the row.
Two runs of the same cell are distinguished by a `-2` suffix.

`tests` is `<ran>/<floor>` — how many tests actually ran, against the task's
`min_tests`. Above the floor means the model wrote tests of its own. A `?`
numerator means the count could not be read from the log, which never passes.

Measured by the harness: `completed`, `tests`, `compile`, `notes`.
Typed in by the operator and unverified: `cost` always, `duration` whenever
`--duration` was passed, and the `model` and `harness` labels.

| run | task | model | harness | completed | tests | duration | cost | compile | notes |
|---|---|---|---|---|---|---|---|---|---|
| 2026-08-03-opus5-01 | 01-live-orders | opus5 | claude-code | yes | 35/32 | 5m | $2.83 | clean |  |
| 2026-08-03-opus5-02 | 02-type-clean | opus5 | claude-code | yes | 52/41 | 2m | $0.88 | clean |  |
| 2026-08-04-mixed-01 | 01-live-orders | mixed | ampcode | yes | 33/32 | 2m | $0.99 | clean |  |
| 2026-08-04-gpt-56-02 | 02-type-clean | gpt-56 | ampcode | yes | 51/41 | 3m | $1.03 | clean |  |
