Issue: Serena symbol tools (`get_symbols_overview`, `find_symbol`) failed in `photo-finish` because language server manager initialization aborted when Kotlin LSP failed during `initialize` with `cancelled (-32800)`. This blocked symbol tools globally.

Change made:
- Updated project config at `C:/Users/paul/projects/photo-finish/.serena/project.yml`.
- `languages` changed from `[dart, kotlin]` to `[dart]`.

Validation:
- Standalone CLI check succeeds:
  - `serena activate-project --project C:/Users/paul/projects/photo-finish` reports `Programming languages: dart`.
  - `serena get-symbols-overview --relative-path lib/main.dart` returns symbols.

Note:
- Existing already-running Serena MCP session (pid 26436 in logs) still held stale config and continued to fail until restart/reconnect.