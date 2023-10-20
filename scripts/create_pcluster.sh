OOD_STACK_NAME="${1}"
CLUSTER_NAME="${2}"

if [ ! -d "../venv" ]; then
    echo "Setting up a virtualenv folder"
    virtualenv ../venv
    source ../venv/bin/activate
    pip3 install aws-parallelcluster
else
    source ../venv/bin/activate
fi

./create_sample_pcluster_config.sh "$OOD_STACK_NAME"
pcluster create-cluster -c ../pcluster-config.yml -n "${CLUSTER_NAME}"
