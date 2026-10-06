#!/usr/bin/env python3
"""Build and launch the actual Debug app on an iOS 26/27 simulator, then capture UI states."""
from pathlib import Path
import json
import os
import re
import subprocess
import time

root = Path(__file__).resolve().parents[1]
os.chdir(root)
major = int(os.environ.get('REQUIRED_IOS_MAJOR', '26'))
prefix = 'ios' + str(major)
output = root / 'artifacts/previews'
output.mkdir(parents=True, exist_ok=True)

def run(args, check=True):
    result = subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if check and result.returncode != 0:
        print(result.stdout[-12000:], flush=True)
        print('::error::Simulator command failed: ' + ' '.join(args[:5]), flush=True)
        result.check_returncode()
    return result

devices = json.loads(run(['xcrun', 'simctl', 'list', 'devices', 'available', '--json']).stdout)['devices']
choices = []
for runtime, entries in devices.items():
    version = re.search(r'iOS-(\d+)(?:-(\d+))?', runtime)
    if not version or int(version.group(1)) != major:
        continue
    for device in entries:
        if device.get('isAvailable') and device['name'].startswith('iPhone'):
            priority = 3 if device['name'] == 'iPhone 17 Pro' else 2 if device['name'] == 'iPhone 16 Pro' else 1
            choices.append((int(version.group(2) or 0), priority, device))
assert choices, f'No available iOS {major} iPhone simulator runtime; cannot claim visual validation.'
_, _, device = max(choices, key=lambda x: (x[0], x[1]))
udid = device['udid']
print(f'Using {device["name"]} / iOS {major} simulator {udid}', flush=True)
if device['state'] != 'Booted':
    run(['xcrun', 'simctl', 'boot', udid])
print(run(['xcrun', 'simctl', 'bootstatus', udid, '-b']).stdout, flush=True)
run(['defaults', 'write', 'com.apple.iphonesimulator', 'ConnectHardwareKeyboard', '-bool', 'NO'], check=False)
run(['xcrun', 'simctl', 'status_bar', udid, 'override', '--time', '9:41', '--batteryState', 'charged', '--batteryLevel', '100', '--wifiMode', 'active', '--wifiBars', '3', '--cellularMode', 'active', '--cellularBars', '4'], check=False)

args = ['xcodebuild', '-project', 'ChatNative.xcodeproj', '-scheme', 'ChatNative', '-configuration', 'Debug', '-sdk', 'iphonesimulator', '-destination', 'id=' + udid, '-derivedDataPath', str(root / '.ci-simulator'), '-clonedSourcePackagesDirPath', str(root / '.ci-packages'), 'CODE_SIGNING_ALLOWED=NO', 'build']
with (root / 'artifacts/simulator-build.log').open('w') as log:
    result = subprocess.run(args, stdout=log, stderr=subprocess.STDOUT)
if result.returncode != 0:
    text = (root / 'artifacts/simulator-build.log').read_text(errors='replace')
    for line in text.splitlines():
        if 'error:' in line:
            print('::error::' + line.replace('%', '%25'), flush=True)
    print(text[-12000:], flush=True)
    raise RuntimeError('Simulator build failed; see artifacts/simulator-build.log.')
app = root / '.ci-simulator/Build/Products/Debug-iphonesimulator/ChatNative.app'
run(['codesign', '--force', '--deep', '--sign', '-', str(app)])
run(['xcrun', 'simctl', 'install', udid, str(app)])
for mode in ['home', 'chat', 'code', 'sidebar', 'models', 'settings', 'voice', 'dark', 'keyboard']:
    run(['xcrun', 'simctl', 'terminate', udid, 'app.chatnative.ios'], check=False)
    run(['xcrun', 'simctl', 'ui', udid, 'appearance', 'dark' if mode == 'dark' else 'light'])
    run(['xcrun', 'simctl', 'launch', udid, 'app.chatnative.ios', '--ui-preview', mode])
    time.sleep(4)
    assert 'app.chatnative.ios' in run(['xcrun', 'simctl', 'spawn', udid, 'launchctl', 'list']).stdout, 'App crashed after launch: ' + mode
    filename = output / f'{prefix}-{mode}.png'
    run(['xcrun', 'simctl', 'io', udid, 'screenshot', str(filename)])
    assert filename.stat().st_size > 10000, f'Missing screenshot: {mode}'
    print('SCREENSHOT ' + filename.name, flush=True)
run(['xcrun', 'simctl', 'terminate', udid, 'app.chatnative.ios'], check=False)
run(['xcrun', 'simctl', 'shutdown', udid], check=False)
print('Nine real simulator screenshots captured; human visual review is still required.', flush=True)
