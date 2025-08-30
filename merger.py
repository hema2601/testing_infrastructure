import json
import os
import sys


reps = int(sys.argv[1])
conns_pow_of_2 = int(sys.argv[2])
exponential = int(sys.argv[3])
if len(sys.argv) > 4:
    base_dir = sys.argv[4]
else:
    base_dir = "."

bases = ["RSS", "RPS", "RFS", "RSS+RPS", "RSS+RFS", "Custom", "Custom1", "Custom2", "Custom3", "RSS+Custom", "RSS+Custom1", "RSS+Custom2", "RSS+Custom3", "Custom1-0", "Custom1-1", "Custom1-2", "Custom1-3", "Custom2-0", "Custom2-1", "Custom2-2", "Custom2-3", "IAPS+RFS", "IAPS+RPS", "IAPS+LB", "IAPS-Base", "IAPS-Basic-Overload", "IAPS-Full-Overload", "IAPS-Idle-Core", "IAPS-Basic-Overload-20", "IAPS-Full-Overload-20", "IAPS-Idle-Core-20", "IAPS-Basic-Overload-10", "IAPS-Full-Overload-10", "IAPS-Idle-Core-10", "IAPS-Basic-Overload-30", "IAPS-Full-Overload-30", "IAPS-Idle-Core-30", "IAPS-Basic-Overload-40", "IAPS-Full-Overload-40", "IAPS-Idle-Core-40", "IAPS-Basic-Overload-50", "IAPS-Full-Overload-50", "IAPS-Idle-Core-50", "IAPS-Basic-Overload-5", "IAPS-Full-Overload-5", "IAPS-Idle-Core-5", "IAPS-Basic-Overload-15", "IAPS-Full-Overload-15", "IAPS-Idle-Core-15", "IAPS-Basic-Overload-25", "IAPS-Full-Overload-25", "IAPS-Idle-Core-25", "IAPS-Full-Overload-60", "IAPS-Full-Overload-80", "IAPS-Full-Overload-100", "IAPS-Full-Overload-35", "IAPS-Full-Overload-45", "IAPS-Full-Overload-50", "IAPS-Full-Overload-55"]

directory = []

exp = 1
tmp = []
for i in range(conns_pow_of_2):
    for base in bases:
        if exponential == 1:
            tmp.append(base+"_"+str(exp))
        else:
            tmp.append(base+"_"+str(i+1))
    exp *= 2

for i in range(reps):
    for curr_dir in tmp:
        directory.append(curr_dir+"_"+str(i+1))

files = ["iperf.json", "irq.json", "packet_cnt.json", "softirq.json", "softnet.json", "pkt_steer.json", "latency.json", "proc_stat.json", "perf.json", "perf_stat.json", "iperf_lat.json", "busy_histo.json", "pkt_lat_histo.json", "netstat.json", "pkt_size_histo.json"]

current_path="/home/hema/testing_infrastructure/"

os.mkdir(current_path + "summaries")


for f in files:
    
    new_dict = list()
    
    # Create new file
    file_name = "summary_"+f


    with open(current_path + "summaries/"+file_name, "w") as file:

        for exp in directory:
            if os.path.isfile(current_path + "data/" + base_dir + "/" + exp+"/"+f) is False:
                continue
            with open(current_path + "data/" + base_dir + "/"+exp+"/"+f) as json_file:
                d = json.load(json_file)
                for elem in d:
                    elem["Exp"]=exp.split("_")[0]
                    elem["Conns"]=exp.split("_")[1]
                    elem["Rep"]=exp.split("_")[2]
                    new_dict.append(elem)

        json.dump(new_dict, file, indent=0)

