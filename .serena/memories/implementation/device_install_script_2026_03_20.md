Installed Sprint Sync debug APK on currently connected Android devices and added npm tooling for repeat installs.

Execution performed:
- Detected devices with adb devices:
  - 31071FDH2008FK
  - 4c637b9e
- Installed build/app/outputs/flutter-apk/app-debug.apk to both via adb -s <id> install -r.

Files added:
- package.json
  - scripts.install:debug:devices -> node scripts/install-debug-apk.mjs
  - scripts.install:debug:devices:build -> flutter build apk --debug && node scripts/install-debug-apk.mjs
- scripts/install-debug-apk.mjs
  - checks APK path exists
  - runs adb devices and extracts ready entries with status 'device'
  - ignores offline/unauthorized entries
  - installs APK on each detected device via adb -s <id> install -r
  - exits non-zero if any install fails

Verification:
- Ran npm run install:debug:devices
- Result: successful installs on both connected devices, exit code 0.