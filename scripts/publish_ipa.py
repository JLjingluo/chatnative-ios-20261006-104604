#!/usr/bin/env python3
"""Verify and publish a compiled IPA as individual GitHub Release assets."""
from pathlib import Path
import hashlib
import json
import os
import plistlib
import struct
import urllib.parse
import urllib.request
import zipfile

root = Path(__file__).resolve().parents[1]
ipa = root / 'artifacts/ChatNative-unsigned.ipa'
with zipfile.ZipFile(ipa) as archive:
    assert archive.testzip() is None, 'IPA ZIP integrity failed'
    info = plistlib.loads(archive.read('Payload/ChatNative.app/Info.plist'))
    executable = archive.read('Payload/ChatNative.app/' + info['CFBundleExecutable'])
    magic, cpu, subtype, filetype, ncmds, size, flags, reserved = struct.unpack_from('<IiiIIIII', executable)
    assert magic == 0xfeedfacf and cpu == 0x100000c and filetype == 2, 'Expected arm64 Mach-O executable'
    offset = 32
    platform = None
    commands = []
    for _ in range(ncmds):
        cmd, cmdsize = struct.unpack_from('<II', executable, offset)
        commands.append(cmd)
        if cmd == 0x32:
            platform = struct.unpack_from('<I', executable, offset + 8)[0]
        offset += cmdsize
    assert platform == 2, 'Expected iOS device executable'
    assert 0x1d not in commands, 'An executable code signature was found'
    assert not any('/_CodeSignature/' in name or name.endswith('embedded.mobileprovision') for name in archive.namelist()), 'Unexpected app signature or provisioning profile'

repository = os.environ['GITHUB_REPOSITORY']
credential = os.environ['GH_RELEASE_TOKEN']
tag = 'unsigned-' + os.environ['GITHUB_RUN_NUMBER']
run_url = 'https://github.com/' + repository + '/actions/runs/' + os.environ['GITHUB_RUN_ID']
verification = {
    'filename': ipa.name,
    'sha256': hashlib.sha256(ipa.read_bytes()).hexdigest(),
    'size_bytes': ipa.stat().st_size,
    'architecture': 'arm64',
    'platform': 'iOS device',
    'unsigned': True,
    'bundle_identifier': info['CFBundleIdentifier'],
    'minimum_ios': info.get('MinimumOSVersion'),
    'version': info['CFBundleShortVersionString'],
    'source_commit': os.environ['GITHUB_SHA'],
    'build_url': run_url
}
report = root / 'artifacts/IPA-VERIFICATION.json'
report.write_text(json.dumps(verification, ensure_ascii=False, indent=2))
print(json.dumps(verification, ensure_ascii=False))
headers = {'Authorization': 'Bearer ' + credential, 'Accept': 'application/vnd.github+json', 'X-GitHub-Api-Version': '2022-11-28', 'User-Agent': 'ChatNative-IPA-Release'}
body = {
    'tag_name': tag,
    'target_commitish': os.environ['GITHUB_SHA'],
    'name': 'ChatNative 1.0.0 · unsigned iOS IPA',
    'body': 'Direct download: **ChatNative-unsigned.ipa**.\n\nNative iOS 17+ arm64 app. Unsigned; ordinary iOS installation requires signing. Configure your own OpenAI-compatible API inside the app. Not an official ChatGPT client.\n\nApple-platform core tests, iPhone Release build and IPA structure checks passed. No device or screenshot verification.\n\nBuild: ' + run_url,
    'draft': False,
    'prerelease': False
}
request = urllib.request.Request('https://api.github.com/repos/' + repository + '/releases', data=json.dumps(body).encode(), headers={**headers, 'Content-Type': 'application/json'}, method='POST')
with urllib.request.urlopen(request, timeout=60) as response:
    release = json.load(response)
upload_root = release['upload_url'].split('{')[0]
assert urllib.parse.urlsplit(upload_root).hostname == 'uploads.github.com'
for file in [ipa, ipa.with_suffix('.ipa.sha256'), report]:
    request = urllib.request.Request(upload_root + '?name=' + urllib.parse.quote(file.name), data=file.read_bytes(), headers={**headers, 'Content-Type': 'application/octet-stream'}, method='POST')
    with urllib.request.urlopen(request, timeout=120) as response:
        asset = json.load(response)
    print('RELEASE_ASSET ' + asset['browser_download_url'])
with open(os.environ['GITHUB_STEP_SUMMARY'], 'a') as summary:
    summary.write('## Unsigned IPA\n\n[Download IPA directly](https://github.com/' + repository + '/releases/download/' + tag + '/' + ipa.name + ')\n')
    summary.write('\nRelease: ' + release['html_url'] + '\n\nSHA-256: `' + verification['sha256'] + '`\n')
