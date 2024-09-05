#!/usr/bin/env python3
# pylint: disable=invalid-name
"""
Parse bundle information.
"""
import argparse
import re
import sys

import yaml

lpid_expr = r"([~a-z0-9\-]+/)?"
charm_name_expr = r"([a-z0-9\-]+)"
charm_expr = re.compile(fr".*cs:{lpid_expr}{charm_name_expr}-([0-9]+)\s*$")
status_match = re.compile(r"^App.*Version.*Status")
empty_line = re.compile(r"^\s*$")


def parse_arguments():
    """ Parse cli args. """
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "FILE",
        help="Parse bundle from FILE. If specifying `-` then read "
        "from standard input.",)
    parser.add_argument(
        "--get-charms",
        action="store_true",
        help="Get charms and their revisions from bundle.")
    return parser.parse_args()


def get_charms(bundle):
    """ Get charms from bundle. """
    charms = {}
    for app in bundle['applications']:
        charms[app] = bundle['applications'][app]['charm']
    return charms


def process_bundle(bundle):
    """ Extra charm info from bundle. """
    versions_found = False
    charms = get_charms(bundle)
    for appinfo in charms.values():
        ret = charm_expr.match(appinfo)
        if ret:
            versions_found = True
            _charm = ret.group(2)
            if ret.group(1):
                _charm = f"{ret.group(1)}{_charm}"

            print(_charm, appinfo)
    return versions_found


def process_status(model_status):
    """ Extract charm versions from model status. """
    versions_found = False
    processing = False
    for line in model_status:
        if status_match.match(line):
            processing = True
            continue
        if empty_line.match(line):
            processing = False
            continue
        if processing:
            ret = line.strip().split()
            charm = ret[4]
            store = ret[5]
            rev = ret[6]
            if store == 'jujucharms':
                versions_found = True
                print(f"{charm} cs:{charm}-{rev}")

    return versions_found


def process(bundle_file, options):
    """ Process a bundle. """
    bundle = {}
    versions_found = False
    # Process revisions file assuming it is an exported bundle in yaml
    # format.
    try:
        bundle = yaml.load(bundle_file, Loader=yaml.SafeLoader)
    except yaml.scanner.ScannerError:
        sys.stderr.write("INFO: input file does not appear to be in YAML "
                         "format\n")
    if 'applications' in bundle:
        if options.get_charms:
            versions_found = process_bundle(bundle)
    else:
        # Process revisions file assuming it is the output of a `juju
        # status` command.
        bundle_file.seek(0)
        model_status = bundle_file.readlines()
        if options.get_charms:
            versions_found = process_status(model_status)

    if not versions_found:
        sys.stderr.write(f"WARNING: no valid charm revisions found in "
                         f"{bundle_file.name}\n\n")


if __name__ == "__main__":
    _options = parse_arguments()
    if _options.FILE == "-":
        with sys.stdin as _bundle:
            process(_bundle, _options)
    else:
        with open(_options.FILE, encoding='utf-8') as _bundle:
            process(_bundle, _options)
