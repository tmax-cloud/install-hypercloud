#!/bin/bash

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
HYPERCLOUD_API_SERVER_HOME=$SCRIPTDIR/hypercloud-api-server
HYPERCLOUD_SINGLE_OPERATOR_HOME=$SCRIPTDIR/hypercloud-single-operator
HYPERCLOUD_MULTI_OPERATOR_HOME=$SCRIPTDIR/hypercloud-multi-operator
source $SCRIPTDIR/hypercloud.config
set -x

# step 1 - delete hypercloud-api-server and involved secret
pushd $HYPERCLOUD_API_SERVER_HOME
  timeout 5m kubectl delete -f 04_default-role.yaml
  suc=`echo $?`
  if [ $suc != 0 ]; then
    echo "Failed to delete 04_default-role.yaml"
  fi
  timeout 5m kubectl delete -f 03_hypercloud-api-server.yaml
  suc=`echo $?`
  if [ $suc != 0 ]; then
    echo "Failed to delete 03_hypercloud-api-server.yaml"
  fi
  timeout 5m kubectl delete -f 02_postgres-create.yaml
  suc=`echo $?`
  if [ $suc != 0 ]; then
    echo "Failed to delete 02_postgres-create.yaml"
  fi
  timeout 5m kubectl delete -f 01_init.yaml
  suc=`echo $?`
  if [ $suc != 0 ]; then
    echo "Failed to delete 01_init.yaml"
  fi
  timeout 5m kubectl -n hypercloud5-system delete secret hypercloud5-api-server-certs
  suc=`echo $?`
  if [ $suc != 0 ]; then
    echo "Failed to delete secret"
  fi
popd

# step 2 - delete hypercloud-multi-operator
pushd $HYPERCLOUD_MULTI_OPERATOR_HOME
  timeout 5m kubectl delete -f hypercloud-multi-operator-v${HPCD_MULTI_OPERATOR_VERSION}.yaml
  suc=`echo $?`
  if [ $suc != 0 ]; then
    echo "Failed to delete hypercloud-multi-operator"
  fi
popd

# step 3 - delete hypercloud-single-operator
pushd $HYPERCLOUD_SINGLE_OPERATOR_HOME
  timeout 5m kubectl delete -f hypercloud-single-operator.yaml
  suc=`echo $?`
  if [ $suc != 0 ]; then
    echo "Failed to delete hypercloud-single-operator"
  fi
popd

# step 4 - delete hypercloud5-system namespace
timeout 5m kubectl delete namespace hypercloud5-system
suc=`echo $?`
if [ $suc != 0 ]; then
  echo "Failed to delete namespace hypercloud5-system"
fi

# step 5 - delete audit configuration
cp /etc/kubernetes/manifests/kube-apiserver.yaml .
yq eval 'del(.spec.dnsPolicy)' -i kube-apiserver.yaml
yq eval 'del(.spec.containers[0].command[] | select(. == "--audit-webhook-mode*") )' -i kube-apiserver.yaml
yq eval 'del(.spec.containers[0].command[] | select(. == "--audit-policy-file*") )' -i kube-apiserver.yaml
yq eval 'del(.spec.containers[0].command[] | select(. == "--audit-webhook-config-file*") )' -i kube-apiserver.yaml
mv -f ./kube-apiserver.yaml /etc/kubernetes/manifests/kube-apiserver.yaml

pushd $HYPERCLOUD_API_SERVER_HOME/config
  rm /etc/kubernetes/pki/audit-policy.yaml
  rm /etc/kubernetes/pki/audit-webhook-config
  kubectl delete -f webhook-configuration.yaml
popd

#  step 6 - delete audit configuration of all k8s-apiserver master nodes
IFS=' ' read -r -a masters <<< $(kubectl get nodes --selector=node-role.kubernetes.io/master -o jsonpath='{$.items[*].status.addresses[?(@.type=="InternalIP")].address}')
for master in "${masters[@]}"
do
  if [ $master == $MAIN_MASTER_IP ]; then
    continue
  fi

  sshpass -p "$MASTER_NODE_ROOT_PASSWORD" ssh -o StrictHostKeyChecking=no ${MASTER_NODE_ROOT_USER}@"$master" sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml .
  sshpass -p "$MASTER_NODE_ROOT_PASSWORD" ssh -o StrictHostKeyChecking=no ${MASTER_NODE_ROOT_USER}@"$master" 'sudo yq eval '"'"'del(.spec.dnsPolicy)'"'"' -i kube-apiserver.yaml'
  sshpass -p "$MASTER_NODE_ROOT_PASSWORD" ssh -o StrictHostKeyChecking=no ${MASTER_NODE_ROOT_USER}@"$master" 'sudo yq eval '"'"'del(.spec.containers[0].command[] | select(. == "--audit-webhook-mode*") )'"'"' -i kube-apiserver.yaml'
  sshpass -p "$MASTER_NODE_ROOT_PASSWORD" ssh -o StrictHostKeyChecking=no ${MASTER_NODE_ROOT_USER}@"$master" 'sudo yq eval '"'"'del(.spec.containers[0].command[] | select(. == "--audit-policy-file*") )'"'"' -i kube-apiserver.yaml'
  sshpass -p "$MASTER_NODE_ROOT_PASSWORD" ssh -o StrictHostKeyChecking=no ${MASTER_NODE_ROOT_USER}@"$master" 'sudo yq eval '"'"'del(.spec.containers[0].command[] | select(. == "--audit-webhook-config-file*") )'"'"' -i kube-apiserver.yaml'

  sshpass -p "$MASTER_NODE_ROOT_PASSWORD" ssh -o StrictHostKeyChecking=no ${MASTER_NODE_ROOT_USER}@"$master" sudo mv -f ./kube-apiserver.yaml /etc/kubernetes/manifests/kube-apiserver.yaml

  sshpass -p "$MASTER_NODE_ROOT_PASSWORD" ssh -o StrictHostKeyChecking=no ${MASTER_NODE_ROOT_USER}@"$master" sudo rm /etc/kubernetes/pki/audit-policy.yaml /etc/kubernetes/pki/audit-webhook-config
done
