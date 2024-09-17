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
    target_name = sys.argv[1]
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
            if target_name in jobs:
                # default is voting=True
                sys.exit(0)

            for check in jobs:
                if isinstance(check, dict) and target_name in check:
                    if not check[target_name]['voting']:
                        sys.exit(1)
                    else:
                        sys.exit(0)
        except KeyError as exc:
            sys.stderr.write(f"ERROR: failed to process osci.yaml - assuming "
                             f"{target_name} is voting (key {exc} not found)."
                             "\n")

    # If the target was not found in osci.yaml then osci will fallback to
    # looking at https://github.com/openstack-charmers/zosci-config/blob/master/zuul.d/project-templates.yaml  # noqa, pylint: disable=line-too-long
    if os.path.exists(project_templates):
        config = ProjectTemplatesConfig(project_templates)
        for project in config.project_templates:
            if project['name'] == "charm-functional-jobs":
                for job in project['check']['jobs']:
                    if target_name in job:
                        if not job[target_name].get('voting', True):
                            sys.exit(1)
