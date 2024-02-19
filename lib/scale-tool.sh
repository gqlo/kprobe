# file paths
vm_template="/root/h-bench/template/cnv/vm.yaml"
vm_deployment_path="/root/cnv/data/batch_completed_time.csv"
vmi_running_path="/root/cnv/data/vmi_running_time.csv"

# batch create 100 VMs at a time
batch_create_vm() {
   vm_num="$1"
   for ((i="$vm_num"; i<vm_num+100; i++)); do
      sed "s/placeholder/$i/g" "$vm_template" | oc create -f - &
   done
}

batch_start_vm() {
   vm_num="$1"
   for ((i="$vm_num"; i<vm_num+100; i++)); do
      virtctl start rhel9-$i &
   done
}

count_dv_line() {
   local start="$1"
   local end="$2"
   dv_line=$(oc get dv -n default | grep "-" | sed 's/^[^-]*-//'| awk -v start="$start" -v end="$end" '$1 >= start && $1 <= end' | grep "100.0%" | wc -l)
   echo "$dv_line"
}

count_vmi_line() {
   local start="$1"
   local end="$2"
   vmi_line=$(oc get vmi -n default | grep "-" | sed 's/^[^-]*-//'| awk -v start="$start" -v end="$end" '$1 >= start && $1 <= end' | grep "Running" | wc -l)
   echo "$vmi_line"
}

wait_dv_clone() {
   vm_num="$1"
   local start=$vm_num
   local end=$((vm_num + 100))
   current_dv_num=$(count_dv_line "$start" "$end")
   while [[ $current_dv_num -ne 100 ]]; do
     current_dv_num=$(count_dv_line "$start" "$end")
     echo "current completed dv clone: $current_dv_num"
     sleep 5
   done
}

wait_vm_running() {
   vm_num="$1"
   timeout=360
   local start=$vm_num
   local end=$((vm_num + 100))
   current_vmi_num=$(count_vmi_line "$start" "$end")
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

deploy_vm() {
	local start="$1"
	local end="$2"
	for ((i="$start"; i<=$end; i=i+100)); do
		local start_time=$(date +%s)
		batch_create_vm "$i"
		wait_dv_clone "$i"
		local end_time=$(date +%s)
		echo "batch number $n, completed in $((end_time - start_time))"
		echo "$n-$((n+99)), $((end_time - start_time)), $start_time, $end_time" | tee -a "$vm_deployment_path"
	done
}

start_vm() {
	local start="$1"
	local end="$2"
	for ((i="$start"; i<=$end; i=i+100)); do
		local start_time=$(date +%s)
		batch_start_vm "$i"
		wait_vm_running "$i"
		local end_time=$(date +%s)
		echo "batch number $n, vmi start running in $((end_time - start_time))"
		echo "$n-$((n+99)), $((end_time - start_time)), $start_time, $end_time" | tee -a "$vmi_running_path"
}
