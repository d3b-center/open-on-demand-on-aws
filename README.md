# Open OnDemand on AWS with Parallel Cluster

This reference architecture provides a set of templates for deploying [Open OnDemand (OOD)](https://openondemand.org/) with [AWS CloudFormation](https://aws.amazon.com/cloudformation/) and integration points for [AWS Parallel Cluster](https://aws.amazon.com/hpc/parallelcluster/).

The main branch is for Open OnDemand v 3.0.0 

## D3B Getting started

1. Create the Cloudformation stack with all appropriate parameters. Currently this is done via the UI. For convenience, specify the option to not rollback on failure, as you may need to retry the deployment if the Active Directory resource fails (which seemed common). 
2. Run the script `create_pcluster.sh` in the `scripts` directory like so: ```
./create_pcluster.sh {CFN stack name} {Cluster name from CFN parameters}```
3. After the PCluster CFN is completed, run the script `associate_fsx_data_repo.sh {ParallelCluster CFN stack name}` to mount the Imaging team S3 bucket to the FSX share.
4. When everything is created, you can log in at the domain you specified in the parameters, with the user `admin` and the password in the `ADAdministratorSecret` in the CFN outputs.

## Architecture

![architecture](images/architecture.png)

The primary components of the solution are:

1. Application load balancer as the entry point to your OOD portal.
1. An Auto Scaling Group for the OOD Portal.
1. A Microsoft ManagedAD Directory
1. A Network Load Balancer (NLB) to provide a single point of connectivity to Microsoft ManagedAD
1. An Elastic File System (EFS) share for user home directories
1. An Aurora MySQL database to store Slurm Accounting data
1. Automation via Event Bridge to automatically register and deregister Parallel Cluster HPC Clusters with OOD

## Prerequisites

This solution was tested with PCluster version 3.7.0. 

1. Route53 domain for your OOD portal

## Deployment 🚀

1. Launch the stack in your AWS account by clicking on one of the below regions:

| Region           | Launch                                                                                                                                                                                                                                                                                                                           |
|------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Ohio (us-east-2) | [![Launch](https://samdengler.github.io/cloudformation-launch-stack-button-svg/images/us-east-2.svg)](https://us-east-2.console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/create/review?stackName=open-ondemand&templateURL=https://aws-hpc-workshops.s3.amazonaws.com/openondemand.yml) |
| N. Virginia (us-east-1) | [![Launch](https://samdengler.github.io/cloudformation-launch-stack-button-svg/images/us-east-1.svg)](https://us-east-1.console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/create/review?stackName=open-ondemand&templateURL=https://aws-hpc-workshops.s3.amazonaws.com/openondemand.yml) |
| Ireland (eu-west-1) | [![Launch](https://samdengler.github.io/cloudformation-launch-stack-button-svg/images/eu-west-1.svg)](https://eu-west-1.console.aws.amazon.com/cloudformation/home?region=eu-west-1#/stacks/create/review?stackName=open-ondemand&templateURL=https://aws-hpc-workshops.s3.amazonaws.com/openondemand.yml) |
| Frankfurt (eu-central-1) | [![Launch](https://samdengler.github.io/cloudformation-launch-stack-button-svg/images/eu-central-1.svg)](https://eu-central-1.console.aws.amazon.com/cloudformation/home?region=eu-central-1#/stacks/create/review?stackName=open-ondemand&templateURL=https://aws-hpc-workshops.s3.amazonaws.com/openondemand.yml) |

<details>
    <summary>More Regions (Click to expand)</summary>

| Region           | Launch                                                                                                                                                                                                                                                                                                                           |
|------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Oregon (us-west-2) | [![Launch](https://samdengler.github.io/cloudformation-launch-stack-button-svg/images/us-west-2.svg)](https://us-west-2.console.aws.amazon.com/cloudformation/home?region=us-west-2#/stacks/create/review?stackName=open-ondemand&templateURL=https://aws-hpc-workshops.s3.amazonaws.com/openondemand.yml) |
| California (us-west-1) | [![Launch](https://samdengler.github.io/cloudformation-launch-stack-button-svg/images/us-west-1.svg)](https://us-west-1.console.aws.amazon.com/cloudformation/home?region=us-west-1#/stacks/create/review?stackName=open-ondemand&templateURL=https://aws-hpc-workshops.s3.amazonaws.com/openondemand.yml) |
| London (eu-west-2) | [![Launch](https://samdengler.github.io/cloudformation-launch-stack-button-svg/images/eu-west-2.svg)](https://eu-west-2.console.aws.amazon.com/cloudformation/home?region=eu-west-2#/stacks/create/review?stackName=open-ondemand&templateURL=https://aws-hpc-workshops.s3.amazonaws.com/openondemand.yml) |
| Paris (eu-west-3) | [![Launch](https://samdengler.github.io/cloudformation-launch-stack-button-svg/images/eu-west-3.svg)](https://eu-west-3.console.aws.amazon.com/cloudformation/home?region=eu-west-3#/stacks/create/review?stackName=open-ondemand&templateURL=https://aws-hpc-workshops.s3.amazonaws.com/openondemand.yml) |
| Stockholm (eu-north-1) | [![Launch](https://samdengler.github.io/cloudformation-launch-stack-button-svg/images/eu-north-1.svg)](https://eu-north-1.console.aws.amazon.com/cloudformation/home?region=eu-north-1#/stacks/create/review?stackName=open-ondemand&templateURL=https://aws-hpc-workshops.s3.amazonaws.com/openondemand.yml) |
| Canada (ca-central-1) | [![Launch](https://samdengler.github.io/cloudformation-launch-stack-button-svg/images/ca-central-1.svg)](https://ca-central-1.console.aws.amazon.com/cloudformation/home?region=ca-central-1#/stacks/create/review?stackName=open-ondemand&templateURL=https://aws-hpc-workshops.s3.amazonaws.com/openondemand.yml) |
| Tokyo (ap-northeast-1) | [![Launch](https://samdengler.github.io/cloudformation-launch-stack-button-svg/images/ap-northeast-1.svg)](https://ap-northeast-1.console.aws.amazon.com/cloudformation/home?region=ap-northeast-1#/stacks/create/review?stackName=open-ondemand&templateURL=https://aws-hpc-workshops.s3.amazonaws.com/openondemand.yml) |
| Seoul (ap-northeast-2) | [![Launch](https://samdengler.github.io/cloudformation-launch-stack-button-svg/images/ap-northeast-2.svg)](https://ap-northeast-2.console.aws.amazon.com/cloudformation/home?region=ap-northeast-2#/stacks/create/review?stackName=open-ondemand&templateURL=https://aws-hpc-workshops.s3.amazonaws.com/openondemand.yml) |
| Mumbai (ap-south-1) | [![Launch](https://samdengler.github.io/cloudformation-launch-stack-button-svg/images/ap-south-1.svg)](https://ap-south-1.console.aws.amazon.com/cloudformation/home?region=ap-south-1#/stacks/create/review?stackName=open-ondemand&templateURL=https://aws-hpc-workshops.s3.amazonaws.com/openondemand.yml) |
| Singapore (ap-southeast-1) | [![Launch](https://samdengler.github.io/cloudformation-launch-stack-button-svg/images/ap-southeast-1.svg)](https://ap-southeast-1.console.aws.amazon.com/cloudformation/home?region=ap-southeast-1#/stacks/create/review?stackName=open-ondemand&templateURL=https://aws-hpc-workshops.s3.amazonaws.com/openondemand.yml) |
| Sydney (ap-southeast-2) | [![Launch](https://samdengler.github.io/cloudformation-launch-stack-button-svg/images/ap-southeast-2.svg)](https://ap-southeast-2.console.aws.amazon.com/cloudformation/home?region=ap-southeast-2#/stacks/create/review?stackName=open-ondemand&templateURL=https://aws-hpc-workshops.s3.amazonaws.com/openondemand.yml) |
</details>

Once deployed, you should be able to navigate to the URL you set up as a CloudFormation parameter and log into your Open OnDemand portal. You can use the username `Admin` and retrieve the default password from Secrets Manager. The correct secret can be identified in the output of the Open OnDemand CloudFormation template via the entry with the key `ADAdministratorSecretArn`.

### Deploying an integrated Parallel Cluster HPC Cluster

The OOD solution is built so that a Parallel Cluster HPC Cluster can be created and automatically registered with the portal.

In your Parallel Cluster config, you must set the following values:

1. HeadNode:
    1. SubnetId: PrivateSubnet1 from OOD Stack Output
    1. AdditionalScurityGroups: HeadNodeSecurityGroup from CloudFormation Outputs
    1. AdditionalIAMPolicies: HeadNodeIAMPolicyArn from CloudFormation Outputs
    1. OnNodeConfigured
        1. Script: CloudFormation Output for the ClusterConfigBucket; in the format `s3://$ClusterConfigBucket/pcluster_head_node.sh`
        1. Args: Open OnDemand CloudFormation stack name
1. SlurmQueues:
    1. SubnetId: PrivateSubnet1 from OOD Stack Output
    1. AdditionalScurityGroups: ComputeNodeSecurityGroup from CloudFormation Outputs
    1. AdditionalIAMPolicies: ComputeNodeIAMPolicyArn from CloudFormation Outputs
    1. OnNodeConfigured
        1. Script: CloudFormation Output for the ClusterConfigBucket; in the format `s3://$ClusterConfigBucket/pcluster_worker_node.sh`
        1. Args: Open OnDemand CloudFormation stack name

### Enabling Interactive Desktops

You can enable interactive clusters on the Portal server by following the directions [here](https://osc.github.io/ood-documentation/latest/enable-desktops/add-cluster.html).

In addition to the above steps, you must update `/etc/resolv.conf` on the Portal instance to include the Parallel Cluster Domain (`ClusterName.pcluster`) in the search configuration. `resolv.conf` will look similar to the example below. The cluster name, in this case was `democluster`.

Example resolv.confg:
```
# Generated by NetworkManager
search ec2.internal democluster.pcluster
nameserver 10.0.0.2
```

This requires you to have a compute queue with `pcluster_worker_node_desktop.sh` as your `OnNodeConfigured` script.

## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This library is licensed under the MIT-0 License. See the LICENSE file.
