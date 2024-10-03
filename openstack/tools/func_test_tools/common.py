""" Common helpers for func test runners. """
from functools import cached_property
import os

import yaml


class ZOSCIConfig():
    """ Extract information from zosci-config """
    def __init__(self, path):
        self.path = path

    @cached_property
    def project_templates(self):
        """
        Generator returning each project-template defined.
        """
        with open(os.path.join(self.path, 'zuul.d/project-templates.yaml'),
                  encoding='utf-8') as fd:
            yield from yaml.safe_load(fd)

    def get_branch_jobs(self, branch, project_templates):
        """
        For a given branch name, find all jobs that need to be run against that
        branch.
        """
        test_jobs = []
        for t in self.project_templates:
            t = t['project-template']

            # only look at functional test jobs
            if 'functional' not in t['name']:
                continue

            if t['name'] not in project_templates:
                continue

            if 'check' not in t or 'jobs' not in t['check']:
                continue

            for jobs in t['check']['jobs']:
                if not isinstance(jobs, dict):
                    test_jobs.append(jobs)
                    continue

                for job, info in jobs.items():
                    if t['name'] == 'charm-functional-jobs':
                        if branch not in info['branches']:
                            continue

                    test_jobs.append(job)

        return test_jobs


class OSCIConfig():
    """ Extract information from osci.yaml """
    def __init__(self):
        path = os.path.join(os.environ.get('CHARM_ROOT_PATH', ''), 'osci.yaml')
        with open(path, encoding='utf-8') as fd:
            self._osci_config = yaml.safe_load(fd)

    @cached_property
    def project_templates(self):
        """ Returns all project templates. """
        for item in self._osci_config:
            if 'project' not in item:
                continue

            return item['project'].get('templates', [])

        return []

    @cached_property
    def project_check_jobs(self):
        """ Generator returning all project check jobs defined. """
        for item in self._osci_config:
            if 'project' not in item:
                continue

            if 'check' not in item['project']:
                continue

            yield from item['project']['check'].get('jobs', [])

    @property
    def jobs(self):
        """ Generator returning all job definitions. """
        for item in self._osci_config:
            if 'job' in item:
                yield item['job']

    def get_job(self, name):
        """ Get job by name.

        @param name: string name
        """
        for job in self.jobs:
            if job['name'] == name:
                return job

        return None

    def get_project_check_job(self, name):
        """ Get job by name from project.check.jobs. Return can be string name
        or dict.

        @param name: string name
        """
        for job in self.project_check_jobs:
            if isinstance(job, dict):
                if name in job:
                    return job
            elif job == name:
                return job

        return None
