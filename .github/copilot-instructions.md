# GitHub Copilot Instructions

This repository follows strict modular architecture and security principles.
The canonical guidelines and developer instructions reside in:

👉 **[AGENTS.md](file:///home/ameya/meteora-dl/AGENTS.md)**

### Key Rules for Copilot:
1. Pass process arguments strictly as array/list parameters. Never construct shell strings or use `sh -c`.
2. Do not bypass or attempt to defeat access control, permission checks, or anti-bot challenges.
3. Adhere to Material 3 dark-first Liquid Glass design system in Flutter UI.
4. Support Android ARM64 as primary target.
5. All domain models and algorithms must have unit tests.
