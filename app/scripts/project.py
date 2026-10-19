#!/usr/bin/env python3
"""Pinned, repeatable local builds. All generated files stay under builds/."""

import argparse
from datetime import datetime, timezone
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
DEVELOPER = Path('/Applications/Xcode-beta.app/Contents/Developer')
CACHE = ROOT / 'builds/cache'
REPORTS = ROOT / 'builds/checks'
EXCLUSIONS = (
    'ProjectionMapperTests/TestOutputCoordinatorTests/normalFrameRestoresAcrossCloseAndNewCoordinator()',
    'ProjectionMapperTests/MetalRendererTests/nativeMetalOutputSurvivesPresetsResizeAndReopen()',
)


def toolchain():
    env = dict(os.environ, DEVELOPER_DIR=str(DEVELOPER))
    result = subprocess.run(['xcodebuild', '-version'], env=env, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if result.returncode or result.stdout.strip() != 'Xcode 27.0\nBuild version 27A5237l':
        sys.exit('Required Xcode 27.0 beta 5 (27A5237l) is unavailable.\n' + result.stdout)
    print(result.stdout.strip(), flush=True)
    return env


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('doctor', 'build', 'test', 'clean'))
    parser.add_argument('--configuration', choices=('Debug', 'Release'), default='Release')
    parser.add_argument('--apply', action='store_true', help='Actually remove the disposable build cache (clean only).')
    args = parser.parse_args()
    if args.apply and args.action != 'clean':
        parser.error('--apply is only valid with clean')
    # Refuse redirected output directories, especially before recursive deletion.
    for directory in (ROOT / 'builds', CACHE, REPORTS):
        if directory.is_symlink():
            sys.exit(f'Refusing symlinked build directory: {directory}')
    if args.action == 'clean':
        print(f'Disposable cache: {CACHE}')
        if args.apply:
            if CACHE.exists():
                shutil.rmtree(CACHE)
            print('Cache removed. App, archives, reports and source are preserved.')
        else:
            print('Preview only. Add --apply to remove it.')
        return
    env = toolchain()
    if args.action == 'doctor':
        print(f'Project: {ROOT / "app/ProjectionMapper/ProjectionMapper.xcodeproj"}')
        print(f'Build cache: {CACHE}')
        print(f'Free disk: {shutil.disk_usage(ROOT).free / 1024**3:.1f} GiB')
        return
    REPORTS.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S.%fZ')
    name = f'{stamp}-{args.configuration}-{args.action}'
    log = REPORTS / f'{name}.log'
    command = ['xcodebuild', '-project', str(ROOT / 'app/ProjectionMapper/ProjectionMapper.xcodeproj'),
               '-scheme', 'ProjectionMapper', '-configuration', args.configuration,
               '-destination', f'platform=macOS,arch={platform.machine()}',
               '-derivedDataPath', str(CACHE / 'DerivedData'),
               'ARCHS=arm64 x86_64', 'ONLY_ACTIVE_ARCH=NO']
    if args.action == 'test':
        command += ['-resultBundlePath', str(REPORTS / f'{name}.xcresult')]
        command += [f'-skip-testing:{test}' for test in EXCLUSIONS]
    command.append(args.action)
    print(f'{args.action.title()} {args.configuration}; log: {log}', flush=True)
    with log.open('w') as output:
        result = subprocess.run(command, cwd=ROOT, env=env, stdout=output, stderr=subprocess.STDOUT)
    if result.returncode:
        print('\n'.join(log.read_text(errors='replace').splitlines()[-45:]), file=sys.stderr)
        sys.exit(result.returncode)
    print(f'{args.action.title()} succeeded.', flush=True)
    if args.action == 'build':
        print(f'App: {CACHE / "DerivedData/Build/Products" / args.configuration / "ProjectionMapper.app"}')
    else:
        summary = REPORTS / f'{name}-summary.json'
        with summary.open('w') as output:
            subprocess.run(['xcrun', 'xcresulttool', 'get', 'test-results', 'summary',
                            '--path', str(REPORTS / f'{name}.xcresult'), '--format', 'json'],
                           env=env, stdout=output, check=True)
        print(f'Test summary: {summary}')


if __name__ == '__main__':
    main()
