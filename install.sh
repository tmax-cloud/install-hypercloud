#!/bin/bash

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
HYPERCLOUD_API_SERVER_HOME=$SCRIPTDIR/hypercloud-api-server
HYPERCLOUD_SINGLE_OPERATOR_HOME=$SCRIPTDIR/hypercloud-single-operator
HYPERCLOUD_MULTI_OPERATOR_HOME=$SCRIPTDIR/hypercloud-multi-operator
source $SCRIPTDIR/hypercloud.config
KUSTOMIZE_VERSION=${KUSTOMIZE_VERSION:-"v3.8.5"}
YQ_VERSION=${YQ_VERSION:-"v4.5.0"}
set -xe


# Check if certmanager exists
if [ -z "$(kubectl get ns | grep cert-manager | awk '{print $1}')" ]; then
  kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.2.0/cert-manager.yaml
  sudo timeout 5m kubectl -n cert-manager rollout status deployment/cert-manager
  sudo timeout 5m kubectl -n cert-manager rollout status deployment/cert-manager-cainjector
  sudo timeout 5m kubectl -n cert-manager rollout status deployment/cert-manager-webhook
fi

# Check if namespace exists
if [ -z "$(kubectl get ns | grep hypercloud5-system | awk '{print $1}')" ]; then
   kubectl create ns hypercloud5-system
fi

# Install pkg or binary
if ! command -v sshpass 2>/dev/null ; then
  sudo yum install -y sshpass
  sudo chmod +x /usr/local/bin/sshpass
fi

if ! command -v yq 2>/dev/null ; then
  sudo yum install -y yq
  sudo chmod +x /usr/local/bin/yq
fi

# Install pkg or binary
if ! command -v kustomize 2>/dev/null ; then
  sudo yum install -y kustomize
  sudo chmod +x /usr/local/bin/kustomize
fi

# Install hypercloud-single-server
pushd $HYPERCLOUD_SINGLE_OPERATOR_HOME
  if [ $REGISTRY != "{REGISTRY}" ]; then
    sudo sed -i 's#tmaxcloudck/hypercloud-single-operator#'${REGISTRY}'/tmaxcloudck/hypercloud-single-operator#g' hypercloud-single-operator-v${HPCD_SINGLE_OPERATOR_VERSION}.yaml
    sudo sed -i 's#gcr.io/kubebuilder/kube-rbac-proxy#'${REGISTRY}'/gcr.io/kubebuilder/kube-rbac-proxy#g' hypercloud-single-operator-v${HPCD_SINGLE_OPERATOR_VERSION}.yaml
  fi
  kubectl apply -f  hypercloud-single-operator-v${HPCD_SINGLE_OPERATOR_VERSION}.yaml
popd

#Install hypercloud-multi-server
if [ $HPCD_MODE == "multi" ]; then
  pushd $HYPERCLOUD_MULTI_OPERATOR_HOME
  if [ $REGISTRY != "{REGISTRY}" ]; then
    sudo sed -i 's#tmaxcloudck/hypercloud-multi-operator#'${REGISTRY}'/tmaxcloudck/hypercloud-multi-operator#g' hypercloud-multi-operator-v${HPCD_MULTI_OPERATOR_VERSION}.yaml
    sudo sed -i 's#gcr.io/kubebuilder/kube-rbac-proxy#'${REGISTRY}'/gcr.io/kubebuilder/kube-rbac-proxy#g' hypercloud-multi-operator-v${HPCD_MULTI_OPERATOR_VERSION}.yaml
  fi
    kubectl apply -f  hypercloud-multi-operator-v${HPCD_MULTI_OPERATOR_VERSION}.yaml
  popd
fi

# Install hypercloud-api-server
# step 1  - create pki and secret
if [ ! -f "$HYPERCLOUD_API_SERVER_HOME/pki/hypercloud-api-server.crt" ] || [ ! -f "$HYPERCLOUD_API_SERVER_HOME/pki/hypercloud-api-server.key" ]; then
pushd $HYPERCLOUD_API_SERVER_HOME/pki
  sudo chmod +x *.sh
  sudo touch ~/.rnd
  sudo ./generateTls.sh -name=hypercloud-api-server -dns=hypercloud5-api-server-service.hypercloud5-system.svc -dns=hypercloud5-api-server-service.hypercloud5-system.svc.cluster.local
  sudo chmod +777 hypercloud-api-server.*
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

if [ -z "$(kubectl get cm -n hypercloud5-system | grep html-config | awk '{print $1}')" ]; then
  sudo chmod +777 $HYPERCLOUD_API_SERVER_HOME/html/invite.html
  kubectl create configmap html-config --from-file=$HYPERCLOUD_API_SERVER_HOME/html/invite.html -n hypercloud5-system
fi

if [ -z "$(kubectl get secret -n hypercloud5-system | grep hypercloud-kafka-secret | awk '{print $1}')"]; then
  sudo cp /etc/kubernetes/pki/hypercloud-root-ca.crt $HYPERCLOUD_API_SERVER_HOME/pki/
  sudo chmod +777 $HYPERCLOUD_API_SERVER_HOME/pki/hypercloud-root-ca.crt
  sudo chmod +777 $HYPERCLOUD_API_SERVER_HOME/pki/hypercloud-api-server.*
  kubectl -n hypercloud5-system create secret generic hypercloud-kafka-secret \
  --from-file=$HYPERCLOUD_API_SERVER_HOME/pki/hypercloud-root-ca.crt \
  --from-file=$HYPERCLOUD_API_SERVER_HOME/pki/hypercloud-api-server.crt \
  --from-file=$HYPERCLOUD_API_SERVER_HOME/pki/hypercloud-api-server.key
fi

# step 2  - sed manifests
if [ $REGISTRY != "{REGISTRY}" ]; then
  sudo sed -i 's#tmaxcloudck/hypercloud-api-server#'${REGISTRY}'/tmaxcloudck/hypercloud-api-server#g' ${HYPERCLOUD_API_SERVER_HOME}/03_hypercloud-api-server.yaml
  sudo sed -i 's#tmaxcloudck/postgres-cron#'${REGISTRY}'/tmaxcloudck/postgres-cron#g' ${HYPERCLOUD_API_SERVER_HOME}/02_postgres-create.yaml
fi
if [ $KAFKA1_ADDR != "{KAFKA1_ADDR}" ] && [ $KAFKA2_ADDR != "{KAFKA2_ADDR}" ] && [ $KAFKA3_ADDR != "{KAFKA3_ADDR}" ]; then
  sudo sed -i 's/{KAFKA1_ADDR}/'${KAFKA1_ADDR}'/g'  ${HYPERCLOUD_API_SERVER_HOME}/03_hypercloud-api-server.yaml
  sudo sed -i 's/{KAFKA2_ADDR}/'${KAFKA2_ADDR}'/g'  ${HYPERCLOUD_API_SERVER_HOME}/03_hypercloud-api-server.yaml
  sudo sed -i 's/{KAFKA3_ADDR}/'${KAFKA3_ADDR}'/g'  ${HYPERCLOUD_API_SERVER_HOME}/03_hypercloud-api-server.yaml
else
  sudo sed -i 's/{KAFKA1_ADDR}/'DNS'/g'  ${HYPERCLOUD_API_SERVER_HOME}/03_hypercloud-api-server.yaml
  sudo sed -i 's/{KAFKA2_ADDR}/'DNS'/g'  ${HYPERCLOUD_API_SERVER_HOME}/03_hypercloud-api-server.yaml
  sudo sed -i 's/{KAFKA3_ADDR}/'DNS'/g'  ${HYPERCLOUD_API_SERVER_HOME}/03_hypercloud-api-server.yaml
fi
sudo sed -i 's/{HPCD_API_SERVER_VERSION}/b'${HPCD_API_SERVER_VERSION}'/g'  ${HYPERCLOUD_API_SERVER_HOME}/03_hypercloud-api-server.yaml
sudo sed -i 's/{HPCD_MODE}/'${HPCD_MODE}'/g'  ${HYPERCLOUD_API_SERVER_HOME}/03_hypercloud-api-server.yaml
sudo sed -i 's/{HPCD_POSTGRES_VERSION}/b'${HPCD_POSTGRES_VERSION}'/g'  ${HYPERCLOUD_API_SERVER_HOME}/02_postgres-create.yaml
sudo sed -i 's/{INVITATION_TOKEN_EXPIRED_DATE}/'${INVITATION_TOKEN_EXPIRED_DATE}'/g'  ${HYPERCLOUD_API_SERVER_HOME}/02_postgres-create.yaml
sudo sed -i 's/{INVITATION_TOKEN_EXPIRED_DATE}/'${INVITATION_TOKEN_EXPIRED_DATE}'/g'  ${HYPERCLOUD_API_SERVER_HOME}/03_hypercloud-api-server.yaml

# step 3  - apply manifests
pushd $HYPERCLOUD_API_SERVER_HOME
  kubectl apply -f  01_init.yaml
  kubectl apply -f  02_postgres-create.yaml
  kubectl apply -f  03_hypercloud-api-server.yaml
  kubectl apply -f  04_default-role.yaml
popd

#  step 4 - create and apply config
pushd $HYPERCLOUD_API_SERVER_HOME/config
  sudo chmod +x *.sh 
  sudo ./gen-audit-config.sh
  sudo ./gen-webhook-config.sh
  sudo cp audit-policy.yaml /etc/kubernetes/pki/
  sudo cp audit-webhook-config /etc/kubernetes/pki/

  kubectl apply -f webhook-configuration.yaml
popd
#  step 5 - modify kubernetes api-server manifest
sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml .
sudo yq e '.spec.containers[0].command += "--audit-webhook-mode=batch"' -i ./kube-apiserver.yaml
sudo yq e '.spec.containers[0].command += "--audit-policy-file=/etc/kubernetes/pki/audit-policy.yaml"' -i ./kube-apiserver.yaml
sudo yq e '.spec.containers[0].command += "--audit-webhook-config-file=/etc/kubernetes/pki/audit-webhook-config"' -i ./kube-apiserver.yaml
sudo yq e 'del(.spec.dnsPolicy)' -i kube-apiserver.yaml
sudo yq e '.spec.dnsPolicy += "ClusterFirstWithHostNet"' -i kube-apiserver.yaml

# get hyperauth URL from --oidc-issuer-url and sed to version.config
KA_YAML=`sudo yq e '.spec.containers[0].command' ./kube-apiserver.yaml`
HYPERAUTH_URL=`echo "${KA_YAML#*--oidc-issuer-url=}" | tr -d '\12' | cut -d '-' -f1`
sudo sed -i 's@{HYPERAUTH_URL}@'${HYPERAUTH_URL}'@g'  ${HYPERCLOUD_API_SERVER_HOME}/01_init.yaml
sudo mv -f ./kube-apiserver.yaml /etc/kubernetes/manifests/kube-apiserver.yaml

#  step 6 - copy audit config files to all k8s-apiserver and modify k8s apiserver manifest
i=0
sudo cp /etc/kubernetes/pki/audit-policy.yaml .
sudo cp /etc/kubernetes/pki/audit-webhook-config .
sudo cp /etc/kubernetes/pki/hypercloud-root-ca.crt .
for master in "${SUB_MASTER_IP[@]}"
do
  if [ $master == "$MAIN_MASTER_IP" ]; then
    continue
  fi
  sudo sshpass -p "${MASTER_NODE_ROOT_PASSWORD[i]}" ssh -o StrictHostKeyChecking=no ${MASTER_NODE_ROOT_USER[i]}@"$master"  sudo yum install -y yq
  sudo sshpass -p "${MASTER_NODE_ROOT_PASSWORD[i]}" ssh -o StrictHostKeyChecking=no ${MASTER_NODE_ROOT_USER[i]}@"$master"  sudo chmod +x /usr/bin/yq

  sudo sshpass -p "${MASTER_NODE_ROOT_PASSWORD[i]}" scp audit-policy.yaml ${MASTER_NODE_ROOT_USER[i]}@"$master":/etc/kubernetes/pki/audit-policy.yaml
  sudo sshpass -p "${MASTER_NODE_ROOT_PASSWORD[i]}" scp audit-webhook-config ${MASTER_NODE_ROOT_USER[i]}@"$master":/etc/kubernetes/pki/audit-webhook-config
  sudo sshpass -p "${MASTER_NODE_ROOT_PASSWORD[i]}" scp hypercloud-root-ca.crt ${MASTER_NODE_ROOT_USER[i]}@"$master":/etc/kubernetes/pki/hypercloud-root-ca.crt

  sudo sshpass -p "${MASTER_NODE_ROOT_PASSWORD[i]}" ssh -o StrictHostKeyChecking=no ${MASTER_NODE_ROOT_USER[i]}@"$master" sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml .
  sudo sshpass -p "${MASTER_NODE_ROOT_PASSWORD[i]}" ssh -o StrictHostKeyChecking=no ${MASTER_NODE_ROOT_USER[i]}@"$master" 'sudo yq e '"'"'.spec.containers[0].command += "--audit-webhook-mode=batch"'"'"' -i ./kube-apiserver.yaml'
  sudo sshpass -p "${MASTER_NODE_ROOT_PASSWORD[i]}" ssh -o StrictHostKeyChecking=no ${MASTER_NODE_ROOT_USER[i]}@"$master" 'sudo yq e '"'"'.spec.containers[0].command += "--audit-policy-file=/etc/kubernetes/pki/audit-policy.yaml"'"'"' -i ./kube-apiserver.yaml'
  sudo sshpass -p "${MASTER_NODE_ROOT_PASSWORD[i]}" ssh -o StrictHostKeyChecking=no ${MASTER_NODE_ROOT_USER[i]}@"$master" 'sudo yq e '"'"'.spec.containers[0].command += "--audit-webhook-config-file=/etc/kubernetes/pki/audit-webhook-config"'"'"' -i ./kube-apiserver.yaml'
  sudo sshpass -p "${MASTER_NODE_ROOT_PASSWORD[i]}" ssh -o StrictHostKeyChecking=no ${MASTER_NODE_ROOT_USER[i]}@"$master" 'sudo yq e '"'"'.spec.dnsPolicy += "ClusterFirstWithHostNet"'"'"' -i ./kube-apiserver.yaml'
  sudo sshpass -p "${MASTER_NODE_ROOT_PASSWORD[i]}" ssh -o StrictHostKeyChecking=no ${MASTER_NODE_ROOT_USER[i]}@"$master" sudo mv -f ./kube-apiserver.yaml /etc/kubernetes/manifests/kube-apiserver.yaml

  i=$((i+1))
done
rm -f audit-policy.yaml audit-webhook-config hypercloud-root-ca.crt

sleep 30s
#  step 7 - check all master is ready
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

