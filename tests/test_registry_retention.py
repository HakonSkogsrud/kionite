import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('retention', Path(__file__).parents[1] / 'scripts/registry-retention.py')
retention = importlib.util.module_from_spec(spec)
spec.loader.exec_module(retention)


def version(number, stable=False, extra=()):
    labels = [f'44-202610{number:02d}T030000Z-0123456789ab-01234567', *extra]
    if stable:
        labels.append('stable')
    return {'id': number, 'name': f'sha256:{number:064x}', 'metadata': {'container': {'tags': labels}}}


class RetentionTests(unittest.TestCase):
    def test_keep_latest_five_including_stable(self):
        deleted, stable = retention.plan([version(i, stable=i == 8) for i in range(1, 9)], 5)
        self.assertEqual({v['id'] for v in deleted}, {1, 2, 3})
        self.assertEqual(stable['id'], 8)

    def test_old_stable_still_counts_and_survives(self):
        deleted, _ = retention.plan([version(i, stable=i == 1) for i in range(1, 9)], 5)
        self.assertEqual({v['id'] for v in deleted}, {2, 3, 4})

    def test_custom_tags_and_untagged_versions_survive(self):
        versions = [version(i, stable=i == 8) for i in range(1, 9)]
        versions[0] = version(1, extra=('known-good',))
        versions.append({'id': 99, 'metadata': {'container': {'tags': []}}})
        deleted, _ = retention.plan(versions, 5)
        self.assertEqual({v['id'] for v in deleted}, {2, 3})

    def test_multiple_release_tags_count_as_one_build(self):
        versions = [version(i, stable=i == 6) for i in range(1, 7)]
        versions[-1]['metadata']['container']['tags'].append('44-20261007T030000Z-0123456789ab-01234567')
        deleted, _ = retention.plan(versions, 5)
        self.assertEqual([v['id'] for v in deleted], [1])

    def test_fewer_than_five_changes_nothing(self):
        self.assertEqual(retention.plan([version(1), version(2, stable=True)], 5)[0], [])

    def test_missing_or_ambiguous_stable_fails_closed(self):
        for versions in ([version(1)], [version(1, True), version(2, True)]):
            with self.assertRaises(ValueError):
                retention.plan(versions, 5)

    def test_invalid_count_fails_closed(self):
        with self.assertRaises(ValueError):
            retention.plan([version(1, True)], 0)


if __name__ == '__main__':
    unittest.main()
