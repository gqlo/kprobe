#! /bin/sh

for i in {1..40}; do 
    fio --name=test-$i --filename=test-$i --ioengine=libaio --size=4G --rw=write --bs=4096k --direct=1 --numjobs=1 --iodepth=256 --output-format=json+ --output=test-$i.json &
done
