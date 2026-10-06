#!/usr/bin/env python3
"""Checks project graph and shipped resources; does not replace xcodebuild."""
from pathlib import Path
import json
import plistlib
import xml.etree.ElementTree as ET
from openstep_parser import OpenStepDecoder
ROOT = Path(__file__).resolve().parents[1]
with (ROOT / 'ChatNative.xcodeproj/project.pbxproj').open() as file:
    project = OpenStepDecoder.ParseFromFile(file)
objects = project['objects']
assert project['rootObject'] in objects
for key, obj in objects.items():
    for field in ['fileRef', 'mainGroup', 'productReference', 'buildConfigurationList', 'containerPortal', 'target', 'targetProxy', 'productRefGroup']:
        if field in obj: assert obj[field] in objects, (key, field)
    for field in ['children', 'files', 'buildPhases', 'buildConfigurations', 'targets', 'dependencies']:
        for value in obj.get(field, []): assert value in objects, (key, field, value)
    if obj.get('isa') == 'PBXFileReference' and obj.get('sourceTree') == 'SOURCE_ROOT':
        assert (ROOT / obj['path']).exists(), obj['path']
file_paths = {obj.get('path') for obj in objects.values() if obj.get('isa') == 'PBXFileReference'}
for file in (ROOT / 'ChatNative').rglob('*.swift'):
    assert file.relative_to(ROOT).as_posix() in file_paths, file
for file in (ROOT / 'ChatNative/Resources').rglob('*'):
    if file.suffix in ['.plist', '.xcprivacy']:
        with file.open('rb') as handle: plistlib.load(handle)
    if file.name == 'Contents.json':
        asset = json.loads(file.read_text())
        for image in asset.get('images', []):
            if 'filename' in image: assert (file.parent / image['filename']).exists()
for scheme in (ROOT / 'ChatNative.xcodeproj/xcshareddata/xcschemes').glob('*.xcscheme'):
    tree = ET.parse(scheme)
    for reference in tree.findall('.//BuildableReference'):
        assert reference.attrib['BlueprintIdentifier'] in objects
print(f'PASS: project graph ({len(objects)} objects), all source references, shared scheme, plists, privacy manifest and assets.')
