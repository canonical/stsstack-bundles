"""
Get names of test targets that OSCI would run for the given charm. Should be
run from within the charm root.

Outputs space separated list of target names.
"""
import os
import re

import yaml
from common import OSCIConfig  # pylint: disable=import-error

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


def get_aliased_targets():
    """
    Extract aliased targets. A charm can define aliased targets which is where
    Zaza tests are run and use configuration steps from an alias section rather
    than the default (see 'configure:' section in tests.yaml for aliases). An
    alias is run by specifying the target to be run as a tox command using a
    job definition in osci.yaml where the target name has a <alias>: prefix.

    We extract any aliased targets here and return as a list.
    """
    targets = []
    osci = OSCIConfig()
    for jobname in osci.project_check_jobs:
        for job in osci.jobs:
            if job['name'] != jobname:
                continue

            if 'tox_extra_args' not in job['vars']:
                continue

            ret = re.search(r"-- (\S+:\S+)",
                            str(job['vars']['tox_extra_args']))
            if ret:
                targets.append(ret.group(1))

    return targets


def get_tests_bundles():
    """
    Extract test targets from primary location i.e. {src/}test/tests.yaml.
    """
    if os.path.exists(REACTIVE_TESTS_YAML):
        tests_file = REACTIVE_TESTS_YAML
    else:
        tests_file = CLASSIC_TESTS_YAML

    with open(tests_file, encoding='utf-8') as fd:
        bundles = yaml.safe_load(fd)

    smoke_bundles = extract_targets(bundles['smoke_bundles'])
    gate_bundles = extract_targets(bundles['gate_bundles'])
    dev_bundles = extract_targets(bundles['dev_bundles'])
    return smoke_bundles + gate_bundles + dev_bundles


if __name__ == "__main__":
    aliased_bundles = get_aliased_targets()
    tests_bundles = get_tests_bundles()
    print(' '.join(sorted(set(tests_bundles + aliased_bundles))))
