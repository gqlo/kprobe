# file paths
vm_template="/root/h-bench/template/cnv/vm.yaml"
vm_deployment_path="/root/cnv/data/batch_completed_time.csv"
vmi_running_path="/root/cnv/data/vmi_running_time.csv"

# batch create 100 VMs at a time
batch_create_vm() {
   local vm_num="$1"
   for ((i="$vm_num"; i<vm_num+100; i++)); do
      sed "s/placeholder/$i/g" "$vm_template" | oc create -f - &
   done
}

batch_start_vm() {
   local vm_num="$1"
   for ((i="$vm_num"; i<vm_num+100; i++)); do
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
   local start=$vm_num
   local end=$((vm_num + 100))
   local current_dv_num=$(count_dv_line "$start" "$end")
   while [[ $current_dv_num -ne 100 ]]; do
     current_dv_num=$(count_dv_line "$start" "$end")
     echo "current completed dv clone: $current_dv_num"
     sleep 5
   done
}

wait_vm_running() {
   local vm_num="$1"
   local timeout=360
   local start=$vm_num
   local end=$((vm_num + 100))
   local current_vmi_num=$(count_vmi_line "$start" "$end")
   while [[ "$current_vmi_num" -ne 100 ]]; do
      if [[ "$timeout" -lt 10 ]]; then
            break
      fi
   current_vmi_num=$(count_vmi_line "$start" "$end")
   echo "current running vmi: $current_vmi_num"
   sleep 5
   timeout=$((timeout - 5 ))
   done
}


delete_all_vm() {
   oc delete vm --all -n default
}

clean_odf_disk() {
  node_list="$1"
  device_path="$2"
  for node in "$node_list"; do
    oc debug node/"$node" -- chroot /host /bin/bash -c \
    "sudo dd if=/dev/zero of=$device_path bs=1M count=100 && \
    echo 'dd command succeeded' || { echo 'dd command failed on node $node'; exit 1; } && \
    sudo wipefs -a $device_path && \
    echo 'wipefs command succeeded' || { echo 'wipefs command failed on node $node'; exit 1; } && \
    sudo rm -rf /mnt/local-storage && \
    echo 'rm command succeeded' || { echo 'rm command failed on node $node'; exit 1; }"
  done

}

deploy_vm() {
	local start="$1"
	local end="$2"
	for ((i="$start"; i<$end; i=i+100)); do
		local start_time=$(date +%s)
		batch_create_vm "$i"
		wait_dv_clone "$i"
		local end_time=$(date +%s)
		echo "batch number $i, completed in $((end_time - start_time))"
		echo "$i-$((i+99)), $((end_time - start_time)), $start_time, $end_time" | tee -a "$vm_deployment_path"
	done
}

start_vm() {
	local start="$1"
	local end="$2"
	for ((i="$start"; i<"$end"; i=i+100)); do
		local start_time=$(date +%s)
		batch_start_vm "$i"
		wait_vm_running "$i"
		local end_time=$(date +%s)
		echo "batch number $i, vmi start running in $((end_time - start_time))"
		echo "$i-$((i+99)), $((end_time - start_time)), $start_time, $end_time" | tee -a "$vmi_running_path"
   done
}


