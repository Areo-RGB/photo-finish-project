Installed RE toolchain for Android/Flutter APK analysis on Windows.

Date: 2026-03-20
Base tools root: C:\Tools\reverse

Installed via winget:
- mitmproxy.mitmproxy 12.2.1
- WiresharkFoundation.Wireshark 4.6.4
- PortSwigger.BurpSuite.Community 2026.2.3
- Rizin.Rizin v0.8.2

Installed via pip:
- frida-tools 14.6.1
- objection 1.12.3
- androguard 4.1.3
- pyaxmlparser 0.3.31

Manual binaries:
- apktool: C:\Tools\reverse\apktool\apktool.bat + apktool.jar (3.0.1)
- dex2jar: C:\Tools\reverse\dex2jar\dex-tools-v2.4 (bin contains dex-tools.bat wrapper)
- CFR: C:\Tools\reverse\cfr\cfr.jar (cfr-0.152.jar)
- Ghidra: C:\Tools\reverse\ghidra\ghidra_12.0.4_PUBLIC\ghidraRun.bat

PATH updates (User env):
- C:\Tools\reverse\apktool
- C:\Tools\reverse\dex2jar\bin
- Rizin already available at C:\Program Files\Rizin\bin

Smoke-test workspace:
- C:\Tools\reverse\work\photofinish_20260320
- Pulled APKs: base.apk, split_config.arm64_v8a.apk
- Outputs/logs: aapt_badging.txt, dexdump_f.txt, llvm_objdump_h.txt, rizin_iI.txt, apktool_out_0928, apktool_out_cmd

Notes:
- rizin -A on libapp.so was long-running/hanging in this environment; non-interactive metadata check with rizin -qc "iI;q" succeeded.
- apktool.bat prints "Press any key to continue" when executed under cmd /c due wrapper pause logic.