#!/bin/bash

# Setup-specific variables

current_path=/home/hema/testing_infrastructure/
remote_client_addr=hema@115.145.178.17
server_ip=30.0.0.3
IPERF_BIN=iperf
IPERF_CUSTOM_ARGS=""
PERF_BIN=/home/hema/Custom_Packet_Steering/linux-6.10.8/tools/perf/perf

# Argument List

exp_name=${1:-exp}
rss=${2:-1}
rps=${3:-0}
rfs=${4:-0}
custom=${5:-0}
backup_core=${6:-1}
conns=${7:-6}
intf=${8:-ens4np0}
iaps_busy_list=${9:-0}
num_queue=${10:-8}
gro=${11:-1}
separate=${12:-0}
mss=${13:-1460}
core_start=${14:-0}
core_num=${15:-8}
time=${16:-10} 

# Configure iperf bin

if command -v iperf3_napi &> /dev/null
then
	IPERF_BIN=iperf3_napi
	IPERF_CUSTOM_ARGS="--server-rx-timestamp 20,5000"
    echo "Using custom iperf3"
fi

# Create directory

mkdir $current_path/data/$exp_name

# Enable exit on error

set -e

# Disable irqbalancer

service irqbalance stop

# Setup RSS

if [[ "$rss" == "1" ]]
then
	echo "Enable RSS"
	ethtool -L $intf combined $num_queue
else
	echo "Disable RSS"
	ethtool -L $intf combined 1
	num_queue=1
fi

# Calculate Irq/PackProc/App Cores

if [[ "$separate" == "1" ]]
then

	IRQ_CORE=$core_start
	IRQ_CORE_NUM=$num_queue

	if [[ ( "$rps" == "1" ) || ( ( "$custom" == "1") && ( "$backup_core" != "1" ) ) ]]
	then	
		PP_CORE=$((core_start + IRQ_CORE_NUM))
		PP_CORE_NUM=$(( (core_num - IRQ_CORE_NUM) / 2))
		APP_CORE=$((core_start + IRQ_CORE_NUM + PP_CORE_NUM))
		APP_CORE_NUM=$((core_num - IRQ_CORE_NUM - PP_CORE_NUM))
	else
		PP_CORE=0
		PP_CORE_NUM=0
		APP_CORE=$((core_start + IRQ_CORE_NUM))
		APP_CORE_NUM=$((core_num - IRQ_CORE_NUM))
	fi

else
	IRQ_CORE=$core_start
	IRQ_CORE_NUM=$num_queue
	PP_CORE=$((core_start+num_queue))
	PP_CORE_NUM=$((core_num-num_queue))
	APP_CORE=$core_start
	APP_CORE_NUM=$core_num
fi


# Setup RFS/RPS

if [[ "$rps" == "1" ]]
then
	echo "Enable RPS"
	$current_path/scripts/enable_rps.sh $intf $PP_CORE $PP_CORE_NUM
else
	echo "Disable RPS"
	$current_path/scripts/disable_rps.sh $intf
fi

if [[ "$rfs" == "1" ]]
then
	echo "Enable RFS"
	$current_path/scripts/enable_rfs.sh $intf
else
	echo "Disable RFS"
	$current_path/scripts/disable_rfs.sh $intf

fi


# Setup IAPS
if [[ "$custom" == "1" ]]
then
	echo "Enable IAPS"
	$current_path/scripts/enable_rps.sh $intf $PP_CORE $PP_CORE_NUM	
    echo $backup_core > /sys/module/pkt_steer_module/parameters/choose_backup_core
	
	if [[ "$backup_core" == "1" ]]
	then
		$current_path/scripts/enable_rfs.sh $intf
	fi

	echo $iaps_busy_list > /sys/module/pkt_steer_module/parameters/list_position
	echo $PP_CORE > /sys/module/pkt_steer_module/parameters/base_cpu
	echo $PP_CORE_NUM > /sys/module/pkt_steer_module/parameters/max_cpus
	
	echo 1 > /sys/module/pkt_steer_module/parameters/custom_toggle
else
	if test -f /sys/module/pkt_steer_module/parameters/custom_toggle
	then 
		echo "Disable IAPS"
		echo 0 > /sys/module/pkt_steer_module/parameters/custom_toggle
	fi
fi

# Toggle GRO

if [[ "$gro" == "1" ]]
then
	ethtool -K $intf gro on
else
	ethtool -K $intf gro off
fi
	
# Set Queue Mappings

$current_path/scripts/set_affinity.sh $intf $core_start

# Get "Before" Values

$current_path/scripts/before.sh $intf

# Run perf stat

if [[ "$separate" == "1" ]]
then
	$PERF_BIN stat -C $IRQ_CORE-$((IRQ_CORE + IRQ_CORE_NUM - 1)) -e cycles,instructions,LLC-loads,LLC-load-misses -o $current_path/perf_stat_irq.json &
	IRQPERFSTAT_PID=$!
	if [[ "$PP_CORE_NUM" != "0" ]]
	then
		$PERF_BIN stat -C $PP_CORE-$((PP_CORE + PP_CORE_NUM - 1)) -e cycles,instructions,LLC-loads,LLC-load-misses -o $current_path/perf_stat_pp.json &
		PPPERFSTAT_PID=$!
	fi
	$PERF_BIN stat -C $APP_CORE-$((APP_CORE + APP_CORE_NUM - 1)) -e cycles,instructions,LLC-loads,LLC-load-misses -o $current_path/perf_stat_app.json &
	APPPERFSTAT_PID=$!
fi

$PERF_BIN stat -C $core_start-$((core_start + core_num - 1)) -e cycles,instructions,LLC-loads,LLC-load-misses -o $current_path/perf_stat.json &
PERFSTAT_PID=$!

# Run iperf3

echo
echo "Iperf Running..."
echo
taskset -c "$APP_CORE-$((APP_CORE + APP_CORE_NUM - 1))" $IPERF_BIN -s -1 -J $IPERF_CUSTOM_ARGS > $current_path/iperf.json & ssh $remote_client_addr "iperf3 -c ${server_ip} -P ${conns} -M ${mss} -t ${time} > /dev/null"
IPERF_PID=$!

# Insert any runtime data collection here 


#=======================================

# Wait for iperf3 to exit

tail --pid=$IPERF_PID -f /dev/null
echo "Iperf ended"

# Clean up perf stat

if [[ "$separate" == 1 ]]
then
	kill -s SIGINT $IRQPERFSTAT_PID
	tail --pid=$IRQPERFSTAT_PID -f /dev/null
	if [[ "$PP_CORE_NUM" != "0" ]]
	then
		kill -s SIGINT $PPPERFSTAT_PID
		tail --pid=$PPPERFSTAT_PID -f /dev/null
	fi
	kill -s SIGINT $APPPERFSTAT_PID
	tail --pid=$APPPERFSTAT_PID -f /dev/null

fi

kill -s SIGINT $PERFSTAT_PID
tail --pid=$PERFSTAT_PID -f /dev/null

# Get "After" Values

$current_path/scripts/after.sh $exp_name $intf

# Move iperf json to data folder

mv $current_path/iperf.json $current_path/data/$exp_name/

# Format perf output

echo "" > $current_path/data/$exp_name/perf_stat.json 
if [[ "$separate" == 1 ]]
then
	if test -f $current_path/perf_stat_irq.json
	then 
		echo "TYPE	IRQ" >> $current_path/data/$exp_name/perf_stat.json 
		cat $current_path/perf_stat_irq.json >> $current_path/data/$exp_name/perf_stat.json
		rm $current_path/perf_stat_irq.json
	fi

	if test -f $current_path/perf_stat_pp.json
	then 
		echo "TYPE	PP" >> $current_path/data/$exp_name/perf_stat.json 
		cat $current_path/perf_stat_pp.json >> $current_path/data/$exp_name/perf_stat.json
		rm $current_path/perf_stat_pp.json
	fi

	if test -f $current_path/perf_stat_app.json
	then 
		echo "TYPE	APP" >> $current_path/data/$exp_name/perf_stat.json 
		cat $current_path/perf_stat_app.json >> $current_path/data/$exp_name/perf_stat.json
		rm $current_path/perf_stat_app.json
	fi

fi

echo "TYPE	FULL" >> $current_path/data/$exp_name/perf_stat.json 
cat $current_path/perf_stat.json >> $current_path/data/$exp_name/perf_stat.json
rm $current_path/perf_stat.json


# Apply File Transformation

python3 $current_path/file_formatter.py $exp_name IRQ SOFTIRQ PACKET_CNT IPERF SOFTNET PROC_STAT PKT_STEER PERF_STAT IPERF_LAT BUSY_HISTO PKT_LAT_HISTO NETSTAT


