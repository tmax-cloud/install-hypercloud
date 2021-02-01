#!/bin/bash

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
HYPERCLOUD_API_SERVER_HOME=$SCRIPTDIR/hypercloud-api-server
source $SCRIPTDIR/hypercloud.config
KUSTOMIZE_VERSION=${KUSTOMIZE_VERSION:-"v3.8.5"}

set -xe
# private 

# Install hypercloud-single-server
# Install hypercloud-multi-server
# Install hypercloud-api-server


# Install pkg or binary
if ! command -v kustomize 2>/dev/null ; then
  curl -L -O "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2F${KUSTOMIZE_VERSION}/kustomize_${KUSTOMIZE_VERSION}_linux_amd64.tar.gz"
  tar -xzvf "kustomize_${KUSTOMIZE_VERSION}_linux_amd64.tar.gz"
  chmod +x kustomize
  sudo mv kustomize /usr/local/bin/.
  rm "kustomize_${KUSTOMIZE_VERSION}_linux_amd64.tar.gz"
fi

if ! command -v kustomize 2>/dev/null ; then
  wget https://github.com/mikefarah/yq/releases/download/4.4.1/yq_linux_amd64 -O /usr/bin/yq &&\
  chmod +x /usr/bin/yq 
fi

# step 1  - initialize
#if [ "hypercloud5-system" != "$(kubectl get ns | grep hypercloud5-system | awk '{print $1}')" ]; then
if [ -z "$(kubectl get ns | grep hypercloud5-system | awk '{print $1}')" ]; then
   kubectl create ns hypercloud5-system
fi

# step 1  - create pki and secret
if [[ -f "$HYPERCLOUD_API_SERVER_HOME/pki/hypercloud-api-server.crt"]] || [[ -f "$HYPERCLOUD_API_SERVER_HOME/pki/hypercloud-api-server.key" ]]; then
pushd $HYPERCLOUD_API_SERVER_HOME
  chmod +x *.sh
  ./generateTls.sh -name=hypercloud-api-server -dns=hypercloud5-api-server-service.hypercloud5-system.svc -dns=hypercloud5-api-server-service.hypercloud5-system.svc.cluster.local 
  kubectl -n hypercloud5-system create secret generic hypercloud5-api-server-certs \
  --from-file=$HYPERCLOUD_API_SERVER_HOME/pki/hypercloud-api-server.crt \
  --from-file=$HYPERCLOUD_API_SERVER_HOME/pki/hypercloud-api-server.key
popd
fi


# step 0  - sed manifests
sed -i 's/tmaxcloudck\/hypercloud-api-server/'${REGISTRY}'\/tmaxcloudck\/hypercloud-api-server/g' ${HYPERCLOUD_API_SERVER_HOME}/04_hypercloud-api-server.yaml
sed -i 's/{HPCD_API_SERVER_VERSION}/b'${HPCD_API_SERVER_VERSION}'/g'  ${HYPERCLOUD_API_SERVER_HOME}/04_hypercloud-api-server.yaml

# step 1  - apply manifests
pushd $HYPERCLOUD_API_SERVER_HOME
  kubectl apply -f  01_init.yaml
  kubectl apply -f  02_mysql-create.yaml
  kubectl apply -f  03_postgres-create.yaml
  kubectl apply -f  04_hypercloud-api-server.yaml
  kubectl apply -f  05_default-role-create.yaml
popd

#  step 2 - create and apply config
pushd $HYPERCLOUD_API_SERVER_HOME/config
chmod +x *.sh 
  ./gen-audit-config.sh
  ./gen-webhook-config.sh
  mv audit-policy.yaml /etc/kubernetes/pki/
  mv audit-webhook-config /etc/kubernetes/pki/

  kubectl apply -f webhook-configuration.yaml
popd

#  step 4 - modify kubernetes api-server manifest
cp /etc/kubernetes/manifests/kube-apiserver.yaml .
yq e '.spec.containers[0].command += "--audit-webhook-mode=batch"' -i ./kube-apiserver.yaml
yq e '.spec.containers[0].command += "--audit-policy-file=/etc/kubernetes/pki/audit-policy.yaml"' -i ./kube-apiserver.yaml
yq e '.spec.containers[0].command += "--audit-webhook-config-file=/etc/kubernetes/pki/audit-webhook-config"' -i ./kube-apiserver.yaml
yq e '.spec.containers[0].command += "--audit-webhook-config-file=/etc/kubernetes/pki/audit-webhook-config"' -i ./kube-apiserver.yaml
yq e '.spec.dnsPolicy += "ClusterFirstWithHostNet"' -i kube-apiserver.yaml
mv -f ./kube-apiserver.yaml /etc/kubernetes/manifests/kube-apiserver.yaml


#  step 5 - copy audit config files to all k8s-apiserver and modify k8s apiserver manifest
IFS=' ' read -r -a masters <<< $(kubectl get nodes --selector=node-role.kubernetes.io/master -o jsonpath='{$.items[*].status.addresses[?(@.type=="InternalIP")].address}')
for master in "${masters[@]}"
do
  if [ $master == $MAIN_MASTER_IP ]; then
    continue
  fi 

  sshpass -p "$MASTER_NODE_ROOT_PASSWORD" ssh -o StrictHostKeyChecking=no ${MASTER_NODE_ROOT_USER}@"$master"  wget https://github.com/mikefarah/yq/releases/download/4.4.1/yq_linux_amd64 -O /usr/bin/yq && chmod +x /usr/bin/yq
  
  sshpass -p "$MASTER_NODE_ROOT_PASSWORD" scp /etc/kubernetes/pki/audit-policy.yaml ${MASTER_NODE_ROOT_USER}@"$master":/etc/kubernetes/pki/audit-policy.yaml
  sshpass -p "$MASTER_NODE_ROOT_PASSWORD" scp /etc/kubernetes/pki/audit-webhook-config ${MASTER_NODE_ROOT_USER}@"$master":/etc/kubernetes/pki/audit-webhook-config
  
  sshpass -p "$MASTER_NODE_ROOT_PASSWORD" ssh -o StrictHostKeyChecking=no ${MASTER_NODE_ROOT_USER}@"$master" cp /etc/kubernetes/manifests/kube-apiserver.yaml .
  sshpass -p "$MASTER_NODE_ROOT_PASSWORD" ssh -o StrictHostKeyChecking=no ${MASTER_NODE_ROOT_USER}@"$master" yq e '.spec.containers[0].command += "--audit-webhook-mode=batch"' -i ./kube-apiserver.yaml
  sshpass -p "$MASTER_NODE_ROOT_PASSWORD" ssh -o StrictHostKeyChecking=no ${MASTER_NODE_ROOT_USER}@"$master" yq e '.spec.containers[0].command += "--audit-policy-file=/etc/kubernetes/pki/audit-policy.yaml"' -i ./kube-apiserver.yaml
  sshpass -p "$MASTER_NODE_ROOT_PASSWORD" ssh -o StrictHostKeyChecking=no ${MASTER_NODE_ROOT_USER}@"$master" yq e '.spec.containers[0].command += "--audit-webhook-config-file=/etc/kubernetes/pki/audit-webhook-config"' -i ./kube-apiserver.yaml
  sshpass -p "$MASTER_NODE_ROOT_PASSWORD" ssh -o StrictHostKeyChecking=no ${MASTER_NODE_ROOT_USER}@"$master" yq e '.spec.dnsPolicy += "ClusterFirstWithHostNet"' -i kube-apiserver.yaml
  sshpass -p "$MASTER_NODE_ROOT_PASSWORD" ssh -o StrictHostKeyChecking=no ${MASTER_NODE_ROOT_USER}@"$master" mv -f ./kube-apiserver.yaml /etc/kubernetes/manifests/kube-apiserver.yaml
done

#  step 6 - check all master is ready

