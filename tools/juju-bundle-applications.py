#!/usr/bin/env python3

import sys
import yaml

application_list = set()

for filename in sys.argv[1:]:
    with open(filename, 'r') as f:
        data = yaml.load(f, Loader=yaml.SafeLoader)
        if 'applications' in data:
            application_list.update(data['applications'].keys())

print('\n'.join(application_list))
