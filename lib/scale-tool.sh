# file paths
vm_template="/root/h-bench/template/cnv/vm.yaml"
vm_deployment_path="/root/cnv/data/batch_completed_time.csv"
vmi_running_path="/root/cnv/data/vmi_running_time.csv"
batch_num=1000

# batch create 100 VMs at a time
batch_create_vm() {
   local vm_num="$1"
   local i
   for ((i="$vm_num"; i<vm_num+batch_num; i++)); do
      sed "s/placeholder/$i/g" "$vm_template" | oc create -f - &
   done
}

batch_start_vm() {
   local vm_num="$1"
   local i
   for ((i="$vm_num"; i<vm_num+batch_num; i++)); do
      virtctl start rhel9-$i &
   done
}

count_dv_line() {
   local start="$1"
   local end="$2"
   local dv_line=$(oc get dv -n default | grep "-" | sed 's/^[^-]*-//'| awk -v start="$start" -v end="$end" '$1 >= start && $1 <= end' | grep "100.0%" | wc -l)
   echo "$dv_line"
}

count_vmi_line() {
   local start="$1"
   local end="$2"
   local vmi_line=$(oc get vmi -n default | grep "-" | sed 's/^[^-]*-//'| awk -v start="$start" -v end="$end" '$1 >= start && $1 <= end' | grep "Running" | wc -l)
   echo "$vmi_line"
}

wait_dv_clone() {
   local vm_num="$1"
   local start="$vm_num"
   local end=$((vm_num + batch_num))
   local timeout=$((batch_num*9)) # on average each dv clone takes 9 seconds
   echo "wait dv clone start=$start, end=$end"
   local current_dv_num=$(count_dv_line "$start" "$end")
   while [[ $current_dv_num -ne $batch_num ]]; do
     if [[ "$timeout" -lt 5 ]]; then
         return 1
     fi
     timeout=$((timeout - 5 ))
     echo "wait dv clone start=$start, end=$end"
     current_dv_num=$(count_dv_line "$start" "$end")
     echo "current completed dv clone: $current_dv_num, timeout: $timeout/$((batch_num*9))"
     sleep 5
   done
   return 0
}

wait_vm_running() {
   local vm_num="$1"
   local timeout="$batch_num" # On average each vmi start in 0.4 seconds, make it 1 to be safe"
   local start=$vm_num
   local end=$((vm_num + batch_num))
   local current_vmi_num=$(count_vmi_line "$start" "$end")
   while [[ "$current_vmi_num" -ne $batch_num ]]; do
      if [[ "$timeout" -lt 5 ]]; then
            return 1
      fi
   current_vmi_num=$(count_vmi_line "$start" "$end")
   echo "current running vmi: $current_vmi_num timeout: $timeout/$batch_num"
   sleep 5
   timeout=$((timeout - 5 ))
   done
   return 0
}


delete_all_vm() {
   oc delete vm --all -n default
}

clean_odf_disk() {
  local node="$1"
  local device_path="$2"
  oc debug node/"$node" -- chroot /host /bin/bash -c \
    "sudo dd if=/dev/zero of=$device_path bs=1M count=100 && \
    echo 'dd command succeeded' || { echo 'dd command failed on node $node'; exit 1; } && \
    sudo wipefs -a $device_path && \
    echo 'wipefs command succeeded' || { echo 'wipefs command failed on node $node'; exit 1; } && \
    sudo rm -rf /mnt/local-storage && \
    echo 'rm command succeeded' || { echo 'rm command failed on node $node'; exit 1; }" 
}

sync_clock() {
   local node="$1"
   oc debug node/"$node" -- chroot /host /bin/bash -c \
     "setenforce 0 && \
      echo 'setenforce to disable selinux succeeded' || { echo 'setenforce to disable selinux failed on node $node'; exit 1; } && \
      chronyc -a makestep && \
      echo 'chronyc cmd succeeded' || { echo 'chronyc failed on node $node'; exit 1; } && \
      setenforce 1 && \
      echo 'setenforce to enable selinux succeeded' || { echo 'setenforce to enable selinux failed on node $node'; exit 1; }"
}

deploy_vm() {
	local start="$1"
	local end="$2"
   local i
	for ((i="$start"; i<$end; i=i+batch_num)); do
		local start_time=$(date +%s)
		batch_create_vm "$i"
		wait_dv_clone "$i"
      status=$?
		local end_time=$(date +%s)
      if [[ $status eq 1 ]]; then
         echo "$i-$((i+batch_num-1)), vm deployment timeout: $((end_time - start_time)), $(date -d "@$start_time" +"%Y-%m-%d %H:%M:%S"), $(date -d "@$end_time" +"%Y-%m-%d %H:%M:%S")" | tee -a "$vm_deployment_path"
      elif [[ $status eq 0 ]]; then
		   echo "batch number $i, completed in $((end_time - start_time))"
         echo "$i-$((i+batch_num-1)), $((end_time - start_time)), $(date -d "@$start_time" +"%Y-%m-%d %H:%M:%S"), $(date -d "@$end_time" +"%Y-%m-%d %H:%M:%S")" | tee -a "$vm_deployment_path"
      fi
	done
}

start_vm() {
	local start="$1"
	local end="$2"
   local i
	for ((i="$start"; i<"$end"; i=i+batch_num)); do
		local start_time=$(date +%s)
		batch_start_vm "$i"
		wait_vm_running "$i"
      status=$?
      local end_time=$(date +%s)
      if [[ $status eq 1 ]]; then
         echo "$i-$((i+batch_num-1)), vmi start timeout: $((end_time - start_time)), $(date -d "@$start_time" +"%Y-%m-%d %H:%M:%S"), $(date -d "@$end_time" +"%Y-%m-%d %H:%M:%S")" | tee -a "$vmi_running_path"
      elif [[ $status eq 0 ]]; then
		   echo "batch number $i, vmi start running in $((end_time - start_time))"
		   echo "$i-$((i+batch_num-1)), $((end_time - start_time)), $(date -d "@$start_time" +"%Y-%m-%d %H:%M:%S"), $(date -d "@$end_time" +"%Y-%m-%d %H:%M:%S")" | tee -a "$vmi_running_path"
      fi
   done
}

