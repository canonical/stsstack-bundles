"""
Get names of test jobs that OSCI would run for the given charm. Should be
run from within the charm root.

Outputs space separated list of job names.
"""
import os

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
    for item in bundle_list or []:
        if isinstance(item, dict):
            values = list(item.values())
            for value in values:
                if isinstance(value, list):
                    # its a list of overlays so we get the key name and go find
                    # the corresponding job in osci.yaml
                    extracted.append(list(item.keys())[0])
                else:
                    # its a bundle name
                    extracted.append(value)
        else:
            extracted.append(item)

    return extracted


def get_job_deps(bundles):
    """
    Extract aliased targets. A charm can define aliased targets which is where
    Zaza tests are run and use configuration steps from an alias section rather
    than the default (see 'configure:' section in tests.yaml for aliases). An
    alias is run by specifying the target to be run as a tox command using a
    job definition in osci.yaml where the target name has a <alias>: prefix.

    We extract any aliased targets here and return as a list.

    @param bundles: list of extracted bundles
    """
    deps = []
    osci = OSCIConfig()
    project_check_jobs = list(osci.project_check_jobs)
    jobs = project_check_jobs + bundles
    for jobname in jobs:
        job = osci.get_job(jobname)
        if not job:
            continue

        # Some jobs will depend on other tests that need to be run but
        # are not defined in tests.yaml so we need to add them from
        # here as well.
        for name in job.get('dependencies', []):
            if name in project_check_jobs:
                deps.append(name)

    return deps + bundles


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
    _bundles = get_tests_bundles()
    _bundles = get_job_deps(list(set(_bundles)))
    print(' '.join(sorted(set(_bundles))))
