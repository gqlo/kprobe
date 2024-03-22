#!/bin/bash
hname=$(hostname)
FIO=$(command -v fio)

{
if [[ ! -d /root/fio-output/ ]]; then
   mkdir -p /root/fio-output/
fi

# workload=(randwrite randread randrw)
workload=(randread)
block_size=(4k 8k 16k 32k 64k 128k 256k 1024k)
iodepth=256
num_jobs=1
run_time=30m
file_size=8G
io_engine=libaio
o_direct=1


for load in ${workload[@]}; do
   for blk in ${block_size[@]}; do
      output_file="/root/fio-output/$load-$hname-$batch_num-$blk.txt"
      if [[ -f "$output_file" ]]; then
        sudo rm -rf "$output_file"
      fi
      
      if [[ -z "$FIO" ]]; then
         sudo dnf install -y fio
      fi

      echo "batch=$batch_num, vmi=$hname, fio=$load started $(date +"%Y-%m-%d %H:%M:%S")"
      if [[ $load == "randread" ]]; then
         fio --name=$hname --filename=/dev/vda --ioengine="$io_engine" --rw="$load" --bs="$blk" --direct="$o_direct" --numjobs="$num_jobs" --size="$file_size" --runtime="$run_time"  --iodepth="$iodepth" --output="$output_file"
      else
         fio --name=$hname --ioengine="$io_engine" --rw="$load" --bs="$blk" --direct="$o_direct" --numjobs="$num_jobs" --size="$file_size" --runtime="$run_time"  --iodepth="$iodepth" --output="$output_file"
      fi
      sudo rm -rf /root/rhel9*
      echo "batch=$batch_num, vmi=$hname, fio=$load ended $(date +"%Y-%m-%d %H:%M:%S")"
      sleep 15
   done
done
}  2>&1 | tee -a /root/fio-output/fio-"$hname"-"$batch_num".log
