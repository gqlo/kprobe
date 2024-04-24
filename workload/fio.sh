#!/bin/bash
hname=$(hostname)
FIO=$(command -v fio)

if [[ ! -d /root/fio-output/ ]]; then
   mkdir -p /root/fio-output/
fi
{
workload=(randwrite)
block_size=(4k 8k 16k 32k 64k)
#cpuio, psync, libaio
io_engine=libaio
iodepth=32
num_jobs=1
size=1G
lockmem=1G
thinktime=1s
cpuload=100
o_direct=1
time_based=1
run_time=15m
batch_num="$1"
echo "current batch num=$batch_num"
for load in ${workload[@]}; do
   for blk in ${block_size[@]}; do
      output_file="/root/fio-output/$load-$hname-$batch_num-$blk.txt"
      if [[ $load == "randread" ]]; then
         fio_base_cmd="fio --name=$hname --filename=/dev/vda --ioengine=$io_engine --rw=$load --bs=$blk --direct=$o_direct --numjobs=$num_jobs --runtime=$run_time --iodepth=$iodepth --time_based=$time_based --output=$output_file"
      else
         fio_base_cmd="fio --name=$hname --filename=/root/fio-output/$hname --size=$size --ioengine=$io_engine --rw=$load --bs=$blk --direct=$o_direct --numjobs=$num_jobs --runtime=$run_time --iodepth=$iodepth --time_based=$time_based --output=$output_file"
      fi
      if [[ -f "$output_file" ]]; then
        sudo rm -rf "$output_file"
      fi

      if [[ -z "$FIO" ]]; then
         sudo dnf install -y fio
      fi

      echo "batch=$batch_num, vmi=$hname, fio=$load, blk=$blk, started $(date +"%Y-%m-%d %H:%M:%S")"
      if [[ $io_engine == "cpuio" ]]; then
         eval "$fio_base_cmd --cpuload=$cpuload"
      elif [[ $io_engine == "psync" ]]; then
         eval "$fio_base_cmd --lockmem=$lockmem --thinktime=$thinktime"
      else
         eval "$fio_base_cmd"
      fi
      sudo rm -rf /root/fio-output/$hname
      echo "batch=$batch_num, vmi=$hname, fio=$load, blk=$blk, ended $(date +"%Y-%m-%d %H:%M:%S")"
      sleep 120
   done
done
}  2>&1 | tee -a /root/fio-output/fio-"$hname-main".log
