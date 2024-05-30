# kprobe
kprobe (also known as Kubernetes probe) is a command-line tool to streamline the benchmarking tasks within Kubernetes environment. It allows you to automate some customized benchmarking tasks involves but not limited to Hypershift, KubeVirt and ceph distributed storage. The end goal is to probe the cluster and gain some performance insight.
<!-- markdown-toc start - Don't edit this section. Run M-x markdown-toc-generate-toc again -->
**Table of Contents**

- [kprobe](#kprobe)
    - [Hypershift](#hypershift)
    - [KubeVirt](#KubeVirt)
    - [Ceph](#Ceph)
<!-- markdown-toc end -->

## Hypershift
- Launch HyperShift/KubeVirt hosted clusters with given configuration file.
- Parallel or sequential creation of hosted clusters with given number
- Mesaure the timings of different phases during host cluster creation
- Extract raw promethus metrics in JSON format.
- Extract time series data points as csv files for plotting in Google sheet.

## KubeVirt
- large scale VM deployment
## Ceph
- ceph utilities
