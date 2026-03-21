Implemented modular Maestro navigation test suite for two-device local-first flow: Setup -> Lobby -> Monitoring -> Lobby.

What was added:
- Stable UI keys for navigation-critical controls and stage titles in race session screen.
- Modular Maestro flow composition under `new-workspace/.maestro/flows` with shared setup/lobby/monitoring steps.
- Entry flow validates role-gating behavior before monitoring starts and verifies host stop returns to lobby.
- Package scripts added for navigation runs and continuous execution.

Validation:
- Race session screen analyze checks passed.
- Maestro CLI availability confirmed for local test execution.