"""
Get names of test jobs that OSCI would run for the given charm. Should be
run from within the charm root.

Outputs space separated list of job names.
"""
import configparser
import os

from common import ZOSCIConfig, OSCIConfig  # pylint: disable=import-error


def get_local_jobs_and_deps(jobs):
    """
    Get any locally defined jobs and add them to the list of jobs provided.

    @param jobs: list of already identified jobs.
    """
    deps = []
    local_jobs = []
    osci = OSCIConfig()
    project_check_jobs = list(osci.project_check_jobs)
    all_jobs = project_check_jobs + jobs
    for jobname in all_jobs:
        if isinstance(jobname, dict):
            jobname = list(jobname.keys())[0]

        job = osci.get_job(jobname)
        if not job:
            continue

        local_jobs.append(jobname)

        # Some jobs will depend on other tests that need to be run but
        # are not defined in tests.yaml so we need to add them from
        # here as well.
        for name in job.get('dependencies', []):
            if name in project_check_jobs:
                deps.append(name)

    return deps + jobs + local_jobs


def get_default_jobs():
    """
    Get all jobs we need to run by default for the given branch.
    """
    path = os.path.join(os.environ['HOME'], 'zosci-config')
    c = configparser.ConfigParser()
    c.read('.gitreview')
    branch = c['gerrit'].get('defaultbranch', 'master')
    osci = OSCIConfig()
    jobs = ZOSCIConfig(path).get_branch_jobs(branch, osci.project_templates)
    return jobs


if __name__ == "__main__":
    _jobs = get_default_jobs()
    _jobs = get_local_jobs_and_deps(list(set(_jobs)))
    print(' '.join(sorted(set(_jobs))))
