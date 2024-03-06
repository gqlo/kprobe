# batch create 100 VMs at a time
batch_create_vm() {
   local vm_num="$1"
   local i
   for ((i="$vm_num"; i<vm_num+deployment_batch_num; i++)); do
      sed "s/placeholder/$i/g" "$vm_template" | oc create -f - &
   done
}
batch_start_vm() {
   local vm_num="$1"
   local i
   for ((i="$vm_num"; i<vm_num+deployment_batch_num; i++)); do
      virtctl start win11-$i &
   done
}

batch_migrate_vmi() {
   local vm_num="$1"
   local i
   for ((i="$vm_num"; i<vm_num+migration_batch_num; i++)); do
      sed "s/placeholder/$i/g" "$vmi_migration_template" | oc create -f - &
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
   local end=$((vm_num + deployment_batch_num))
   local timeout=$((deployment_batch_num*18)) # on average each dv clone takes 9 seconds
   echo "wait dv clone start=$start, end=$end"
   local current_dv_num=$(count_dv_line "$start" "$end")
   while [[ $current_dv_num -ne $deployment_batch_num ]]; do
      if [[ "$timeout" -lt 5 ]]; then
          return 1
      fi
      timeout=$((timeout - 5 ))
      echo "wait dv clone start=$start, end=$end"
      current_dv_num=$(count_dv_line "$start" "$end")
      echo "current completed dv clone: $current_dv_num, timeout: $timeout/$((deployment_batch_num*18))"
      sleep 5
   done
   return 0
}

wait_vm_running() {
   local vm_num="$1"
   local timeout="$deployment_batch_num" # On average each vmi start in 0.4 seconds, make it 1 to be safe"
   local start=$vm_num
   local end=$((vm_num + deployment_batch_num))
   local current_vmi_num=$(count_vmi_line "$start" "$end")
   while [[ "$current_vmi_num" -ne $deployment_batch_num ]]; do
      if [[ "$timeout" -lt 5 ]]; then
            return 1
      fi
   current_vmi_num=$(count_vmi_line "$start" "$end")
   echo "current running vmi: $current_vmi_num timeout: $timeout/$deployment_batch_num"
   sleep 5
   timeout=$((timeout - 5 ))
   done
   return 0
}

wait_vmi_migrate() {
   local target_vmi_num="$1"
   local timeout="$((migration_batch_num*36))"  
   local current_migrated_vmi=$(oc get virtualmachineinstancemigration | grep "Succeeded" | wc -l)
   while [[ "$current_migrated_vmi" -ne $target_vmi_num ]]; do
      if [[ "$timeout" -lt 5 ]]; then
            return 1
      fi
      current_migrated_vmi=$(oc get virtualmachineinstancemigration | grep "Succeeded" | wc -l)
      echo "current migrated vmi: $current_migrated_vmi/$target_vmi_num timeout: $timeout/$((migration_batch_num*36))"
      sleep 5
      timeout=$((timeout - 5 ))
   done
   return 0
}

get_dv_timestamps() {
   local dvs="$1"
   for dv in $dvs; do
      dv_creation_ts=$(oc get dv $dv -o jsonpath='{.metadata.creationTimestamp}')
      dv_bound_ts=$(oc get dv $dv -o jsonpath='{.status.conditions[?(@.type=="Bound")].lastTransitionTime}')
      dv_creation_unix=$(date -d "$dv_creation_ts" +"%s")
      dv_bound_unix=$(date -d "$dv_bound_ts" +"%s")
      deployment_time=$((dv_bound_unix - dv_creation_unix))
      echo "$dv, $deployment_time" | tee -a "$vm_deployment_ts" 
   done
}

get_vmi_boot_time() {
   local vmis="$1"
   for vm in $vmis; do
      Pending=$(oc get vmi $vm -o jsonpath='{.status.phaseTransitionTimestamps[?(@.phase=="Pending")].phaseTransitionTimestamp}')
      Scheduled=$(oc get vmi $vm -o jsonpath='{.status.phaseTransitionTimestamps[?(@.phase=="Scheduled")].phaseTransitionTimestamp}')
      Pending_unix_ts=$(date -d "$Pending" +"%s")
      Scheduled_unix_ts=$(date -d "$Scheduled" +"%s")
      if [[ $vm =~ [Ww][Ii][Nn] ]]; then
         timestamp_string=$(virtctl ssh Administrator@$vm --command "type C:\Users\Administrator\timestamp.txt")
      else
         timestamp_string=$(virtctl ssh root@$vm --command "cat /root/timestamp.txt" | sed -n 2p)
      fi
      boot_ts="${timestamp_string#*,}"
      boot_unix="${timestamp_string%%,*}"
      boot_unix_ts=$(date -d "$boot_ts" +"%s")
      boot_time=$((boot_unix_ts - Scheduled_unix_ts))
      schedule_time=$((Scheduled_unix_ts - Pending_unix_ts))
      total_time=$((boot_unix_ts - Pending_unix_ts))
      echo "$vm, $schedule_time, $boot_time, $total_time" | tee -a  "$vmi_boot_ts"
   done
}

cal_max_boot_time() {
  local boot_ts_text_file="$1" 
  local end=$(wc -l < $boot_ts_text_file)
  echo $end
  local i
  for ((i=1; i<=end; i=i+deployment_batch_num)); do
     local max_val=$(sed -n "${i},$((${i}+${deployment_batch_num}))p" $boot_ts_text_file | awk -F ',' '{print $NF}' | sort -n | tail -1)
     local batch_name=$(sed -n "${i}p" $boot_ts_text_file | awk -F ',' '{print $1}')
     echo "$batch_name-$((i+deployment_batch_num-1)), $max_val" | tee -a $max_boot_time
  done
}

delete_vm() {
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
     "systemctl restart chronyd && \
      setenforce 0 && \
      echo 'setenforce to disable selinux succeeded' || { echo 'setenforce to disable selinux failed on node $node'; exit 1; } && \
      chronyc -a makestep && \
      echo 'chronyc cmd succeeded' || { echo 'chronyc failed on node $node'; exit 1; } && \
      setenforce 1 && \
      echo 'setenforce to enable selinux succeeded' || { echo 'setenforce to enable selinux failed on node $node'; exit 1; }"
}

get_vm_type() {
   local yaml_file_path="$1"
   local vm_type=$(sed -n '/-placeholder/{s/.*: \(.*\)-placeholder.*/\1/;p;q;}' $yaml_file_path)
   echo "$vm_type"
}

deploy_vm() {
	local start="$1"
	local end="$2"
   local i
   local vm_type=$(get_vm_type $vm_template) 
	for ((i="$start"; i<$end; i=i+deployment_batch_num)); do
		local start_time=$(date +%s)
		batch_create_vm "$i"
		wait_dv_clone "$i"
      status=$?
		local end_time=$(date +%s)
      if [[ $status -eq 1 ]]; then
         echo "$vm_type-$i-$((i+deployment_batch_num-1)), vm deployment timeout: $((end_time - start_time)), $(date -d "@$start_time" +"%Y-%m-%d %H:%M:%S"), $(date -d "@$end_time" +"%Y-%m-%d %H:%M:%S")" | tee -a "$batch_deployment_ts"
      elif [[ $status -eq 0 ]]; then
		   echo "batch number $i, completed in $((end_time - start_time))"
         echo "$vm_type-$i-$((i+deployment_batch_num-1)), $((end_time - start_time)), $(date -d "@$start_time" +"%Y-%m-%d %H:%M:%S"), $(date -d "@$end_time" +"%Y-%m-%d %H:%M:%S")" | tee -a "$batch_deployment_ts"
      fi
   sleep 30
	done
}

start_vm() {
	local start="$1"
	local end="$2"
   local i
	for ((i="$start"; i<"$end"; i=i+deployment_batch_num)); do
		local start_time=$(date +%s)
		batch_start_vm "$i"
		wait_vm_running "$i"
      status=$?
      local end_time=$(date +%s)
      if [[ $status -eq 1 ]]; then
         echo "$i-$((i+deployment_batch_num-1)), vmi start timeout: $((end_time - start_time)), $(date -d "@$start_time" +"%Y-%m-%d %H:%M:%S"), $(date -d "@$end_time" +"%Y-%m-%d %H:%M:%S")" | tee -a "$vmi_running_ts"
      elif [[ $status -eq 0 ]]; then
		   echo "batch number $i, vmi start running in $((end_time - start_time))"
		   echo "win11-$i-$((i+deployment_batch_num-1)), $((end_time - start_time)), $(date -d "@$start_time" +"%Y-%m-%d %H:%M:%S"), $(date -d "@$end_time" +"%Y-%m-%d %H:%M:%S")" | tee -a "$vmi_running_ts"
      fi
   sleep 30
   done
}

live_migrate_vm() {
	local start="$1"
	local end="$2"
   local i
   local vm_type=$(get_vm_type $vmi_migration_template)
	for ((i="$start"; i<"$end"; i=i+migration_batch_num)); do
		local start_time=$(date +%s)
		batch_migrate_vmi "$i"
		wait_vmi_migrate "$((i+migration_batch_num-1))"
      status=$?
      local end_time=$(date +%s)
      if [[ $status -eq 1 ]]; then
         echo "$vm_type-$i-$((i+migration_batch_num-1)), vmi migration timeout: $((end_time - start_time)), $(date -d "@$start_time" +"%Y-%m-%d %H:%M:%S"), $(date -d "@$end_time" +"%Y-%m-%d %H:%M:%S")" | tee -a "$vmi_migration_ts"
      elif [[ $status -eq 0 ]]; then
		   echo "batch number $i-$((i+migration_batch_num-1)), vmi migrated in $((end_time - start_time))"
		   echo "$vm_type-$i-$((i+migration_batch_num-1)), $((end_time - start_time)), $(date -d "@$start_time" +"%Y-%m-%d %H:%M:%S"), $(date -d "@$end_time" +"%Y-%m-%d %H:%M:%S")" | tee -a "$vmi_migration_ts"
      fi
   sleep 30
   done
}

# file paths
vm_template="/root/h-bench/template/cnv/win-vm.yaml"
vmi_migration_template="/root/h-bench/template/cnv/vmi-migration.yaml"
batch_deployment_ts="/root/cnv/data/batch_completed_time.csv"
vm_deployment_ts="/root/cnv/data/deployment_time_ts.csv"
vmi_boot_ts="/root/cnv/data/vmi_boot_ts.csv"
vmi_running_ts="/root/cnv/data/vmi_running_time.csv"
vmi_migration_ts="/root/cnv/data/vmi_migration_time.csv"
max_boot_time="/root/cnv/data/max_boot_time.csv"
deployment_batch_num=100
migration_batch_num=100

live_migrate_vm 1 6001
