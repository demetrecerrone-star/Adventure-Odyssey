#!/usr/bin/env python3
"""Validate user-provided Firebase Android config without displaying credentials.

Input is read from FIREBASE_CLIENT_CONFIG_JSON only. Output contains exclusively
public client identifiers. Never store the original google-services.json.
"""
import argparse
import json
import os
from pathlib import Path
import re
import sys

PROJECT = 'adventure-odyssey-2aadf'
PACKAGE = 'com.demetrecerrone.adventureodyssey'


def select_client(raw):
    if not isinstance(raw, str) or not raw or len(raw) > 1024 * 1024:
        raise ValueError('Missing or oversized client configuration')
    try:
        data = json.loads(raw)
    except (ValueError, TypeError):
        raise ValueError('Invalid JSON client configuration') from None
    if not isinstance(data, dict):
        raise ValueError('Client configuration must be an object')
    def no_privileged_fields(value):
        if isinstance(value, dict):
            if any(k in value for k in ('private_key', 'private_key_id', 'client_secret', 'refresh_token', 'access_token')) or value.get('type') == 'service_account':
                raise ValueError('Privileged credentials are not accepted')
            for v in value.values():
                no_privileged_fields(v)
        elif isinstance(value, list):
            for v in value:
                no_privileged_fields(v)
    no_privileged_fields(data)
    project = data.get('project_info')
    if not isinstance(project, dict) or project.get('project_id') != PROJECT:
        raise ValueError('Firebase project does not match Adventure Odyssey')
    number = project.get('project_number')
    if not isinstance(number, str) or not number.isdecimal():
        raise ValueError('Missing Firebase project number')
    clients = data.get('client')
    if not isinstance(clients, list):
        raise ValueError('Missing Android client list')
    matches = []
    for client in clients:
        if not isinstance(client, dict):
            continue
        info = client.get('client_info', {})
        if not isinstance(info, dict):
            continue
        android = info.get('android_client_info', {})
        if isinstance(android, dict) and android.get('package_name') == PACKAGE:
            matches.append(client)
    if len(matches) != 1:
        raise ValueError('Expected exactly one matching Android application')
    keys = matches[0].get('api_key')
    if not isinstance(keys, list) or len(keys) != 1 or not isinstance(keys[0], dict):
        raise ValueError('Expected exactly one public client key')
    key = keys[0].get('current_key')
    if not isinstance(key, str) or not re.fullmatch(r'AIza[A-Za-z0-9_-]{35}', key):
        raise ValueError('Invalid public client key format')
    app_id = matches[0]['client_info'].get('mobilesdk_app_id')
    if not isinstance(app_id, str) or not app_id.startswith('1:' + number + ':android:'):
        raise ValueError('Android app identity does not match project number')
    return {'project_id': PROJECT, 'package_name': PACKAGE, 'api_key': key}


def render_godot_config(selected):
    # Only the already-validated public client values enter a distributed build.
    # JSON string escaping is compatible with these restricted GDScript strings.
    return ('extends RefCounted\n'
            '# Generated in the approved build; public client configuration only.\n'
            'const PROJECT_ID := ' + json.dumps(selected['project_id']) + '\n'
            'const WEB_API_KEY := ' + json.dumps(selected['api_key']) + '\n'
            'const ENABLED := true\n')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', required=True)
    parser.add_argument('--godot-config', action='store_true', help='Write approved public runtime config instead of check-only JSON')
    args = parser.parse_args()
    try:
        selected = select_client(os.environ.get('FIREBASE_CLIENT_CONFIG_JSON', ''))
        output = Path(args.output)
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(render_godot_config(selected) if args.godot_config else json.dumps(selected, separators=(',', ':')) + '\n')
    except (ValueError, OSError):
        # Do not log raw JSON, parsing context, credential values or environment.
        print('Firebase configuration check failed. Verify project, Android package and public-client JSON; no credential values were logged.', file=sys.stderr)
        return 1
    print('Firebase public-client configuration validated for Adventure Odyssey. No network requests made. API restrictions and billing were not verified.')
    return 0

if __name__ == '__main__':
    sys.exit(main())
