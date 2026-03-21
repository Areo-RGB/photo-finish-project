Consolidated Serena Kotlin LSP recovery for `photo-finish` after repeated `initialize cancelled (-32800)` failures.

Resolution:
- Re-enabled Kotlin in project languages (`[dart, kotlin]`).
- Pinned Kotlin LSP to hotfix version `262.1817.0` with increased JVM memory.
- Refreshed Kotlin language server bundle to clear corrupted/stale artifacts.

Validation:
- Standalone Serena symbol operations succeeded for both Dart and Kotlin files after refresh.

Operational caveat:
- Existing long-lived MCP sessions may retain stale state and require restart/reconnect.

Supersession:
- Consolidates and supersedes intermediate disable-only incident notes about Kotlin LSP cancellation.