"""
If a job has an accompanying vars section that specifies a tox command with
target names we need to run those instead of the job name.
"""
import re
import sys

from common import OSCIConfig  # pylint: disable=import-error


def extract_job_target(testjob):
    """
    Some jobs map directly to target names and some needs to be de-refenced by
    looking for the job definition and extracting the target from the tox
    command. Returns jobname if no dereference available.

    @param job: job name
    """
    osci = OSCIConfig()
    job = osci.get_job(testjob)
    if not job or 'vars' not in job or 'tox_extra_args' not in job['vars']:
        return testjob

    ret = re.search(r"(?:--)?\s*(.+)",
                    str(job['vars']['tox_extra_args']))
    if not ret:
        return testjob

    return ret.group(1)


if __name__ == "__main__":
    print(extract_job_target(sys.argv[1]))
