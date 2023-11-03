# Handoff notes

Abandon all hope ye who enter. Just kidding it's not that bad.

The architecture diagram is in the README, so I won't cover it again. It's deployed in the sandbox account in us-east-1. Open OnDemand submits jobs to the PCluster, which is specified mostly in the file `/etc/ood/config/clusters.d/{cluster_name}.yml`. There is a lot in this file that enables the interactive desktops. There is customization done in `/etc/ood/config/apps/bc_desktop/imaging-cluster.yml` that simplifies the parameter selction on the launch screen (desktop type, queue name, etc).`/etc/ood/config/apps/bc_desktop/submit/imaging-cluster-submit.yml.erb` has config that is required to set up interactive desktops, especially the `set_host` field which sets the FQDN which is required since the EC2 instances don't join the AD DNS domain.

When spinning up a PCluster, the head node comes up and downloads the script `pcluster_head_node.sh` from S3 (`imaging-ood-clusterconfigbucket-1avadnljbv4nr`) and runs it. The worker nodes do the same for `pcluster_worker_node.sh`, although the desktop nodes use `pcluster_worker_node_desktop.sh` which is where most of the changes will go for tailoring the desktops to the Imaging team. 

### Debugging
If you have questions about Open Ondemand, they have a very helpful [Discourse](https://discourse.openondemand.org/) server where they're very responsive (<15 mins usually).

If they seem stumped or it seems more related to the Cloudformation setup, you can email Jianjun at `jianjx@amazon.com` or reach out to Satinder. 