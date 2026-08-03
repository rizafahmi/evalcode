# Results

Each row is one model working one task inside one agent harness.
`completed` means the held-out tests passed, at least the task's minimum number
of tests actually ran, and no compiler suppressions were added — plus a clean
compile for tasks whose `grading.conf` sets `requires_clean_compile=yes`.
`notes` says why a row is not completed, and is empty on a pass.

| task | model | harness | completed | duration | cost | compile | notes |
|---|---|---|---|---|---|---|---|
