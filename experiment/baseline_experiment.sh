#!/bin/bash
source my_lib.sh

intf=$1
rep=$2
conns=$3

current_path=/home/hema/testing_infrastructure/

exponential=0

# Create Meta-Experiment Directory
name="Main_Baseline2"
mkdir $current_path/data/$name

# General Setup Parameters that don't change
set_intf $intf
set_sep $ON
set_gro $ON
set_mss 1460
set_core_start 0
set_core_num 8

# Experiment Setup 1: RSS
exp_name="RSS"

set_rss $ON
set_queues 4

run_exp $exp_name $rep $conns $exponential $name

# Experiment Setup 2: RPS
exp_name="RPS"
set_queues 1

set_rps $ON

run_exp $exp_name $rep $conns $exponential $name

#Experiment Setup 3: RFS
exp_name="RFS"

set_rfs $ON

run_exp $exp_name $rep $conns $exponential $name


# Summarize
summarize $current_path $rep $conns $exponential $name

