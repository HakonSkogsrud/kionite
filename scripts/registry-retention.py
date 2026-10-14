#!/usr/bin/env python3
"""Keep five managed GHCR builds, including stable. Default to a dry run."""
import argparse
import base64
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

RELEASE = re.compile(r'^44-(\d{8}T\d{6}Z)-[0-9a-f]{12}-[0-9a-f]{8}$')


def tags(version):
    return version.get('metadata', {}).get('container', {}).get('tags', [])


def managed(version):
    labels = tags(version)
    # Never delete untagged manifests or versions with custom recovery tags.
    return bool(labels) and any(RELEASE.fullmatch(t) for t in labels) and all(
        t == 'stable' or RELEASE.fullmatch(t) for t in labels)


def plan(versions, keep):
    if keep < 1:
        raise ValueError('Retention count must be positive')
    stable = [v for v in versions if 'stable' in tags(v)]
    if len(stable) != 1:
        raise ValueError('Expected exactly one stable version; refusing cleanup')
    candidates = [v for v in versions if managed(v)]
    candidates.sort(key=lambda v: max(
        RELEASE.fullmatch(t).group(1) for t in tags(v) if RELEASE.fullmatch(t)), reverse=True)
    protected = {stable[0]['id']}
    for version in candidates:
        if len(protected) >= keep:
            break
        protected.add(version['id'])
    return [v for v in candidates if v['id'] not in protected], stable[0]


class GitHub:
    def __init__(self, token, package):
        self.token = token
        self.path = '/user/packages/container/' + urllib.parse.quote(package, safe='')
        self.delete_allowed = False

    def request(self, path, method='GET'):
        request = urllib.request.Request('https://api.github.com' + path, method=method, headers={
            'Authorization': 'Bearer ' + self.token,
            'Accept': 'application/vnd.github+json',
            'X-GitHub-Api-Version': '2022-11-28',
        })
        with urllib.request.urlopen(request, timeout=30) as response:
            scopes = {s.strip() for s in response.headers.get('X-OAuth-Scopes', '').split(',')}
            if 'delete:packages' in scopes:
                self.delete_allowed = True
            return json.load(response) if response.status != 204 else None

    def versions(self):
        versions = []
        page = 1
        while True:
            batch = self.request(self.path + f'/versions?per_page=100&page={page}')
            versions.extend(batch)
            if len(batch) < 100:
                return versions
            page += 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--keep', type=int, default=5)
    args = parser.parse_args()
    repo = os.environ.get('REGISTRY_REPO', 'ghcr.io/hakonskogsrud/kionite')
    match = re.fullmatch(r'ghcr.io/([a-z0-9_-]+)/([a-z0-9_-]+)', repo)
    if not match:
        raise ValueError('Expected personal GHCR repository')
    owner, package = match.groups()
    authfile = os.environ.get('REGISTRY_AUTH_FILE', os.path.expanduser('~/.config/containers/auth.json'))
    with open(authfile) as source:
        auth = json.load(source)['auths']['ghcr.io']['auth']
    _, token = base64.b64decode(auth).decode().split(':', 1)
    api = GitHub(token, package)
    identity = api.request('/user')['login']
    if identity.lower() != owner:
        raise ValueError('Publishing account differs from registry owner')
    versions = api.versions()
    deletions, stable = plan(versions, args.keep)
    print(f'Retention: keep {args.keep} managed builds; stable protected; {len(deletions)} deletions planned')
    for version in deletions:
        print(('Delete' if args.apply else 'Would delete'), version['id'], ', '.join(tags(version)))
    if not args.apply:
        if not api.delete_allowed:
            print('Token needs delete:packages before retention can delete versions')
        return
    if not deletions:
        return
    if not api.delete_allowed:
        raise ValueError('Token needs delete:packages; published images left unchanged')
    for version in deletions:
        # Re-read the whole inventory before each deletion. A changed stable stops
        # cleanup, and newly promoted/custom-tagged versions are never removed.
        fresh = api.versions()
        current_plan, current_stable = plan(fresh, args.keep)
        if current_stable['id'] != stable['id']:
            raise ValueError('Stable changed during cleanup; stopping')
        if not any(v['id'] == version['id'] and v['name'] == version['name'] for v in current_plan):
            continue
        api.request(api.path + '/versions/' + str(version['id']), 'DELETE')
        print('Deleted version', version['id'])


if __name__ == '__main__':
    try:
        main()
    except urllib.error.HTTPError as error:
        print(f'Registry retention failed: GitHub HTTP {error.code}; credentials suppressed', file=sys.stderr)
        sys.exit(1)
    except Exception as error:
        # Only our own validation messages may be logged, never network URLs/auth.
        message = str(error) if isinstance(error, ValueError) else type(error).__name__
        print('Registry retention failed: ' + message, file=sys.stderr)
        sys.exit(1)
