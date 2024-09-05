# Get names of test targets that OSCI would run for the given charm. Should be
# run from within the charm root.
#
# Outputs space seperated list of target names.
#
import os
import yaml

CLASSIC_TESTS_YAML = 'tests/tests.yaml'
REACTIVE_TESTS_YAML = os.path.join('src', CLASSIC_TESTS_YAML)

if os.path.exists(REACTIVE_TESTS_YAML):
    bundles = yaml.safe_load(open(REACTIVE_TESTS_YAML))
else:
    bundles = yaml.safe_load(open(CLASSIC_TESTS_YAML))

targets = set(bundles['smoke_bundles'] + bundles['gate_bundles'] +
              bundles['dev_bundles'])

print(' '.join(sorted(targets)))
