#!/bin/bash
hname=$(hostname)
FIO=$(command -v fio)

if [[ ! -d /root/fio-output/ ]]; then
   mkdir -p /root/fio-output/
fi
{

#declare -A io_rate
workload=("read")
block_size=(4096k)
#cpuio, psync, libaio
io_engine=libaio
iodepth=(128)
num_jobs=512
size=50G
lockmem=1G
thinktime=1s
cpuload=100
# 4k - 128k
#io_rate=(32 65 97 130 162 195 227 260 292 325 357 390 422 455 487 520 552 585 617 650 682 715 747 780 812 845 877 910)
# 256k - 512k
#io_rate=(16 32 49 65 82 98 114 131 147 164 180 197 213 229 246 262 279 295 312 328 344 361 377 394 410 427 443 459)
# 1024k - 2048k
# io_rate=(3 7 11 15 18 22 26 30 34 37 41 45 49 53 56 60 64 68 71 75 79 83 87 90 94 98 102 106 109 113 117 121 125 128 132 136 140 143 147 151 155 159 162 166 170 174 178 181 185 189 193 197)
# randread 4k - 128k
#io_rate=(120 241 362 483 604 725 846 967 1088 1209 1329 1450 1571 1692 1813 1934 2055 2176 2297 2418 2538 2659 2780 2901 3022 3143 3264 3385 3506 3627 3748 3868 3989 4110 4231 4352 4473 4594 4715 4836 4957 5077 5198 5319 5440 5561)
#io_rate=(4957 5077 5198 5319 5440 5561 5682 5803 5924 6045 6166 6287 6407 6528 6649 6770 6891 7012 7133 7254 7375 7496)
io_rate=(5000000)
# randread 256k - 512k
# io_rate=(58 116 174 232 290 348 406 464 522 580 638 696 754 812 870 928 986 1045 1103 1161 1219 1277 1335 1393 1451 1509 1567 1625 1683 1741 1799 1857 1915 1973 2032 2090 2148 2206 2264 2322 2380 2438 2496 2554 2612 2670 2728)
rwmixread=70
o_direct=1
time_based=1
run_time=3m
run_name="$1"
echo "current run=$run_name"
for load in ${workload[@]}; do
   for depth in ${iodepth[@]}; do
      for blk in ${block_size[@]}; do
   	 for iorate in ${io_rate[@]}; do
	    # output_file="/root/fio-output/$run_name-$hname-$blk-$load-depth-$iodepth-rate-$iorate.json"
	    if [[ $load == "randread" ]]; then
	       fio_base_cmd="fio --name=$hname --filename=/dev/nvme0n1 --ioengine=$io_engine --rw=$load --bs=$blk --direct=$o_direct --rwmixread=$rwmixread --numjobs=$num_jobs --runtime=$run_time --iodepth=$iodepth --time_based=$time_based  --rate_iops=$iorate"
	    else
	       fio_base_cmd="fio --name=$hname --filename=/dev/nvme0n1 --size=$size --ioengine=$io_engine --rw=$load --bs=$blk --direct=$o_direct --rwmixread=$rwmixread --numjobs=$num_jobs --runtime=$run_time --iodepth=$iodepth --time_based=$time_based --rate_iops=$iorate"
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
done
}  2>&1 | tee -a /root/fio-output/fio-"$hname-main".log
