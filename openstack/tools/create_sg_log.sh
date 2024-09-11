#!/bin/bash -u
openstack network loggable resources list
openstack network log create --resource-type security_group \
                                --description "Collecting all security events" \
                                --enable --event ALL Log_Created