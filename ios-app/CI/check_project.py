#!/usr/bin/env python3
"""Offline structural audit, NOT proof that Xcode can build or execute tests.

Parses the generated OpenStep/XML plist and shared scheme using only stdlib.
Does not change files or invoke Xcode. Run from any directory with Python 3.
"""
import json
from pathlib import Path
import plistlib
import re
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / 'MusicfyIOS.xcodeproj'


def parse_openstep(text):
    pattern = re.compile(
        r'\s+|//[^\n]*|/\*.*?\*/|"(?:\\.|[^"\\])*"|'
        r'[{}()=;,]|[^\s{}()=;,"]+',
        re.S,
    )
    tokens = []
    end = 0

    for match in pattern.finditer(text):
        if match.start() != end:
            raise ValueError(f'Unparsed plist text at {end}')

        token = match.group()
        end = match.end()

        if token.isspace() or token.startswith(('//', '/*')):
            continue

        tokens.append(json.loads(token) if token.startswith('"') else token)

    if end != len(text):
        raise ValueError(f'Unparsed plist text at {end}')

    index = 0

    def take(expected=None):
        nonlocal index

        if index >= len(tokens):
            raise ValueError('Unexpected end of plist')

        token = tokens[index]
        index += 1

        if expected is not None and token != expected:
            raise ValueError(f'Expected {expected!r}, got {token!r}')

        return token

    def value():
        token = take()

        if token == '{':
            result = {}

            while tokens[index] != '}':
                key = take()

                if key in result:
                    raise ValueError(f'Duplicate plist key {key}')

                take('=')
                result[key] = value()
                take(';')

            take('}')
            return result

        if token == '(':
            result = []

            while tokens[index] != ')':
                result.append(value())

                if tokens[index] != ')':
                    take(',')

            take(')')
            return result

        if token in set('{}()=;,'):
            raise ValueError(f'Unexpected token {token}')

        return token

    result = value()

    if index != len(tokens):
        raise ValueError('Trailing plist data')

    return result


def audit():
    data = (PROJECT / 'project.pbxproj').read_bytes()

    project = (
        plistlib.loads(data)
        if data.lstrip().startswith(b'<?xml')
        else parse_openstep(data.decode('utf-8'))
    )

    objects = project['objects']
    root_object = objects[project['rootObject']]

    assert root_object['isa'] == 'PBXProject'
    assert not root_object.get('packageReferences')

    def audit_references(item):
        if isinstance(item, dict):
            for child in item.values():
                audit_references(child)

        elif isinstance(item, list):
            for child in item:
                audit_references(child)

        elif isinstance(item, str) and re.fullmatch(
            r'[A-Fa-f0-9]{24}', item
        ):
            assert item in objects, f'Dangling object reference: {item}'

    audit_references(project)

    assert not any(
        obj['isa'] in {
            'PBXShellScriptBuildPhase',
            'PBXCopyFilesBuildPhase',
            'XCRemoteSwiftPackageReference',
            'XCLocalSwiftPackageReference',
            'XCSwiftPackageProductDependency',
        }
        for obj in objects.values()
    ), 'Unexpected scripts, copy phases or packages'

    paths = {}
    visited = set()

    def walk(identifier, parent):
        assert identifier not in visited, (
            f'Duplicate group/file membership: {identifier}'
        )
        visited.add(identifier)

        obj = objects[identifier]
        tree = obj.get('sourceTree', '<group>')

        if tree == 'BUILT_PRODUCTS_DIR':
            return

        assert tree in {'<group>', 'SOURCE_ROOT'}, (
            f'External sourceTree: {tree}'
        )

        base = ROOT if tree == 'SOURCE_ROOT' else parent
        path = (base / obj.get('path', '')).resolve()

        assert path == ROOT or ROOT in path.parents, (
            f'Path escapes ios-app: {path}'
        )

        if obj['isa'] == 'PBXGroup':
            for child in obj.get('children', []):
                walk(child, path)

        elif obj['isa'] == 'PBXFileReference':
            paths[identifier] = path
            assert path.is_file(), f'Missing file: {path}'

        else:
            raise AssertionError(
                f'Unsupported group child: {obj["isa"]}'
            )

    walk(root_object['mainGroup'], ROOT)

    targets = {
        objects[item]['name']: (item, objects[item])
        for item in root_object['targets']
    }

    assert set(targets) == {'MusicfyIOS', 'MusicfyIOSTests'}

    # The standalone live smoke-test program lives in CI.
    # It is compiled separately by ios-innertube-live-smoke.yml,
    # so do not count it as a source file in the Xcode app target.
    ci_dir = ROOT / 'CI'
    all_swift = {
        path
        for path in ROOT.rglob('*.swift')
        if ci_dir not in path.parents
    }

    tests = set((ROOT / 'Tests').rglob('*.swift'))
    production = all_swift - tests

    assert len(production) == 31 and len(tests) == 2, (
        'Review membership when adding source files'
    )

    assert {
        path for path in paths.values() if path.suffix == '.swift'
    } == all_swift

    for name, expected, product_type in (
        ('MusicfyIOS', production, 'com.apple.product-type.application'),
        (
            'MusicfyIOSTests',
            tests,
            'com.apple.product-type.bundle.unit-test',
        ),
    ):
        target_id, target = targets[name]

        assert target['isa'] == 'PBXNativeTarget'
        assert target['productType'] == product_type
        assert not target.get('packageProductDependencies')

        phases = [
            objects[item] for item in target['buildPhases']
        ]
        sources = [
            phase for phase in phases
            if phase['isa'] == 'PBXSourcesBuildPhase'
        ]

        assert len(sources) == 1

        member_ids = [
            objects[item]['fileRef']
            for item in sources[0]['files']
        ]

        assert len(member_ids) == len(set(member_ids)), (
            'Duplicate source build entry'
        )

        assert {
            paths[item] for item in member_ids
        } == expected, f'Wrong source membership: {name}'

        configs = [
            objects[item]
            for item in objects[
                target['buildConfigurationList']
            ]['buildConfigurations']
        ]

        assert {
            item['name'] for item in configs
        } == {'Debug', 'Release'}

        for config in configs:
            settings = config['buildSettings']

            assert str(
                settings['IPHONEOS_DEPLOYMENT_TARGET']
            ) == '17.0'

            assert str(settings['SWIFT_VERSION']) == '5.0'
            assert str(settings['TARGETED_DEVICE_FAMILY']) == '1'
            assert settings['GENERATE_INFOPLIST_FILE'] == 'YES'
            assert settings['CODE_SIGNING_ALLOWED'] == 'NO'
            assert settings['CODE_SIGNING_REQUIRED'] == 'NO'

            if name == 'MusicfyIOS' and config['name'] == 'Debug':
                assert settings['ENABLE_TESTABILITY'] == 'YES'

            if name == 'MusicfyIOSTests':
                assert 'MusicfyIOS.app' in settings['TEST_HOST']
                assert settings['BUNDLE_LOADER'] == '$(TEST_HOST)'

        print(
            f'PASS {name}: {len(expected)} Swift files; '
            'Debug/Release, iOS 17, unsigned'
        )

    app_id, app = targets['MusicfyIOS']
    test_id, test = targets['MusicfyIOSTests']

    assert not app.get('dependencies')

    dependencies = [
        objects[item] for item in test['dependencies']
    ]

    assert (
        len(dependencies) == 1
        and dependencies[0]['target'] == app_id
    )

    proxy = objects[dependencies[0]['targetProxy']]

    assert proxy['isa'] == 'PBXContainerItemProxy'
    assert proxy['remoteGlobalIDString'] == app_id
    assert proxy['containerPortal'] == project['rootObject']

    for obj in objects.values():
        if obj['isa'] != 'XCBuildConfiguration':
            continue

        settings = obj['buildSettings']

        assert not {
            'DEVELOPMENT_TEAM',
            'PROVISIONING_PROFILE',
            'PROVISIONING_PROFILE_SPECIFIER',
            'CODE_SIGN_IDENTITY',
        } & set(settings)

        assert (
            settings['CODE_SIGNING_ALLOWED']
            == settings['CODE_SIGNING_REQUIRED']
            == 'NO'
        )

        assert str(
            settings['IPHONEOS_DEPLOYMENT_TARGET']
        ) == '17.0'

    scheme = ET.parse(
        PROJECT / 'xcshareddata/xcschemes/MusicfyIOS.xcscheme'
    ).getroot()

    build_entries = scheme.findall(
        './BuildAction/BuildActionEntries/BuildActionEntry'
    )

    assert {
        item.find('BuildableReference').attrib['BlueprintIdentifier']
        for item in build_entries
    } == {app_id, test_id}

    assert all(
        item.attrib['buildForTesting'] == 'YES'
        for item in build_entries
    )

    test_action = scheme.find('TestAction')
    assert test_action.attrib['buildConfiguration'] == 'Debug'

    testables = scheme.findall(
        './TestAction/Testables/TestableReference'
    )

    assert (
        len(testables) == 1
        and testables[0].attrib['skipped'] == 'NO'
    )

    assert (
        testables[0].find('BuildableReference')
        .attrib['BlueprintIdentifier'] == test_id
    )

    for reference in scheme.findall('.//BuildableReference'):
        assert (
            reference.attrib['ReferencedContainer']
            == 'container:MusicfyIOS.xcodeproj'
        )

        assert reference.attrib['BlueprintIdentifier'] in {
            app_id,
            test_id,
        }

    assert not scheme.findall('.//ExecutionAction'), (
        'Unexpected scheme script'
    )

    production_text = '\n'.join(
        path.read_text(encoding='utf-8')
        for path in production
    )

    assert len(re.findall(r'@main\b', production_text)) == 1

    test_source = next(iter(tests)).read_text(encoding='utf-8')
    assert '@testable import MusicfyIOS' in test_source

    print(
        'PASS object references, target dependency, generated plist, '
        'shared scheme and test import'
    )
    print(
        'STATIC AUDIT ONLY — Xcode parsing, Swift compilation, '
        'build and XCTest NOT RUN.'
    )


if __name__ == '__main__':
    audit()