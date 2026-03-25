Patched local installed solidlsp Dart adapter to advertise hierarchical document symbols.

File changed:
- C:\Users\paul\AppData\Local\uv\cache\archive-v0\34gxGt7GaFDGybBsrcoLy\Lib\site-packages\solidlsp\language_servers\dart_language_server.py

Change:
- In DartLanguageServer._get_initialize_params(), replaced capabilities {} with textDocument.documentSymbol capabilities:
  - dynamicRegistration: true
  - symbolKind.valueSet: 1..26
  - hierarchicalDocumentSymbolSupport: true
  - tagSupport.valueSet: [1]
  - labelSupport: true

Reason:
- Serena include_body for Dart returned stubs because raw symbols used token-level ranges from SymbolInformation.
- Enabling hierarchical documentSymbol support may allow Dart LS to return DocumentSymbol with fuller ranges.

Follow-up:
- Restart Serena MCP process on port 9121 to apply patch.
- If issue persists, clear .serena/cache/dart and retest find_symbol(include_body=true).