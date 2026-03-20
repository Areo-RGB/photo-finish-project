import { spawnSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { resolve } from 'node:path';

function run(command, args) {
  const result = spawnSync(command, args, {
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  if (result.error) {
    throw result.error;
  }
  return result;
}

function fail(message, detail = '') {
  console.error(message);
  if (detail.trim().length > 0) {
    console.error(detail.trim());
  }
  process.exit(1);
}

const apkPath = resolve(
  process.cwd(),
  'build',
  'app',
  'outputs',
  'flutter-apk',
  'app-debug.apk',
);

if (!existsSync(apkPath)) {
  fail(`Debug APK not found at ${apkPath}. Run "flutter build apk --debug" first.`);
}

const devicesResult = run('adb', ['devices']);
if (devicesResult.status !== 0) {
  fail('Failed to run "adb devices". Ensure adb is installed and in PATH.', devicesResult.stderr);
}

const lines = devicesResult.stdout
  .split(/\r?\n/)
  .map((line) => line.trim())
  .filter((line) => line.length > 0 && !line.startsWith('List of devices attached'));

const readyDeviceIds = lines
  .filter((line) => /\tdevice$/.test(line))
  .map((line) => line.split('\t')[0]);

const ignored = lines.filter((line) => !/\tdevice$/.test(line));
if (ignored.length > 0) {
  console.log(`Ignoring non-ready entries: ${ignored.join(', ')}`);
}

if (readyDeviceIds.length === 0) {
  fail('No ready Android devices found. Connect devices and run "adb devices".');
}

let failedInstalls = 0;
for (const deviceId of readyDeviceIds) {
  console.log(`Installing debug APK on ${deviceId}...`);
  const installResult = run('adb', ['-s', deviceId, 'install', '-r', apkPath]);
  const output = `${installResult.stdout}\n${installResult.stderr}`.trim();

  if (installResult.status !== 0 || !output.includes('Success')) {
    failedInstalls += 1;
    console.error(`Install failed on ${deviceId}.`);
    if (output.length > 0) {
      console.error(output);
    }
    continue;
  }

  console.log(`Install success on ${deviceId}.`);
}

if (failedInstalls > 0) {
  fail(`${failedInstalls} device install(s) failed.`);
}

console.log(`Installed debug APK on ${readyDeviceIds.length} device(s).`);
