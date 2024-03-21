#!/bin/bash
hname=$(hostname)
FIO=$(command -v fio)
iodepth=256

{
if [[ ! -d /root/fio-output/ ]]; then
   mkdir -p /root/fio-output/
fi

workload=(randwrite randread randrw)

for load in ${workload[@]}; do
   output_file="/root/fio-output/$load-$hname-$batch_num.txt"
   if [[ -f "$output_file" ]]; then
     sudo rm -rf "$output_file"
   fi
   
   if [[ -z "$FIO" ]]; then
      sudo dnf install -y fio
   fi

   echo "batch=$batch_num, vmi=$hname, fio=$load started $(date +"%Y-%m-%d %H:%M:%S")"
   if [[ $load == "randread" ]]; then
      fio --name=$hname --ioengine=libaio --rw="$load" --bs=4k --direct=1 --numjobs=1 --size=8G --runtime=30m  --iodepth="$iodepth" --output="$output_file"
   else
      fio --name=$hname --ioengine=libaio --rw="$load" --bs=4k --direct=1 --numjobs=1 --size=8G --runtime=30m  --iodepth="$iodepth" --output="$output_file"
   fi
   sudo rm -rf /root/rhel9*
   echo "batch=$batch_num, vmi=$hname, fio=$load ended $(date +"%Y-%m-%d %H:%M:%S")"
   sleep 120

done
}  2>&1 | tee -a /root/fio-output/fio-"$hname"-"$batch_num".log
