#!/bin/bash

crm node show $HOSTNAME |grep -q 'standby=on'
STANDBY_OFF=$?

if [ $STANDBY_OFF -eq 1 ]; then
  echo "WARNING: This node is NOT in standby! Maybe you want to run crm node standby $HOSTNAME?"
fi