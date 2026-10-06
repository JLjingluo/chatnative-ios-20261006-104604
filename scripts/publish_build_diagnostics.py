#!/usr/bin/env python3
"""Publish only compiler/simulator diagnostics from this run; never dump environment or credentials."""
from pathlib import Path
import json
import os
import re
import time
import urllib.error
import urllib.parse
import urllib.request

root = Path(__file__).resolve().parents[1]
repository = os.environ['GITHUB_REPOSITORY']
key = os.environ['GH_RELEASE_TOKEN']
major = os.environ['REQUIRED_IOS_MAJOR']
tag = 'ui-diagnostics-' + os.environ['GITHUB_RUN_NUMBER']
headers = {'Authorization': 'Bearer ' + key, 'Accept': 'application/vnd.github+json', 'User-Agent': 'ChatNative-CI-Diagnostics', 'Content-Type': 'application/json'}
def api(path, method='GET', data=None):
    request = urllib.request.Request('https://api.github.com/repos/' + repository + path, headers=headers, method=method, data=None if data is None else json.dumps(data).encode())
    with urllib.request.urlopen(request, timeout=60) as response:
        return json.load(response)
try:
    release = api('/releases/tags/' + tag)
except urllib.error.HTTPError as error:
    if error.code != 404: raise
    try:
        release = api('/releases', 'POST', {'tag_name': tag, 'target_commitish': os.environ['GITHUB_SHA'], 'name': 'UI build diagnostics ' + os.environ['GITHUB_RUN_NUMBER'], 'body': 'Compiler and simulator diagnostics. This is not an IPA release.', 'prerelease': True})
    except urllib.error.HTTPError as race:
        if race.code != 422: raise
        time.sleep(2)
        release = api('/releases/tags/' + tag)
for name in ['xcodebuild.log', 'simulator-build.log', 'preview-driver.log']:
    file = root / 'artifacts' / name
    if not file.exists(): continue
    text = file.read_text(errors='replace').replace(key, '[REDACTED]')
    text = re.sub(r'(?:gh[pousr]_[A-Za-z0-9]+|github_pat_[A-Za-z0-9_]+)', '[REDACTED]', text)
    text = re.sub(r'https://x-access-token:[^@\s]+@', 'https://[REDACTED]@', text)
    label = 'ios' + major + '-' + name
    url = release['upload_url'].split('{')[0] + '?name=' + urllib.parse.quote(label)
    request = urllib.request.Request(url, headers={**headers, 'Content-Type': 'text/plain'}, method='POST', data=text.encode())
    with urllib.request.urlopen(request, timeout=120) as response:
        asset = json.load(response)
    print('DIAGNOSTIC ' + asset['browser_download_url'])
