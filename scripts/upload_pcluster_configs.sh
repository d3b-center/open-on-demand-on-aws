# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
#!/bin/bash

aws s3 cp pcluster_head_node.sh s3://$CLUSTER_CONFIG_BUCKET/pcluster_head_node.sh
aws s3 cp pcluster_worker_node.sh s3://$CLUSTER_CONFIG_BUCKET/pcluster_worker_node.sh
aws s3 cp pcluster_worker_node_desktop.sh s3://$CLUSTER_CONFIG_BUCKET/pcluster_worker_node_desktop.sh

aws s3 cp pcluster_head_node_v2.sh s3://$CLUSTER_CONFIG_BUCKET/pcluster_head_node_v2.sh
aws s3 cp pcluster_worker_node_v2.sh s3://$CLUSTER_CONFIG_BUCKET/pcluster_worker_node_v2.sh
aws s3 cp pcluster_worker_node_desktop_v2.sh s3://$CLUSTER_CONFIG_BUCKET/pcluster_worker_node_desktop_v2.sh
