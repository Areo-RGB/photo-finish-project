Verified after Serena restart on port 9121 that Dart find_symbol(include_body=true) now returns full symbol bodies (not stubs).

Checks:
- find_symbol(relative_path='lib/features/race_session/race_session_controller.dart', name_path_pattern='RaceSessionController', include_body=true)
  -> returned class body with range start_line=10, end_line=1683 and full body text.
- find_symbol(... name_path_pattern='requestPermissions', include_body=true)
  -> returned method body with range start_line=252, end_line=276 and full body text.

Conclusion:
- local patch in solidlsp Dart adapter (documentSymbol hierarchical capabilities) is active and effective in this Serena process.