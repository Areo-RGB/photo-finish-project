Refactored mobile automation into reusable modular scripts.

Files created:
- scripts/mobile_mcp/mobile_mcp_helpers.ps1
  - Shared helpers for mobile-mcp calls, element parsing/clicking, condition waits, label checks, and project-root resolution.
  - Wait logic now supports state-gated progression with optional timeout and periodic heartbeat logs.
- scripts/mobile_mcp/mobile_mcp_steps.ps1
  - Reusable step functions: build/install/restart app, permissions, setup connection, lobby entry, role assignment, start monitoring.
  - Permission step changed to fast parallel action across both devices (Start-Job on both, max 5s wall time), to avoid long/stuck behavior.
  - Connection/lobby/monitoring flow remains check-until-done (state-gated), not fixed short timeout gating.
- scripts/mobile-mcp-lobby-monitoring.ps1
  - Thin setup orchestrator that dot-sources helper and steps modules and executes the full two-device flow.

Behavioral changes requested by user:
- Modular/import-based script architecture.
- Parallelizable operations for both devices where practical.
- Avoid short timeout-driven progression; proceed when step-done conditions are met.
- Permission step specifically bounded to 5s with parallel taps on both devices.