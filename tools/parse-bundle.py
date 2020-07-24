#!/usr/bin/env python3

import argparse
import yaml
import re
import sys

lpid = r"([~a-z0-9\-]+/)?"
charm = r"([a-z0-9\-]+)"
charm_match = re.compile(r".*cs:{}{}-([0-9]+)\s*$".format(lpid, charm))
status_match = re.compile("^App.*Version.*Status")
empty_line = re.compile("^\s*$")


def parse_arguments():
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
    charms = {}
    for app in bundle['applications']:
        charms[app] = bundle['applications'][app]['charm']
    return charms


def process_bundle(bundle):
    versions_found = False
    charms = get_charms(bundle)
    for app in charms:
        ret = charm_match.match(charms[app])
        if ret:
            versions_found = True
            _charm = ret.group(2)
            if ret.group(1):
                _charm = "{}{}".format(ret.group(1), _charm)

            print(_charm, charms[app])
    return versions_found


def process_status(model_status):
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
            ret = [l.strip() for l in line.split()]
            version = ret[1]
            charm = ret[4]
            store = ret[5]
            rev = ret[6]
            if store == 'jujucharms':
                versions_found = True
                print("{} cs:{}-{}".format(charm, charm, rev))

    return versions_found


def process(bundle_file, options):
    bundle = {}
    versions_found = False
    # Process revisions file assuming it is an exported bundle in yaml
    # format.
    try:
        bundle = yaml.load(bundle_file, Loader=yaml.SafeLoader)
    except yaml.scanner.ScannerError:
        sys.stderr.write("INFO: input file does not appear to be in YAML format")
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
        sys.stderr.write("WARNING: no valid charm revisions found in {}\n\n".
                         format(bundle_file.name))


def main():
    options = parse_arguments()
    if options.FILE == "-":
        with sys.stdin as bundle:
            process(bundle, options)
    else:
        with open(options.FILE) as bundle:
            process(bundle, options)


if __name__ == "__main__":
    main()
