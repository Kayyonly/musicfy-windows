#!/usr/bin/env python3
"""Choose an existing, available iPhone accepted by the selected Xcode scheme.

Uses only the Python standard library. Does not boot/create/download a simulator.
"""
import argparse
import json
from pathlib import Path
import re


def select_destination(devices, runtimes, device_types, destinations):
    # Ignore the ineligible section even if a device there has a valid UUID.
    available_text = destinations.split('Ineligible destinations', 1)[0]
    accepted_ids = set()
    for line in available_text.splitlines():
        if 'platform:iOS Simulator' not in line or 'error:' in line:
            continue
        match = re.search(r'\bid:\s*([0-9a-fA-F-]{36})(?=\s*[,}])', line)
        if match:
            accepted_ids.add(match.group(1).upper())
    iphone_types = {
        item['identifier'] for item in device_types['devicetypes']
        if item.get('productFamily') == 'iPhone'
    }
    eligible_runtimes = {}
    for runtime in runtimes['runtimes']:
        if not runtime.get('isAvailable', False):
            continue
        if not runtime.get('identifier', '').startswith('com.apple.CoreSimulator.SimRuntime.iOS-'):
            continue
        version = tuple(int(part) for part in runtime['version'].split('.'))
        if version < (17, 0):
            continue
        eligible_runtimes[runtime['identifier']] = version
    candidates = []
    for runtime_id, items in devices['devices'].items():
        if runtime_id not in eligible_runtimes:
            continue
        for device in items:
            udid = device.get('udid', '')
            if not re.fullmatch(r'[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}', udid):
                continue
            if not device.get('isAvailable', False) or device.get('deviceTypeIdentifier') not in iphone_types:
                continue
            if udid.upper() not in accepted_ids:
                continue
            candidates.append((eligible_runtimes[runtime_id], udid.upper()))
    if not candidates:
        raise ValueError('No available iOS >= 17 iPhone simulator accepted by the scheme; no download or fallback attempted.')
    # Prefer the newest installed eligible runtime, then a stable UUID ordering.
    version, udid = sorted(candidates, key=lambda item: (tuple(-x for x in item[0]), item[1]))[0]
    return f'platform=iOS Simulator,id={udid}', '.'.join(map(str, version))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('devices', 'runtimes', 'device-types', 'destinations'):
        parser.add_argument('--' + name, required=True, type=Path)
    parser.add_argument('--github-env', type=Path)
    args = parser.parse_args()
    destination, version = select_destination(
        json.loads(args.devices.read_text()),
        json.loads(args.runtimes.read_text()),
        json.loads(args.device_types.read_text()),
        args.destinations.read_text(),
    )
    print(f'Selected installed iOS {version}: {destination}')
    if args.github_env:
        # destination contains only a constant prefix and a validated UUID.
        with args.github_env.open('a') as handle:
            handle.write(f'MUSICFY_DESTINATION={destination}\n')


if __name__ == '__main__':
    main()
