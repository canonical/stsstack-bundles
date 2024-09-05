# Get names of test targets that OSCI would run for the given charm. Should be
# run from within the charm root.
#
# Outputs space seperated list of target names.
#
import os
import yaml

CLASSIC_TESTS_YAML = 'tests/tests.yaml'
REACTIVE_TESTS_YAML = os.path.join('src', CLASSIC_TESTS_YAML)

def extract_values(bundle_list):
    extracted = []
    for item in bundle_list:
        if isinstance(item, dict):
            extracted.append(list(item.values())[0])
        else:
            extracted.append(item)
    return extracted

if os.path.exists(REACTIVE_TESTS_YAML):
    bundles = yaml.safe_load(open(REACTIVE_TESTS_YAML))
else:
    bundles = yaml.safe_load(open(CLASSIC_TESTS_YAML))

smoke_bundles = extract_values(bundles['smoke_bundles'])
gate_bundles = extract_values(bundles['gate_bundles'])
dev_bundles = extract_values(bundles['dev_bundles'])

targets = set(smoke_bundles + gate_bundles + dev_bundles)

print(' '.join(sorted(targets)))
