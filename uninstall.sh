#!/bin/bash

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
HYPERCLOUD_API_SERVER_HOME=$SCRIPTDIR/hypercloud-api-server
HYPERCLOUD_SINGLE_OPERATOR_HOME=$SCRIPTDIR/hypercloud-single-operator
HYPERCLOUD_MULTI_OPERATOR_HOME=$SCRIPTDIR/hypercloud-multi-operator
HYPERCLOUD_MULTI_AGENT_HOME=$SCRIPTDIR/hypercloud-multi-agent

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

# step 2.5 - delete hypercloud-multi-agent
pushd $HYPERCLOUD_MULTI_AGENT_HOME
  timeout 5m kubectl delete -f 03_federate-deployment.yaml
  suc=`echo $?`
  if [ $suc != 0 ]; then
    echo "Failed to delete hypercloud-multi-agent"
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
sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml .
sudo yq eval 'del(.spec.dnsPolicy)' -i kube-apiserver.yaml
sudo yq eval 'del(.spec.containers[0].command[] | select(. == "--audit-webhook-mode*") )' -i kube-apiserver.yaml
sudo yq eval 'del(.spec.containers[0].command[] | select(. == "--audit-policy-file*") )' -i kube-apiserver.yaml
sudo yq eval 'del(.spec.containers[0].command[] | select(. == "--audit-webhook-config-file*") )' -i kube-apiserver.yaml
sudo mv -f ./kube-apiserver.yaml /etc/kubernetes/manifests/kube-apiserver.yaml

pushd $HYPERCLOUD_API_SERVER_HOME/config
  sudo rm /etc/kubernetes/pki/audit-policy.yaml
  sudo rm /etc/kubernetes/pki/audit-webhook-config
  kubectl delete -f webhook-configuration.yaml
popd

sleep 30s

#  step 6 - delete audit configuration of all k8s-apiserver master nodes
for master in "${SUB_MASTER_IP[@]}"
do
  if [ $master == "$MAIN_MASTER_IP" ]; then
    continue
  fi

  sudo sshpass -p "${MASTER_NODE_ROOT_PASSWORD[i]}" ssh -o StrictHostKeyChecking=no ${MASTER_NODE_ROOT_USER[i]}@"$master" sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml .
  sudo sshpass -p "${MASTER_NODE_ROOT_PASSWORD[i]}" ssh -o StrictHostKeyChecking=no ${MASTER_NODE_ROOT_USER[i]}@"$master" 'sudo yq eval '"'"'del(.spec.dnsPolicy)'"'"' -i kube-apiserver.yaml'
  sudo sshpass -p "${MASTER_NODE_ROOT_PASSWORD[i]}" ssh -o StrictHostKeyChecking=no ${MASTER_NODE_ROOT_USER[i]}@"$master" 'sudo yq eval '"'"'del(.spec.containers[0].command[] | select(. == "--audit-webhook-mode*") )'"'"' -i kube-apiserver.yaml'
  sudo sshpass -p "${MASTER_NODE_ROOT_PASSWORD[i]}" ssh -o StrictHostKeyChecking=no ${MASTER_NODE_ROOT_USER[i]}@"$master" 'sudo yq eval '"'"'del(.spec.containers[0].command[] | select(. == "--audit-policy-file*") )'"'"' -i kube-apiserver.yaml'
  sudo sshpass -p "${MASTER_NODE_ROOT_PASSWORD[i]}" ssh -o StrictHostKeyChecking=no ${MASTER_NODE_ROOT_USER[i]}@"$master" 'sudo yq eval '"'"'del(.spec.containers[0].command[] | select(. == "--audit-webhook-config-file*") )'"'"' -i kube-apiserver.yaml'

  sudo sshpass -p "${MASTER_NODE_ROOT_PASSWORD[i]}" ssh -o StrictHostKeyChecking=no ${MASTER_NODE_ROOT_USER[i]}@"$master" sudo mv -f ./kube-apiserver.yaml /etc/kubernetes/manifests/kube-apiserver.yaml

  sudo sshpass -p "${MASTER_NODE_ROOT_PASSWORD[i]}" ssh -o StrictHostKeyChecking=no ${MASTER_NODE_ROOT_USER[i]}@"$master" sudo rm /etc/kubernetes/pki/audit-policy.yaml /etc/kubernetes/pki/audit-webhook-config
done
sleep 30s
