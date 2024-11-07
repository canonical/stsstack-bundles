"""
Takes a func test target name as input.

 - Exit return code 0 == voting
 - Exit return code 1 == non-voting
"""
import os
import sys

from common import (  # pylint: disable=import-error
    OSCIConfig,
    ZOSCIConfig,
)


def is_job_voting(job, name):
    """
    Jobs are voting by default so only return False if there is a match and it
    is a dict with voting=False.
    """
    if isinstance(job, dict):
        if name in job:
            return job[name].get('voting', True)

    return True


def is_test_voting():
    """
    Exit with 1 if test is non-voting otherwise 0.
    """
    test_job = sys.argv[1]
    # First look for the func-target in osci
    if os.path.exists('osci.yaml'):
        osci_config = OSCIConfig()
        try:
            job = osci_config.get_project_check_job(test_job)
            if not is_job_voting(job, test_job):
                sys.exit(1)

            # default is true
        except KeyError as exc:
            sys.stderr.write(f"ERROR: failed to process osci.yaml - assuming "
                             f"{test_job} is voting (key {exc} not found)."
                             "\n")

    # If the target was not found in osci.yaml then osci will fallback to zosci
    project_template = 'charm-functional-jobs'
    for template in osci_config.project_templates:
        if 'functional' in template:
            project_template = template

    path = os.path.join(os.environ['HOME'], 'zosci-config')
    for project in ZOSCIConfig(path).project_templates:
        t = project['project-template']
        if ('functional' not in t['name'] or t['name'] != project_template):
            continue

        for job in t['check']['jobs']:
            if not is_job_voting(job, test_job):
                sys.exit(1)


if __name__ == "__main__":
    is_test_voting()
