#!/usr/bin/env python3

import sys
import yaml

application_list = set()

for filename in sys.argv[1:]:
    with open(filename, 'r') as f:
        data = yaml.load_all(f, Loader=yaml.SafeLoader)
        for d in data:
            if 'applications' in d:
                application_list.update(d['applications'].keys())
print('\n'.join(application_list))
