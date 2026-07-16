# Workspace constraints

- Never create or clone a simulator under any circumstances.
- Do not run UI tests or any command that may create a simulator clone.
- Do not boot, shut down, delete, or otherwise operate a simulator unless the user explicitly authorizes that exact action.
- Prefer static checks and non-simulator builds. Ask before any verification that may start simulator services or impose substantial system load.
