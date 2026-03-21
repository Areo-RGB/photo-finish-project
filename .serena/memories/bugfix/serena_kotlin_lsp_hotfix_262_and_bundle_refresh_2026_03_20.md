Goal: restore Serena Kotlin LSP in photo-finish while keeping symbol tools working.

What changed:
1) Project config re-enabled Kotlin language server:
- `C:/Users/paul/projects/photo-finish/.serena/project.yml`
- `languages` set to `[dart, kotlin]`.

2) Global Serena LS settings pinned Kotlin LSP to upstream hotfix build:
- `C:/Users/paul/.serena/serena_config.yml`
- `ls_specific_settings.kotlin.kotlin_lsp_version = "262.1817.0"`
- `ls_specific_settings.kotlin.jvm_options = "-Xmx2G"`

3) Forced clean Kotlin LSP bundle refresh:
- Old bundle moved to backup: `C:/Users/paul/.serena/language_servers/static/KotlinLanguageServer/kotlin_language_server_backup_261_20260320`
- New bundle downloaded into default path on next startup.

Diagnosis details:
- Previous failures were `cancelled (-32800)` during initialize.
- After switching to v262, first startup initially raced with bundle extraction and failed once with `JRE not found` while files were still being created.
- Retrying after extraction completed succeeded.

Validation (standalone Serena CLI):
- Dart symbols: `serena get-symbols-overview --relative-path lib/main.dart --project C:/Users/paul/projects/photo-finish` => success.
- Kotlin symbols: `serena get-symbols-overview --relative-path android/app/src/main/kotlin/com/paul/sprintsync/MainActivity.kt --project C:/Users/paul/projects/photo-finish` => `{\"Class\":[\"MainActivity\"]}`.

Note:
- Existing long-lived Serena MCP sessions may still show stale active languages until restarted/reconnected.