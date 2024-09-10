"""
Get names of test targets that OSCI would run for the given charm. Should be
run from within the charm root.

Outputs space separated list of target names.
"""
import os

import yaml

CLASSIC_TESTS_YAML = 'tests/tests.yaml'
REACTIVE_TESTS_YAML = os.path.join('src', CLASSIC_TESTS_YAML)


def extract_targets(bundle_list):
    """
    Targets are provided as strings or dicts where the target name is the
    value so this accounts for both formats.
    """
    extracted = []
    for item in bundle_list:
        if isinstance(item, dict):
            extracted.append(list(item.values())[0])
        else:
            extracted.append(item)

    return extracted


if __name__ == "__main__":
    if os.path.exists(REACTIVE_TESTS_YAML):
        TESTS_FILE = REACTIVE_TESTS_YAML
    else:
        TESTS_FILE = CLASSIC_TESTS_YAML

    with open(TESTS_FILE, encoding='utf-8') as fd:
        bundles = yaml.safe_load(fd)

    smoke_bundles = extract_targets(bundles['smoke_bundles'])
    gate_bundles = extract_targets(bundles['gate_bundles'])
    dev_bundles = extract_targets(bundles['dev_bundles'])

    targets = set(smoke_bundles + gate_bundles + dev_bundles)

    print(' '.join(sorted(targets)))
