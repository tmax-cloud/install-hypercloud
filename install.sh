#!/bin/bash

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
HYPERCLOUD_API_SERVER_HOME=$SCRIPTDIR/hypercloud-api-server
HYPERCLOUD_SINGLE_OPERATOR_HOME=$SCRIPTDIR/hypercloud-single-operator
HYPERCLOUD_MULTI_OPERATOR_HOME=$SCRIPTDIR/hypercloud-multi-operator
source $SCRIPTDIR/hypercloud.config
KUSTOMIZE_VERSION=${KUSTOMIZE_VERSION:-"v3.8.5"}
YQ_VERSION=${YQ_VERSION:-"v4.4.1"}
set -xe


# Check if certmanager exists
if [ -z "$(kubectl get ns | grep cert-manager | awk '{print $1}')" ]; then
  kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.2.0/cert-manager.yaml
fi

# Check if namespace exists
if [ -z "$(kubectl get ns | grep hypercloud5-system | awk '{print $1}')" ]; then
   kubectl create ns hypercloud5-system
fi

# Install pkg or binary
if ! command -v kustomize 2>/dev/null ; then
  curl -L -O "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2F${KUSTOMIZE_VERSION}/kustomize_${KUSTOMIZE_VERSION}_linux_amd64.tar.gz"
  tar -xzvf "kustomize_${KUSTOMIZE_VERSION}_linux_amd64.tar.gz"
  chmod +x kustomize
  sudo mv kustomize /usr/local/bin/.
  rm "kustomize_${KUSTOMIZE_VERSION}_linux_amd64.tar.gz"
fi

# Install pkg or binary
if ! command -v sshpass 2>/dev/null ; then
  yum install sshpass
fi

if ! command -v yq 2>/dev/null ; then
  wget https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64 -O /usr/bin/yq &&\
  chmod +x /usr/bin/yq
fi

# Install hypercloud-single-server
pushd $HYPERCLOUD_SINGLE_OPERATOR_HOME
  kubectl apply -f  hypercloud-single-operator.yaml
popd

# Install hypercloud-multi-server
#pushd $HYPERCLOUD_MULTI_OPERATOR_HOME
#  kubectl apply -f  hypercloud-multi-operator-v${HPCD_MULTI_VERSION}.yaml
#popd

# Install hypercloud-api-server
# step 1  - create pki and secret
if [ ! -f "$HYPERCLOUD_API_SERVER_HOME/pki/hypercloud-api-server.crt" ] || [ ! -f "$HYPERCLOUD_API_SERVER_HOME/pki/hypercloud-api-server.key" ]; then
pushd $HYPERCLOUD_API_SERVER_HOME/pki
  chmod +x *.sh
  ./generateTls.sh -name=hypercloud-api-server -dns=hypercloud5-api-server-service.hypercloud5-system.svc -dns=hypercloud5-api-server-service.hypercloud5-system.svc.cluster.local 
  if [ -z "$(kubectl get secret hypercloud5-api-server-certs -n hypercloud5-system | awk '{print $1}')" ]; then
    kubectl -n hypercloud5-system create secret generic hypercloud5-api-server-certs \
    --from-file=$HYPERCLOUD_API_SERVER_HOME/pki/hypercloud-api-server.crt \
    --from-file=$HYPERCLOUD_API_SERVER_HOME/pki/hypercloud-api-server.key
  else
    kubectl -n hypercloud5-system delete secret  hypercloud5-api-server-certs
    kubectl -n hypercloud5-system create secret generic hypercloud5-api-server-certs \
    --from-file=$HYPERCLOUD_API_SERVER_HOME/pki/hypercloud-api-server.crt \
    --from-file=$HYPERCLOUD_API_SERVER_HOME/pki/hypercloud-api-server.key
  fi
popd
fi


# step 0  - sed manifests
if [ $REGISTRY != "{REGISTRY}" ]; then
  sed -i 's#tmaxcloudck/hypercloud-api-server#'${REGISTRY}'/tmaxcloudck/hypercloud-api-server#g' ${HYPERCLOUD_API_SERVER_HOME}/04_hypercloud-api-server.yaml
fi
sed -i 's/{HPCD_API_SERVER_VERSION}/b'${HPCD_API_SERVER_VERSION}'/g'  ${HYPERCLOUD_API_SERVER_HOME}/04_hypercloud-api-server.yaml

# step 1  - apply manifests
pushd $HYPERCLOUD_API_SERVER_HOME
  kubectl apply -f  01_init.yaml
  kubectl apply -f  02_mysql-create.yaml
  kubectl apply -f  03_postgres-create.yaml
  kubectl apply -f  04_hypercloud-api-server.yaml
  kubectl apply -f  05_default-role.yaml
popd

#  step 2 - create and apply config
pushd $HYPERCLOUD_API_SERVER_HOME/config
chmod +x *.sh 
  ./gen-audit-config.sh
  ./gen-webhook-config.sh
  cp audit-policy.yaml /etc/kubernetes/pki/
  cp audit-webhook-config /etc/kubernetes/pki/

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

  sshpass -p "$MASTER_NODE_ROOT_PASSWORD" ssh -o StrictHostKeyChecking=no ${MASTER_NODE_ROOT_USER}@"$master"  sudo wget https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64 -O /usr/bin/yq
  sshpass -p "$MASTER_NODE_ROOT_PASSWORD" ssh -o StrictHostKeyChecking=no ${MASTER_NODE_ROOT_USER}@"$master"  sudo chmod +x /usr/bin/yq

  sshpass -p "$MASTER_NODE_ROOT_PASSWORD" scp /etc/kubernetes/pki/audit-policy.yaml ${MASTER_NODE_ROOT_USER}@"$master":/etc/kubernetes/pki/audit-policy.yaml
  sshpass -p "$MASTER_NODE_ROOT_PASSWORD" scp /etc/kubernetes/pki/audit-webhook-config ${MASTER_NODE_ROOT_USER}@"$master":/etc/kubernetes/pki/audit-webhook-config

  sshpass -p "$MASTER_NODE_ROOT_PASSWORD" ssh -o StrictHostKeyChecking=no ${MASTER_NODE_ROOT_USER}@"$master" sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml .
  sshpass -p "$MASTER_NODE_ROOT_PASSWORD" ssh -o StrictHostKeyChecking=no ${MASTER_NODE_ROOT_USER}@"$master" 'sudo yq e '"'"'.spec.containers[0].command += "--audit-webhook-mode=batch"'"'"' -i ./kube-apiserver.yaml'
  sshpass -p "$MASTER_NODE_ROOT_PASSWORD" ssh -o StrictHostKeyChecking=no ${MASTER_NODE_ROOT_USER}@"$master" 'sudo yq e '"'"'.spec.containers[0].command += "--audit-policy-file=/etc/kubernetes/pki/audit-policy.yaml"'"'"' -i ./kube-apiserver.yaml'
  sshpass -p "$MASTER_NODE_ROOT_PASSWORD" ssh -o StrictHostKeyChecking=no ${MASTER_NODE_ROOT_USER}@"$master" 'sudo yq e '"'"'.spec.containers[0].command += "--audit-webhook-config-file=/etc/kubernetes/pki/audit-webhook-config"'"'"' -i ./kube-apiserver.yaml'
  sshpass -p "$MASTER_NODE_ROOT_PASSWORD" ssh -o StrictHostKeyChecking=no ${MASTER_NODE_ROOT_USER}@"$master" 'sudo yq e '"'"'.spec.dnsPolicy += "ClusterFirstWithHostNet"'"'"' -i ./kube-apiserver.yaml'
  sshpass -p "$MASTER_NODE_ROOT_PASSWORD" ssh -o StrictHostKeyChecking=no ${MASTER_NODE_ROOT_USER}@"$master" sudo mv -f ./kube-apiserver.yaml /etc/kubernetes/manifests/kube-apiserver.yaml
done

#  step 6 - check all master is ready
IFS=' ' read -r -a nodes <<< $(kubectl get nodes --selector=node-role.kubernetes.io/master -o jsonpath='{$.items[*].status.conditions[-1].type}')
for (( i=0; i<8; i++ )); do
  j=0;
  for node in "${nodes[@]}"
  do
    if [ $node != Ready ]; then
      sleep 10s
      continue
    else
      j=$((j+1));
    fi

    if [ ${#nodes[@]} == $j  ]; then
      break 2;
    fi
  done
done

