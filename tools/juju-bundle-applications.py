#!/usr/bin/env python3
# pylint: disable=invalid-name
"""
Get Juju Bundle or Overlay Applications.
"""
import sys

import yaml

if __name__ == "__main__":
    application_list = set()
    for filename in sys.argv[1:]:
        with open(filename, 'r', encoding='utf-8') as f:
            data = yaml.load_all(f, Loader=yaml.SafeLoader)
            for d in data:
                if 'applications' in d:
                    application_list.update(d['applications'].keys())
    print('\n'.join(application_list))
