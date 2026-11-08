# Antigravity Rules

This project adheres to the canonical engineering instructions in [AGENTS.md](file:///home/ameya/meteora-dl/AGENTS.md).

Key Constraints:
1. Always preserve documentation integrity and update ADRs for architectural shifts.
2. Maintain separate decoupled packages for `media_engine`, `package_manager`, and `media_library`.
3. Never use shell command interpolation with user URLs or parameters.
4. Verify every feature with unit and integration tests.
