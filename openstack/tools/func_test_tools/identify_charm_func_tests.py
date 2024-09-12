"""
Get names of test targets that OSCI would run for the given charm. Should be
run from within the charm root.

Outputs space separated list of target names.
"""
import os

import yaml

OSCI_YAML = 'osci.yaml'
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


def extract_targets_from_osci(osci_yaml):
    """
    Additional Targets from osci.yaml
    """
    extracted = []
    try:
        check_jobs = osci_yaml[0]['project']['check']['jobs']
        for job in osci_yaml:
            if 'job' in job:
                job_name = job['job']['name']
                if job_name in check_jobs:
                    tox_args = job['job']['vars']['tox_extra_args']
                    extracted.append(tox_args.replace('--', ''))
    except Exception as e:
		pass	

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

    # read osci.yaml and extract target from there
    with open(OSCI_YAML, encoding='utf-8') as fd:
        osci_yaml = yaml.safe_load(fd)

    osci_targets = extract_targets_from_osci(osci_yaml)

    targets = set(smoke_bundles + gate_bundles + dev_bundles + osci_targets)

    print(' '.join(sorted(targets)))
