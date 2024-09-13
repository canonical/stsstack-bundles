""" Common helpers for func test runners. """
import os

import yaml


class OSCIConfig():
    """ Extract information from osci.yaml """
    def __init__(self):
        if not os.path.exists('osci.yaml'):
            self._osci_config = {}
        else:
            with open('osci.yaml', encoding='utf-8') as fd:
                self._osci_config = yaml.safe_load(fd)

    @property
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


class ProjectTemplatesConfig():
    """ Extract information from project_templates.yaml """
    def __init__(self, path):
        if not os.path.exists(path):
            self._config = {}
        else:
            with open(path, encoding='utf-8') as fd:
                self._config = yaml.safe_load(fd)

    @property
    def project_templates(self):
        """ Generator returning all project check jobs defined. """
        for item in self._config:
            if 'project-template' not in item:
                continue

            yield item['project-template']
