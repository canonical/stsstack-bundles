#!/bin/bash

set -e -u

# This script checks that the commit message is well-formed.
#
# The script takes up to 2 arguments.
#
# ./lint-git-messages.sh [BASE_SHA [HEAD_SHA]]
#
# If both arguments are provided, the script will check all commits in the
# commit range BASE_SHA..HEAD_SHA. If only BASE_SHA is provided, the script
# will check all commits in the range BASE_SHA..HEAD. If no arguments are
# provided then the script will check all commits in the range (merge-base
# origin/main)..HEAD.
#
# A commit message is exprected to be in the following format:
#
# [TYPE] SUBJECT (<= 50 characters)
#
# MESSAGE BODY (<= 72 characters per line)

if (( $# == 2 )); then
    base_commit=$1
    head_commit=$2
elif (( $# == 1 )); then
    base_commit=$1
    head_commit=HEAD
else
    base_commit=$( git merge-base HEAD origin/main )
    head_commit=HEAD
fi

for sha in $(git rev-list --no-merges ${base_commit}..${head_commit}); do
    readarray -t message < <(git log --format=%B --max-count=1 ${sha})

    # Check subject
    echo "${sha} Checking subject: ${message[0]}"
    if (( $(wc --chars <<<${message[0]}) > 50 )); then
        echo "Subject line is > 50 characters"
        exit 1
    fi
    if grep --quiet --invert-match --extended-regexp '^[[][^]]+[]].*$' <<<${message[0]}; then
        echo "Subject needs to start with '[TYPE]' where TYPE is e.g. {bug, enhancement, doc, CI}"
        exit 1
    fi

    # Check body
    echo "${sha} Checking commit message body"
    if (( ${#message[@]} > 1 )); then
        if [[ -n ${message[1]} ]]; then
            echo "Empty line after subject required"
            exit 1
        fi
        for i in $(seq 2 $(( ${#message[@]} - 1 ))); do
            if (( $(wc --chars <<<${message[${i}]}) > 72 )); then
                echo "Body line is > 72 characters"
                echo "${message[${i}]}"
                exit 1
            fi
        done
    fi
    echo "${sha} passed"
done
