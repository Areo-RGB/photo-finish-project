Issue: active-project state can be lost when Serena initialization calls are run in parallel.
Fix: enforce sequential startup order only: 1) serena.activate_project, 2) serena.check_onboarding_performed, 3) serena.initial_instructions.
Project guard added to AGENTS.md at repo root to prevent recurrence.