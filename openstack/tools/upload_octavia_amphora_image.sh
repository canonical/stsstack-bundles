#!/bin/bash -eu

juju run octavia-diskimage-retrofit/0 retrofit-image --wait 10m
