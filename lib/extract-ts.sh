#! /bin/bash

vmis=$(oc get vmi | awk 'NR>1 {print $1}')

echo "vm, schedule_time, boot_time, total" | tee -a boot_time.csv

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
    echo "$vm, $schedule_time, $boot_time, $total_time" | tee -a  boot_time.csv
done




