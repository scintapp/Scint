#!/usr/bin/env python3
"""Run against the existing Debug build: xcodebuild -project Scint.xcodeproj -scheme Scint -configuration Debug build."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
env = os.environ.copy()
env.setdefault('DEVELOPER_DIR', '/Applications/Xcode-beta.app/Contents/Developer')
settings = json.loads(subprocess.check_output([
    'xcodebuild', '-project', 'Scint.xcodeproj', '-scheme', 'Scint',
    '-configuration', 'Debug', '-showBuildSettings', '-json',
], cwd=repo, env=env, stderr=subprocess.DEVNULL))
settings = next(item['buildSettings'] for item in settings if item['target'] == 'Scint')
products = Path(settings['BUILT_PRODUCTS_DIR'])
arch = settings['NATIVE_ARCH_ACTUAL']
objects = Path(settings['OBJECT_FILE_DIR_normal']) / arch
app_objects = sorted(p for p in objects.glob('*.o') if p.name != 'ScintApp.o')
if not app_objects:
    raise SystemExit('Build the Scint Debug scheme before running this regression test.')
with tempfile.TemporaryDirectory(prefix='scint-root-tests-') as directory:
    binary = Path(directory) / 'scint-root-tests'
    command = [
        'xcrun', 'swiftc', '-swift-version', '6', '-parse-as-library',
        '-target', f"{arch}-apple-macos{settings['MACOSX_DEPLOYMENT_TARGET']}",
        '-I', str(products), '-F', str(products / 'PackageFrameworks'),
        str(repo / 'Tests/RootProcessRegression.swift'),
        *map(str, app_objects), *map(str, sorted(products.glob('*.o'))),
        '-o', str(binary),
    ]
    subprocess.run(command, cwd=repo, env=env, check=True)
    env['XDG_DATA_HOME'] = directory
    env['XDG_CONFIG_HOME'] = directory
    subprocess.run([str(binary)], cwd=repo, env=env, check=True)
