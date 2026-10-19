import copy
import importlib.util
import json
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('prepare', Path(__file__).parents[1] / 'tools/prepare_firebase_client.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class ConfigTests(unittest.TestCase):
    def fixture(self):
        return {'project_info': {'project_id': module.PROJECT, 'project_number': '123456'}, 'client': [{'client_info': {'mobilesdk_app_id': '1:123456:android:fixture', 'android_client_info': {'package_name': module.PACKAGE}}, 'api_key': [{'current_key': 'AIza' + 'x' * 35}], 'oauth_client': [{'client_id': 'ignored'}]}]}
    def test_selection_only_public_fields(self):
        selected = module.select_client(json.dumps(self.fixture()))
        self.assertEqual(set(selected), {'project_id', 'package_name', 'api_key'})
    def test_runtime_config_contains_only_selected_public_values(self):
        selected = module.select_client(json.dumps(self.fixture()))
        rendered = module.render_godot_config(selected)
        self.assertIn('const ENABLED := true', rendered)
        self.assertIn(module.PROJECT, rendered)
        self.assertNotIn('oauth_client', rendered)
        self.assertNotIn('project_number', rendered)
        self.assertNotIn('mobilesdk_app_id', rendered)
        self.assertEqual(rendered.count(selected['api_key']), 1)
    def test_invalid_and_ambiguous(self):
        cases = ['', '{}', '[]', 'invalid', 'x' * (1024 * 1024 + 1)]
        for path, value in [('project', 'other'), ('package', 'other'), ('key', 'not-a-key'), ('number', 123), ('app', 'other')]:
            data = self.fixture()
            if path == 'project': data['project_info']['project_id'] = value
            if path == 'package': data['client'][0]['client_info']['android_client_info']['package_name'] = value
            if path == 'key': data['client'][0]['api_key'][0]['current_key'] = value
            if path == 'number': data['project_info']['project_number'] = value
            if path == 'app': data['client'][0]['client_info']['mobilesdk_app_id'] = value
            cases.append(json.dumps(data))
        data = self.fixture(); data['client'].append(copy.deepcopy(data['client'][0])); cases.append(json.dumps(data))
        for raw in cases:
            with self.assertRaises(ValueError): module.select_client(raw)
    def test_reject_privileged_material(self):
        for key in ['private_key', 'private_key_id', 'client_secret', 'access_token', 'refresh_token']:
            data = self.fixture(); data['nested'] = {key: 'fixture'}
            with self.assertRaises(ValueError): module.select_client(json.dumps(data))
        data = self.fixture(); data['type'] = 'service_account'
        with self.assertRaises(ValueError): module.select_client(json.dumps(data))

if __name__ == '__main__': unittest.main()
