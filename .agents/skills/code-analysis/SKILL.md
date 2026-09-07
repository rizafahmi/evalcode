---
name: code-analysis
description: "Use this skill for code quality, linting, architecture boundaries, type checking, and anti-pattern analysis with Credo, Dialyxir, Reach, ExDNA, and Elixir/OTP guidelines."
metadata:
  managed-by: usage-rules
---

<!-- usage-rules-skill-start -->
## Additional References

### usage_rules

- [usage_rules](references/usage_rules/usage_rules.md)
- [elixir](references/usage_rules/elixir.md)
- [otp](references/usage_rules/otp.md)

## Searching Documentation

```sh
mix usage_rules.search_docs "search term" -p usage_rules -p credo -p dialyxir -p reach -p ex_dna
```

## Available Mix Tasks

- `mix usage_rules.docs` - Shows documentation for Elixir modules and functions
- `mix usage_rules.install` - Installs usage_rules
- `mix usage_rules.install.docs`
- `mix usage_rules.list` - Lists usage-rules.md and sub-rules (usage-rules/*.md) for dependencies
- `mix usage_rules.search_docs` - Searches hexdocs with human-readable output
- `mix usage_rules.sync` - Sync AGENTS.md and agent skills from project config
- `mix usage_rules.sync.docs`
- `mix credo` - Run code analysis (use `--help` for options)
- `mix credo.gen.check` - Generate a new custom check for Credo
- `mix credo.gen.config` - Generate a new config for Credo
- `mix dialyzer` - Runs dialyzer with default or project-defined flags.
- `mix dialyzer.build` - Build the required PLT(s) and exit.
- `mix dialyzer.clean` - Delete PLT(s) and exit.
- `mix dialyzer.explain` - Display information about Dialyzer warnings.
- `mix js.check` - Lint and format-check TypeScript assets
- `mix reach` - Generate interactive HTML report
- `mix reach.boundaries` - Removed; use mix reach.map --boundaries
- `mix reach.check` - Structural validation and change-safety checks
- `mix reach.concurrency` - Removed; use mix reach.otp --concurrency
- `mix reach.coupling` - Removed; use mix reach.map --coupling
- `mix reach.dead_code` - Removed; use mix reach.check --dead-code
- `mix reach.deps` - Removed; use mix reach.inspect TARGET --deps
- `mix reach.depth` - Removed; use mix reach.map --depth
- `mix reach.effects` - Removed; use mix reach.map --effects
- `mix reach.flow` - Removed; use mix reach.trace
- `mix reach.graph` - Removed; use mix reach.inspect TARGET --graph
- `mix reach.hotspots` - Removed; use mix reach.map --hotspots
- `mix reach.impact` - Removed; use mix reach.inspect TARGET --impact
- `mix reach.inspect` - Inspect one target's dependencies, impact, slices, and context
- `mix reach.map` - Project structure and risk map
- `mix reach.modules` - Removed; use mix reach.map --modules
- `mix reach.otp` - Show OTP state machine analysis
- `mix reach.slice` - Removed; use mix reach.trace TARGET
- `mix reach.smell` - Removed; use mix reach.check --smells
- `mix reach.trace` - Trace data flow, taint paths, and slices
- `mix reach.xref` - Removed; use mix reach.map --data
- `mix ex_dna` - Detect code duplication in your Elixir project
- `mix ex_dna.explain` - Show detailed analysis for a specific clone
<!-- usage-rules-skill-end -->
