#!/bin/bash

#===========================[FILL IN BELOW]===========================

# The absolute path to this github repository
CURR_PATH=/home/hema/testing_infrastructure/

# How to access your iperf binary
STANDARD_IPERF_BIN=iperf

# How to access your perf binary
PERF_BIN=/home/hema/Custom_Packet_Steering/linux-6.10.8/tools/perf/perf

# How to ssh onto your remote node
REMOTE_SSH=hema@115.145.178.17

# The IP address of this server's target network interface
SERVER_TARGET_IP=30.0.0.3

#=====================================================================

# Set Path

NO_SPEC_PATH="$(echo "$CURR_PATH" | sed -e 's/\//\\\//g')"
find $CURR_PATH -type f -not -path "*/data/*" -not -path "*configure.sh*" -exec sed -i -E "s/current_path=[[:space:]]*\".*/current_path=\"$NO_SPEC_PATH\"/g" {} \;
find $CURR_PATH -type f -not -path "*/data/*" -not -path "*configure.sh*" -exec sed -i -E "s/current_path=[^\"].*/current_path=$NO_SPEC_PATH/g" {} \;

# Set iperf
NO_SPEC_PATH="$(echo "$STANDARD_IPERF_BIN" | sed -e 's/\//\\\//g')"
sed -i "0,/IPERF_BIN=.*/s/IPERF_BIN=.*/IPERF_BIN=$NO_SPEC_PATH/" run_mini_project.sh

# Set perf
NO_SPEC_PATH="$(echo "$PERF_BIN" | sed -e 's/\//\\\//g')"
sed -i "s/\bPERF_BIN=.*/PERF_BIN=$NO_SPEC_PATH/g" run_mini_project.sh

# Set remote ssh target
sed -i "s/remote_client_addr=.*/remote_client_addr=$REMOTE_SSH/g" run_mini_project.sh

# Set server IP
sed -i "s/server_ip=.*/server_ip=$SERVER_TARGET_IP/g" run_mini_project.sh

