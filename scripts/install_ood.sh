#!/bin/bash
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

DEBIAN_FRONTEND=noninteractive apt install python3-pip apache2 -y -q
# Enable SSL
a2enmod ssl
systemctl restart apache2

wget -O /tmp/ondemand-release-web_3.0.0_all.deb https://apt.osc.edu/ondemand/3.0/ondemand-release-web_3.0.0_all.deb
DEBIAN_FRONTEND=noninteractive apt install /tmp/ondemand-release-web_3.0.0_all.deb
DEBIAN_FRONTEND=noninteractive apt update -yq
DEBIAN_FRONTEND=noninteractive apt install ondemand ondemand-dex krb5-user samba -yq

echo "$(date +%Y%m%d-%H%M) | ood installed" >> /var/log/install.txt
export AD_SECRET=$(aws secretsmanager --region $AWS_REGION get-secret-value --secret-id $AD_SECRET_ID --query SecretString --output text)
export AD_PASSWORD=$(aws secretsmanager --region $AWS_REGION get-secret-value --secret-id $AD_PASSWORD --query SecretString --output text)
export ALB_NAME=${!ALB_DNS_NAME,,} # Need to make it lower case as apache is case sensitive

cat << EOF >> /etc/sssd/sssd.conf
[domain/$DOMAIN_NAME.$TOP_LEVEL_DOMAIN]
cache_credentials = True
debug_level = 0x1ff
default_shell = /bin/bash
fallback_homedir = /shared/home/%u
id_provider = ldap
ldap_auth_disable_tls_never_use_in_production = true
ldap_default_authtok = $AD_PASSWORD
ldap_default_bind_dn = CN=Admin,OU=Users,OU=$DOMAIN_NAME,DC=$DOMAIN_NAME,DC=$TOP_LEVEL_DOMAIN
ldap_id_mapping = True
ldap_referrals = False
ldap_schema = AD
ldap_search_base = DC=$DOMAIN_NAME,DC=$TOP_LEVEL_DOMAIN
ldap_tls_reqcert = never
ldap_uri = ldap://$LDAP_NLB
use_fully_qualified_names = False

[sssd]
config_file_version = 2
services = nss, pam
domains = $DOMAIN_NAME.$TOP_LEVEL_DOMAIN
full_name_format = %1\$s

[nss]
filter_users = nobody,root
filter_groups = nobody,root

[pam]
offline_credentials_expiration = 7
EOF

chown root:root /etc/sssd/sssd.conf
chmod 600 /etc/sssd/sssd.conf
systemctl restart sssd

sed -i "s/#servername: null/servername: $WEBSITE_DOMAIN/" /etc/ood/config/ood_portal.yml

cat << EOF >> /etc/ood/config/ood_portal.yml
ssl:
  - 'SSLCertificateFile "/etc/ssl/private/cert.crt"'
  - 'SSLCertificateKeyFile "/etc/ssl/private/private_key.key"'
EOF

cat << EOF >> /etc/ood/config/ood_portal.yml
dex_uri: /dex
dex:
    ssl: true
    connectors:
        - type: ldap
          id: ldap
          name: LDAP
          config:
            host: $LDAP_NLB
            insecureSkipVerify: false
            insecureNoSSL: true
            bindDN: CN=Admin,OU=Users,OU=$DOMAIN_NAME,DC=$DOMAIN_NAME,DC=$TOP_LEVEL_DOMAIN
            bindPW: $AD_PASSWORD
            userSearch:
              baseDN: dc=$DOMAIN_NAME,dc=$TOP_LEVEL_DOMAIN
              filter: "(objectClass=user)"
              username: name
              idAttr: name
              emailAttr: name
              nameAttr: name
              preferredUsernameAttr: name
# turn on proxy for interactive desktop apps
host_regex: '[^/]+'
node_uri: '/node'
rnode_uri: '/rnode'
EOF

# # Tells PUN to look for home directories in EFS
cat << EOF >> /etc/ood/config/nginx_stage.yml
user_home_dir: '/shared/home/%{user}'
EOF


# Set up directories for clusters and interactive desktops
mkdir -p /etc/ood/config/clusters.d
mkdir -p /etc/ood/config/apps/bc_desktop


# Setup OOD add user; will add local user for AD user if doesn't exist
touch /var/log/add_user.log
chown www-data /var/log/add_user.log
touch /etc/ood/add_user.sh
touch /shared/userlistfile
mkdir -p /shared/home

# Script that we want to use when adding user
cat << EOF >> /etc/ood/add_user.sh
#!/bin/bash
if  id "\$1" &> /dev/null; then
  echo "user \$1 found" >> /var/log/add_user.log
  if [ ! -d "/shared/home/\$1" ] ; then
    echo "user \$1 home folder doesn't exist, create one " >> /var/log/add_user.log
  #  usermod -a -G spack-users \$1
    sudo mkdir -p /shared/home/\$1 >> /var/log/add_user.log
    sudo chown \$1:"Domain Users" /shared/home/\$1 >> /var/log/add_user.log
  #  echo "\$1 $(id -u $1)" >> /shared/userlistfile
    sudo su \$1 -c 'ssh-keygen -t rsa -f ~/.ssh/id_rsa -q -P ""'
    sudo su \$1 -c 'echo "source /etc/bashrc" > ~/.bashrc'
    sudo su \$1 -c 'cat ~/.ssh/id_rsa.pub > ~/.ssh/authorized_keys'
    sudo chmod 600 /shared/home/$USER/.ssh/*
  fi
fi
echo \$1
EOF


echo "user_map_cmd: '/etc/ood/add_user.sh'" >> /etc/ood/config/ood_portal.yml

# Creates a script where we can re-create local users on PCluster nodes.
# Since OOD uses local users, need those same local users with same UID on PCluster nodes
#cat << EOF >> /shared/copy_users.sh
#while read USERNAME USERID
#do
#    # -u to set UID to match what is set on the head node
#    if [ \$(grep -c '^\$USERNAME:' /etc/passwd) -eq 0 ]; then
#        useradd -M -u \$USERID \$USERNAME -d /shared/home/\$USERNAME
#        usermod -a -G spack-users \$USERNAME
#    fi
#done < "/shared/userlistfile"
#EOF

chmod +x /etc/ood/add_user.sh
#chmod +x /shared/copy_users.sh
#chmod o+w /shared/userlistfile

/opt/ood/ood-portal-generator/sbin/update_ood_portal
systemctl enable apache2
systemctl enable ondemand-dex

# install bin overrides so sbatch executes on remote node
pip3 install sh pyyaml
#create sbatch log
touch /var/log/sbatch.log
chmod 666 /var/log/sbatch.log

# Create this bin overrides script on the box: https://osc.github.io/ood-documentation/latest/installation/resource-manager/bin-override-example.html
cat << EOF > /etc/ood/config/sbatch_override.py
#!/bin/python3
from getpass import getuser
from select import select
from sh import ssh, ErrorReturnCode
import logging
import os
import re
import sys
import yaml

'''
An example of a "bin_overrides" replacing Slurm "sbatch" for use with Open OnDemand.
Executes sbatch on the target cluster vs OOD node to get around painful experiences with sbatch + EFA.

Requirements:

- $USER must be able to SSH from web node to submit node without using a password
'''
logging.basicConfig(filename='/var/log/sbatch.log', level=logging.INFO)

USER = os.environ['USER']

def run_remote_sbatch(script,host_name, *argv):
  """
  @brief      SSH and submit the job from the submission node

  @param      script (str)  The script
  @parma      host_name (str) The hostname of the head node on which to execute the script
  @param      argv (list<str>)    The argument vector for sbatch

  @return     output (str) The merged stdout/stderr of the remote sbatch call
  """

  output = None

  try:
    result = ssh(
      '@'.join([USER, host_name]),
      '-oBatchMode=yes',  # ensure that SSH does not hang waiting for a password that will never be sent
      '-oStrictHostKeyChecking=no',
      '/opt/slurm/bin/sbatch',  # the real sbatch on the remote
      *argv,  # any arguments that sbatch should get
      _in=script,  # redirect the script's contents into stdin
      _err_to_out=True  # merge stdout and stderr
    )

    output = result
    logging.info(output)
  except ErrorReturnCode as e:
    output = e
    logging.error(output)
    print(output)
    sys.exit(e.exit_code)

  return output

def load_script():
  """
  @brief      Loads a script from stdin.

  With OOD and Slurm the user's script is read from disk and passed to sbatch via stdin
  https://github.com/OSC/ood_core/blob/5b4d93636e0968be920cf409252292d674cc951d/lib/ood_core/job/adapters/slurm.rb#L138-L148

  @return     script (str) The script content
  """
  # Do not hang waiting for stdin that is not coming
  if not select([sys.stdin], [], [], 0.0)[0]:
    logging.error('No script available on stdin!')
    sys.exit(1)

  return sys.stdin.read()

def get_cluster_host(cluster_name):
  with open(f"/etc/ood/config/clusters.d/{cluster_name}.yml", "r") as stream:
    try:
      config_file=yaml.safe_load(stream)
    except yaml.YAMLError as e:
      logging.error(e)
  return config_file["v2"]["login"]["host"]

def main():
  """
  @brief SSHs from web node to submit node and executes the remote sbatch.
  """
  host_name=get_cluster_host(sys.argv[-1])
  output = run_remote_sbatch(
    load_script(),
    host_name,
    sys.argv[1:]
  )

  print(output)

if __name__ == '__main__':
  main()
EOF

cat << EOF > /etc/ood/config/squeue_override.py
#!/bin/python3
from getpass import getuser
from select import select
from sh import ssh, ErrorReturnCode
import logging
import os
import re
import sys
import yaml

'''
An example of a "bin_overrides" replacing Slurm "squeue" for use with Open OnDemand.
Executes squeue on the target cluster vs OOD node to get around painful experiences with squeue + EFA.

Requirements:

- $USER must be able to SSH from web node to submit node without using a password
'''
logging.basicConfig(filename='/var/log/squeue.log', level=logging.INFO)

USER = os.environ['USER']

def run_remote_squeue(script,host_name, *argv):
  """
  @brief      SSH and submit the job from the submission node

  @param      script (str)  The script
  @parma      host_name (str) The hostname of the head node on which to execute the script
  @param      argv (list<str>)    The argument vector for squeue

  @return     output (str) The merged stdout/stderr of the remote squeue call
  """

  output = None

  try:
    result = ssh(
      '@'.join([USER, host_name]),
      '-oBatchMode=yes',  # ensure that SSH does not hang waiting for a password that will never be sent
      '-oStrictHostKeyChecking=no',
      '/opt/slurm/bin/squeue',  # the real squeue on the remote
      *argv,  # any arguments that squeue should get
      _in=script,  # redirect the script's contents into stdin
      _err_to_out=True  # merge stdout and stderr
    )

    output = result
    logging.info(output)
  except ErrorReturnCode as e:
    output = e
    logging.error(output)
    print(output)
    sys.exit(e.exit_code)

  return output

def load_script():
  """
  @brief      Loads a script from stdin.

  With OOD and Slurm the user's script is read from disk and passed to squeue via stdin
  https://github.com/OSC/ood_core/blob/5b4d93636e0968be920cf409252292d674cc951d/lib/ood_core/job/adapters/slurm.rb#L138-L148

  @return     script (str) The script content
  """
  # Do not hang waiting for stdin that is not coming
  if not select([sys.stdin], [], [], 0.0)[0]:
    logging.error('No script available on stdin!')
    sys.exit(1)

  return sys.stdin.read()

def get_cluster_host(cluster_name):
  with open(f"/etc/ood/config/clusters.d/{cluster_name}.yml", "r") as stream:
    try:
      config_file=yaml.safe_load(stream)
    except yaml.YAMLError as e:
      logging.error(e)
  return config_file["v2"]["login"]["host"]

def main():
  """
  @brief SSHs from web node to submit node and executes the remote squeue.
  """
  host_name=get_cluster_host(sys.argv[-1])
  output = run_remote_squeue(
    load_script(),
    host_name,
    sys.argv[1:]
  )

  print(output)

if __name__ == '__main__':
  main()
EOF

cat << EOF > /etc/ood/config/scancel_override.py
#!/bin/python3
from getpass import getuser
from select import select
from sh import ssh, ErrorReturnCode
import logging
import os
import re
import sys
import yaml

'''
An example of a "bin_overrides" replacing Slurm "scancel" for use with Open OnDemand.
Executes scancel on the target cluster vs OOD node to get around painful experiences with scancel + EFA.

Requirements:

- $USER must be able to SSH from web node to submit node without using a password
'''
logging.basicConfig(filename='/var/log/scancel.log', level=logging.INFO)

USER = os.environ['USER']

def run_remote_scancel(script,host_name, *argv):
  """
  @brief      SSH and submit the job from the submission node

  @param      script (str)  The script
  @parma      host_name (str) The hostname of the head node on which to execute the script
  @param      argv (list<str>)    The argument vector for scancel

  @return     output (str) The merged stdout/stderr of the remote scancel call
  """

  output = None

  try:
    result = ssh(
      '@'.join([USER, host_name]),
      '-oBatchMode=yes',  # ensure that SSH does not hang waiting for a password that will never be sent
      '-oStrictHostKeyChecking=no',
      '/opt/slurm/bin/scancel',  # the real scancel on the remote
      *argv,  # any arguments that scancel should get
      _in=script,  # redirect the script's contents into stdin
      _err_to_out=True  # merge stdout and stderr
    )

    output = result
    logging.info(output)
  except ErrorReturnCode as e:
    output = e
    logging.error(output)
    print(output)
    sys.exit(e.exit_code)

  return output

def load_script():
  """
  @brief      Loads a script from stdin.

  With OOD and Slurm the user's script is read from disk and passed to scancel via stdin
  https://github.com/OSC/ood_core/blob/5b4d93636e0968be920cf409252292d674cc951d/lib/ood_core/job/adapters/slurm.rb#L138-L148

  @return     script (str) The script content
  """
  # Do not hang waiting for stdin that is not coming
  if not select([sys.stdin], [], [], 0.0)[0]:
    logging.error('No script available on stdin!')
    sys.exit(1)

  return sys.stdin.read()

def get_cluster_host(cluster_name):
  with open(f"/etc/ood/config/clusters.d/{cluster_name}.yml", "r") as stream:
    try:
      config_file=yaml.safe_load(stream)
    except yaml.YAMLError as e:
      logging.error(e)
  return config_file["v2"]["login"]["host"]

def main():
  """
  @brief SSHs from web node to submit node and executes the remote scancel.
  """
  host_name=get_cluster_host(sys.argv[-1])
  output = run_remote_scancel(
    load_script(),
    host_name,
    sys.argv[1:]
  )

  print(output)

if __name__ == '__main__':
  main()
EOF

touch /var/log/scancel.log
touch /var/log/squeue.log
touch /var/log/sbatch.log

chmod 666 /var/log/scancel.log
chmod 666 /var/log/squeue.log
chmod 666 /var/log/sbatch.log

chmod +x /etc/ood/config/sbatch_override.py
chmod +x /etc/ood/config/squeue_override.py
chmod +x /etc/ood/config/scancel_override.py
#Edit sudoers to allow www-data to add users
echo "www-data  ALL=NOPASSWD: /sbin/adduser" >> /etc/sudoers
echo "www-data  ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

mkdir -p /etc/ood/config/apps/bc_desktop/submit/

cat << EOF >> /etc/ood/config/apps/bc_desktop/${PCLUSTER_NAME}.yml
---
title: "$PCLUSTER_NAME Desktop"
cluster: "${PCLUSTER_NAME}"
submit: "submit/${PCLUSTER_NAME}-submit.yml.erb"
attributes:
  desktop: xfce
  bc_queue: desktop
  bc_account: null
EOF

# Setup for interactive desktops with PCluster

cat << EOF >> /etc/ood/config/apps/bc_desktop/submit/${PCLUSTER_NAME}-submit.yml.erb
batch_connect:
  template: vnc
  websockify_cmd: "/usr/local/bin/websockify"
  set_host: "host=\$(hostname | awk '{print \$1}').${PCLUSTER_NAME}.pcluster"
cluster: ${PCLUSTER_NAME}
EOF
shutdown -r now