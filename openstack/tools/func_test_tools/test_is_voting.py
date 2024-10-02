"""
Takes a func test target name as input.

 - Exit return code 0 == voting
 - Exit return code 1 == non-voting
"""
import os
import sys

from common import (  # pylint: disable=import-error
    OSCIConfig,
    ProjectTemplatesConfig,
)


if __name__ == "__main__":
    test_job = sys.argv[1]
    zosci_path = os.path.join(os.environ['HOME'], "zosci-config")
    project_templates = os.path.join(zosci_path,
                                     "zuul.d/project-templates.yaml")
    """
    First look for the func-target in osci
    """
    if os.path.exists('osci.yaml'):
        osci_config = OSCIConfig()
        try:
            jobs = osci_config.project_check_jobs
            for job in jobs:
                if isinstance(job, dict) and test_job in job:
                    if not job[test_job]['voting']:
                        sys.exit(1)
                    else:
                        # default is true
                        sys.exit(0)

        except KeyError as exc:
            sys.stderr.write(f"ERROR: failed to process osci.yaml - assuming "
                             f"{test_job} is voting (key {exc} not found)."
                             "\n")

    # If the target was not found in osci.yaml then osci will fallback to
    # looking at https://github.com/openstack-charmers/zosci-config/blob/master/zuul.d/project-templates.yaml  # noqa, pylint: disable=line-too-long
    if os.path.exists(project_templates):
        config = ProjectTemplatesConfig(project_templates)
        for project in config.project_templates:
            if project['name'] == "charm-functional-jobs":
                for job in project['check']['jobs']:
                    if test_job in job:
                        if not job[test_job].get('voting', True):
                            sys.exit(1)
