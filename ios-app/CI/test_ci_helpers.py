"""Offline fixtures only: these tests never call Xcode or a simulator."""
import copy
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


if __name__ == '__main__':
    unittest.main()
