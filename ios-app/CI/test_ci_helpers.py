"""Offline fixtures only: these tests never call Xcode or a simulator."""
import copy
from pathlib import Path
import unittest

from select_destination import select_destination

UUID = 'AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE'
OTHER_UUID = '11111111-2222-3333-4444-555555555555'
RUNTIME = 'com.apple.CoreSimulator.SimRuntime.iOS-18-5'
PHONE_TYPE = 'com.apple.CoreSimulator.SimDeviceType.iPhone-example'


class DestinationTests(unittest.TestCase):
    def setUp(self):
        self.devices = {'devices': {RUNTIME: [{
            'name': 'Fixture name is deliberately not consulted',
            'udid': UUID, 'isAvailable': True,
            'deviceTypeIdentifier': PHONE_TYPE,
        }]}}
        self.runtimes = {'runtimes': [{
            'identifier': RUNTIME, 'version': '18.5', 'isAvailable': True,
        }]}
        self.types = {'devicetypes': [{
            'identifier': PHONE_TYPE, 'productFamily': 'iPhone',
        }]}
        self.destinations = f'Available destinations for scheme:\n{{ platform:iOS Simulator, arch:arm64, id:{UUID}, OS:18.5, name:Any label }}\n'

    def choose(self):
        return select_destination(self.devices, self.runtimes, self.types, self.destinations)

    def test_uses_actual_uuid_not_device_name(self):
        self.assertEqual(self.choose(), (f'platform=iOS Simulator,id={UUID}', '18.5'))

    def test_rejects_unavailable_device(self):
        self.devices['devices'][RUNTIME][0]['isAvailable'] = False
        with self.assertRaises(ValueError):
            self.choose()

    def test_rejects_unavailable_runtime(self):
        self.runtimes['runtimes'][0]['isAvailable'] = False
        with self.assertRaises(ValueError):
            self.choose()

    def test_rejects_runtime_below_deployment_target(self):
        self.runtimes['runtimes'][0]['version'] = '16.4'
        with self.assertRaises(ValueError):
            self.choose()

    def test_rejects_ipad_and_missing_product_family(self):
        for family in ('iPad', None):
            self.types['devicetypes'][0]['productFamily'] = family
            with self.assertRaises(ValueError):
                self.choose()

    def test_requires_scheme_to_accept_uuid(self):
        self.destinations = 'Available destinations: { platform:iOS Simulator, id:dvtdevice-DVTiOSDeviceSimulatorPlaceholder }'
        with self.assertRaises(ValueError):
            self.choose()

    def test_ignores_ineligible_section_and_error_lines(self):
        for text in (f'Ineligible destinations:\n{{ platform:iOS Simulator, id:{UUID} }}',
                     f'{{ platform:iOS Simulator, id:{UUID}, error:Unavailable runtime }}'):
            self.destinations = text
            with self.assertRaises(ValueError):
                self.choose()

    def test_rejects_tvos_even_if_fixture_calls_device_iphone(self):
        tv = 'com.apple.CoreSimulator.SimRuntime.tvOS-18-5'
        self.runtimes['runtimes'][0]['identifier'] = tv
        self.devices['devices'][tv] = self.devices['devices'].pop(RUNTIME)
        with self.assertRaises(ValueError):
            self.choose()

    def test_prefers_newest_available_runtime(self):
        newer = 'com.apple.CoreSimulator.SimRuntime.iOS-26-0'
        device = copy.deepcopy(self.devices['devices'][RUNTIME][0])
        device['udid'] = OTHER_UUID
        self.devices['devices'][newer] = [device]
        self.runtimes['runtimes'].append({'identifier': newer, 'version': '26.0', 'isAvailable': True})
        self.destinations += f'{{ platform:iOS Simulator, id:{OTHER_UUID}, OS:26.0, name:Another label }}'
        self.assertEqual(self.choose(), (f'platform=iOS Simulator,id={OTHER_UUID}', '26.0'))

    def test_rejects_malformed_or_injected_uuid(self):
        self.devices['devices'][RUNTIME][0]['udid'] = UUID + '\nUNTRUSTED=value'
        with self.assertRaises(ValueError):
            self.choose()

    def test_no_installed_simulators_fails_without_fallback(self):
        self.devices = {'devices': {}}
        with self.assertRaisesRegex(ValueError, 'no download or fallback'):
            self.choose()


class CaptureContractTests(unittest.TestCase):
    ROOT = Path(__file__).resolve().parents[1]
    CAPTURE = (ROOT / 'CI' / 'capture_screenshots.sh').read_text()
    WORKFLOW = (ROOT.parent / '.github' / 'workflows' / 'ios-ui-ci.yml').read_text()
    ROUTES = ('home', 'search', 'library', 'profile', 'now-playing', 'queue', 'lyrics', 'home-bottom')

    def test_capture_manifest_has_exactly_eight_requested_routes(self):
        self.assertIn('routes=(home search library profile now-playing queue lyrics home-bottom)', self.CAPTURE)
        self.assertEqual(self.CAPTURE.count('for screen in "${routes[@]}"'), 1)

    def test_gallery_links_every_route_and_diagnostics(self):
        for route in self.ROUTES:
            self.assertIn(f'href="{route}.png"', self.CAPTURE)
        self.assertIn('href="diagnostics.txt"', self.CAPTURE)
        self.assertIn('visual-verification.txt', self.WORKFLOW)

    def test_readiness_is_polled_and_saved_before_screenshot(self):
        self.assertIn('simctl get_app_container "$device_id" "$bundle_id" data', self.CAPTURE)
        self.assertIn('rm -f "$readiness_file"', self.CAPTURE)
        self.assertIn('readiness_deadline=$((SECONDS + 20))', self.CAPTURE)
        self.assertIn('cp "$readiness_file" "$out_dir/$screen-readiness.json"', self.CAPTURE)
        self.assertLess(self.CAPTURE.index('cp "$readiness_file"'), self.CAPTURE.index('sleep "$settle_seconds"'))

    def test_readiness_validation_requires_exact_route_and_home_bottom_marker(self):
        self.assertIn('expected = {"route": route, "ready": True}', self.CAPTURE)
        self.assertIn('expected["bottomVisible"] = True', self.CAPTURE)
        self.assertIn('payload == expected', self.CAPTURE)
        self.assertIn('Readiness timeout or invalid JSON for route', self.CAPTURE)

    def test_workflow_is_manual_unsigned_read_only_and_pinned(self):
        self.assertIn('workflow_dispatch:', self.WORKFLOW)
        self.assertNotIn('push:', self.WORKFLOW)
        self.assertIn('contents: read', self.WORKFLOW)
        self.assertIn('runs-on: macos-15', self.WORKFLOW)
        self.assertIn('/Applications/Xcode_16.4.app/Contents/Developer', self.WORKFLOW)
        self.assertNotIn('Xcode_26', self.WORKFLOW)
        self.assertIn('CODE_SIGNING_ALLOWED=NO', self.WORKFLOW)
        self.assertIn('CODE_SIGNING_REQUIRED=NO', self.WORKFLOW)
        self.assertIn('Build unsigned Release app for the selected iPhone simulator', self.WORKFLOW)
        self.assertIn('-configuration Release', self.WORKFLOW)
        self.assertIn('retention-days: 3', self.WORKFLOW)


if __name__ == '__main__':
    unittest.main()
