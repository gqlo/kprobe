#!/bin/bash
hname=$(hostname)
FIO=$(command -v fio)

if [[ ! -d /root/fio-output/ ]]; then
   mkdir -p /root/fio-output/
fi
{

#declare -A io_rate
workload=("randwrite" "randread")
block_size=(4k 8k 16k 32k 64k 128k 256k 512k 1024k 2048k 4096k)
#cpuio, psync, libaio
io_engine=libaio
iodepth=(4 8 16 32 64 128)
num_jobs=(2 4 6)
size=50G
lockmem=1G
thinktime=1s
cpuload=100
io_rate=(5000000)
rwmixread=70
o_direct=1
time_based=1
run_time=3m
run_name="$1"
echo "current run=$run_name"
for load in ${workload[@]}; do
   for blk in ${block_size[@]}; do
      for depth in ${iodepth[@]}; do
	 for job in ${num_jobs[@]}; do
	    for iorate in ${io_rate[@]}; do
	       output_file="/root/fio-output/$run_name-$hname-$blk-$load-depth-$iodepth-numjob-$job-rate-$iorate.json"
	       if [[ $load == "randread" ]]; then
		  fio_base_cmd="fio --name=$hname --filename=/dev/vdb --ioengine=$io_engine --rw=$load --bs=$blk --direct=$o_direct --rwmixread=$rwmixread --numjobs=$job --runtime=$run_time --iodepth=$depth --time_based=$time_based --output-format=json+ --output=$output_file --rate_iops=$iorate"
	       else
		  fio_base_cmd="fio --name=$hname --filename=/dev/vdb --size=$size --ioengine=$io_engine --rw=$load --bs=$blk --direct=$o_direct --rwmixread=$rwmixread --numjobs=$job --runtime=$run_time --iodepth=$depth --time_based=$time_based --output-format=json+ --output=$output_file --rate_iops=$iorate"
	       fi
	       if [[ -f "$output_file" ]]; then
		 sudo rm -rf "$output_file"
	       fi

	       if [[ -z "$FIO" ]]; then
		  sudo dnf install -y fio
	       fi

	       echo "batch=$run_name, vmi=$hname, iodepth=$depth, iorate=$iorate, fio=$load, blk=$blk, started $(date +"%Y-%m-%d %H:%M:%S")"
	       if [[ $io_engine == "cpuio" ]]; then
		  eval "$fio_base_cmd --cpuload=$cpuload"
	       elif [[ $io_engine == "psync" ]]; then
		  eval "$fio_base_cmd --lockmem=$lockmem --thinktime=$thinktime"
	       else
		  eval "$fio_base_cmd"
	       fi
	       sudo rm -rf /root/fio-output/$hname
	       echo "batch=$run_name, vmi=$hname, iodepth=$depth, iorate=$iorate, fio=$load, blk=$blk, ended $(date +"%Y-%m-%d %H:%M:%S")"
	       sleep 60
	    done
	 done
      done
      sleep 180
   done
done
}  2>&1 | tee -a /root/fio-output/fio-"$hname-main".log
