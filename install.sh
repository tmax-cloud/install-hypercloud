#!/bin/bash

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
HYPERCLOUD_API_SERVER_HOME=$SCRIPTDIR/hypercloud-api-server
HYPERCLOUD_SINGLE_OPERATOR_HOME=$SCRIPTDIR/hypercloud-single-operator
HYPERCLOUD_MULTI_OPERATOR_HOME=$SCRIPTDIR/hypercloud-multi-operator
#HYPERCLOUD_MULTI_AGENT_HOME=$SCRIPTDIR/hypercloud-multi-agent
source $SCRIPTDIR/hypercloud.config
KUSTOMIZE_VERSION=${KUSTOMIZE_VERSION:-"v3.8.5"}
YQ_VERSION=${YQ_VERSION:-"v4.5.0"}
INGRESS_DNSURL="hypercloud5-api-server-service.hypercloud5-system.svc/audit"
INGRESS_IPADDR=$(kubectl get svc ingress-nginx-shared-controller -n ingress-nginx-shared -o jsonpath='{.status.loadBalancer.ingress[0:].ip}')
INGRESS_SVCURL="hypercloud5-api-server-service."${INGRESS_IPADDR}".nip.io"
KA_YAML=`sudo yq e '.spec.containers[0].command' /etc/kubernetes/manifests/kube-apiserver.yaml`
HYPERAUTH_URL=`echo "${KA_YAML#*--oidc-issuer-url=}" | tr -d '\12' | cut -d '-' -f1`
set -xe

# Check if certmanager exists
#if [ -z "$(kubectl get ns | grep cert-manager | awk '{print $1}')" ]; then
#  kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.2.0/cert-manager.yaml
#  sudo timeout 5m kubectl -n cert-manager rollout status deployment/cert-manager
#  sudo timeout 5m kubectl -n cert-manager rollout status deployment/cert-manager-cainjector
#  sudo timeout 5m kubectl -n cert-manager rollout status deployment/cert-manager-webhook
#fi

# Create hypercloud5-system namespace
kubectl apply -f $HYPERCLOUD_API_SERVER_HOME/00_namespace.yaml

# Install hypercloud-single-server
pushd $HYPERCLOUD_SINGLE_OPERATOR_HOME
  if [ $REGISTRY != "{REGISTRY}" ]; then
    sudo sed -i 's#tmaxcloudck/hypercloud-single-operator#'${REGISTRY}'/tmaxcloudck/hypercloud-single-operator#g' hypercloud-single-operator-v${HPCD_SINGLE_OPERATOR_VERSION}.yaml
    sudo sed -i 's#gcr.io/kubebuilder/kube-rbac-proxy#'${REGISTRY}'/gcr.io/kubebuilder/kube-rbac-proxy#g' hypercloud-single-operator-v${HPCD_SINGLE_OPERATOR_VERSION}.yaml
  fi
  sudo sed -i 's/--zap-log-level=info/'--zap-log-level=${SINGLE_OPERATOR_LOG_LEVEL}'/g' hypercloud-single-operator-v${HPCD_SINGLE_OPERATOR_VERSION}.yaml
  kubectl apply -f  hypercloud-single-operator-v${HPCD_SINGLE_OPERATOR_VERSION}.yaml
  if [ -e "key-mapping/hypercloud-single-operator-crd-v${HPCD_SINGLE_OPERATOR_VERSION}.yaml" ]; then
    kubectl apply -f  key-mapping/hypercloud-single-operator-crd-v${HPCD_SINGLE_OPERATOR_VERSION}.yaml
  fi
popd

# Install hypercloud-api-server
# step 1  - create configmap and secret
if [ -z "$(kubectl get cm -n hypercloud5-system | grep html-config | awk '{print $1}')" ]; then
  sudo chmod +777 $HYPERCLOUD_API_SERVER_HOME/html/cluster-invitation.html
  kubectl create configmap html-config --from-file=$HYPERCLOUD_API_SERVER_HOME/html/cluster-invitation.html -n hypercloud5-system
fi

if [ -z "$(kubectl get secret -n hypercloud5-system | grep hypercloud-kafka-secret | awk '{print $1}')"]; then
  pushd $HYPERCLOUD_API_SERVER_HOME
    kubectl apply -f  kafka-secret.yaml
  popd
fi

# step 2  - sed manifests
if [ $REGISTRY != "{REGISTRY}" ]; then
  sudo sed -i 's#tmaxcloudck/hypercloud-api-server#'${REGISTRY}'/tmaxcloudck/hypercloud-api-server#g' ${HYPERCLOUD_API_SERVER_HOME}/03_hypercloud-api-server.yaml
  sudo sed -i 's#tmaxcloudck/timescaledb-cron#'${REGISTRY}'/tmaxcloudck/timescaledb-cron#g' ${HYPERCLOUD_API_SERVER_HOME}/02_timescaledb-create.yaml
fi
sudo sed -i 's/{HPCD_API_SERVER_VERSION}/b'${HPCD_API_SERVER_VERSION}'/g'  ${HYPERCLOUD_API_SERVER_HOME}/03_hypercloud-api-server.yaml
sudo sed -i 's/{HPCD_MODE}/'${HPCD_MODE}'/g'  ${HYPERCLOUD_API_SERVER_HOME}/03_hypercloud-api-server.yaml
sudo sed -i 's/{HPCD_TIMESCALEDB_VERSION}/b'${HPCD_TIMESCALEDB_VERSION}'/g'  ${HYPERCLOUD_API_SERVER_HOME}/02_timescaledb-create.yaml
sudo sed -i 's/{INVITATION_TOKEN_EXPIRED_DATE}/'${INVITATION_TOKEN_EXPIRED_DATE}'/g'  ${HYPERCLOUD_API_SERVER_HOME}/02_timescaledb-create.yaml
sudo sed -i 's/{INVITATION_TOKEN_EXPIRED_DATE}/'${INVITATION_TOKEN_EXPIRED_DATE}'/g'  ${HYPERCLOUD_API_SERVER_HOME}/03_hypercloud-api-server.yaml
sudo sed -i 's/{KAFKA_ENABLED}/'${KAFKA_ENABLED}'/g' ${HYPERCLOUD_API_SERVER_HOME}/03_hypercloud-api-server.yaml
sudo sed -i 's/{KAFKA_GROUP_ID}/'hypercloud-api-server-$HOSTNAME-$(($RANDOM%100))'/g' ${HYPERCLOUD_API_SERVER_HOME}/03_hypercloud-api-server.yaml
sudo sed -i 's#{INGRESS_SVCURL}#'${INGRESS_SVCURL}'#g' ${HYPERCLOUD_API_SERVER_HOME}/03_hypercloud-api-server.yaml
sudo sed -i 's#{HYPERAUTH_URL}#'${HYPERAUTH_URL}'#g'  ${HYPERCLOUD_API_SERVER_HOME}/01_init.yaml
sudo sed -i 's/{API_SERVER_LOG_LEVEL}/'${API_SERVER_LOG_LEVEL}'/g'  ${HYPERCLOUD_API_SERVER_HOME}/03_hypercloud-api-server.yaml
sudo sed -i 's/{TIMESCALEDB_LOG_LEVEL}/'${TIMESCALEDB_LOG_LEVEL}'/g'  ${HYPERCLOUD_API_SERVER_HOME}/02_timescaledb-create.yaml
sudo sed -i 's/{TIMESCALEDB_AUDIT_CHUNK_INTERVAL}/'${TIMESCALEDB_AUDIT_CHUNK_INTERVAL}'/g'  ${HYPERCLOUD_API_SERVER_HOME}/02_timescaledb-create.yaml
sudo sed -i 's/{TIMESCALEDB_AUDIT_RETENTION_POLICY}/'${TIMESCALEDB_AUDIT_RETENTION_POLICY}'/g'  ${HYPERCLOUD_API_SERVER_HOME}/02_timescaledb-create.yaml
sudo sed -i 's/{TIMESCALEDB_EVENT_CHUNK_INTERVAL}/'${TIMESCALEDB_EVENT_CHUNK_INTERVAL}'/g'  ${HYPERCLOUD_API_SERVER_HOME}/02_timescaledb-create.yaml
sudo sed -i 's/{TIMESCALEDB_EVENT_RETENTION_POLICY}/'${TIMESCALEDB_EVENT_RETENTION_POLICY}'/g'  ${HYPERCLOUD_API_SERVER_HOME}/02_timescaledb-create.yaml
sudo sed -i 's/{TIMESCALEDB_METERING_HOUR_CHUNK_INTERVAL}/'${TIMESCALEDB_METERING_HOUR_CHUNK_INTERVAL}'/g'  ${HYPERCLOUD_API_SERVER_HOME}/02_timescaledb-create.yaml
sudo sed -i 's/{TIMESCALEDB_METERING_HOUR_RETENTION_POLICY}/'${TIMESCALEDB_METERING_HOUR_RETENTION_POLICY}'/g'  ${HYPERCLOUD_API_SERVER_HOME}/02_timescaledb-create.yaml
sudo sed -i 's/{TIMESCALEDB_METERING_DAY_CHUNK_INTERVAL}/'${TIMESCALEDB_METERING_DAY_CHUNK_INTERVAL}'/g'  ${HYPERCLOUD_API_SERVER_HOME}/02_timescaledb-create.yaml
sudo sed -i 's/{TIMESCALEDB_METERING_DAY_RETENTION_POLICY}/'${TIMESCALEDB_METERING_DAY_RETENTION_POLICY}'/g'  ${HYPERCLOUD_API_SERVER_HOME}/02_timescaledb-create.yaml
sudo sed -i 's/{TIMESCALEDB_METERING_MONTH_CHUNK_INTERVAL}/'${TIMESCALEDB_METERING_MONTH_CHUNK_INTERVAL}'/g'  ${HYPERCLOUD_API_SERVER_HOME}/02_timescaledb-create.yaml
sudo sed -i 's/{TIMESCALEDB_METERING_MONTH_RETENTION_POLICY}/'${TIMESCALEDB_METERING_MONTH_RETENTION_POLICY}'/g'  ${HYPERCLOUD_API_SERVER_HOME}/02_timescaledb-create.yaml
sudo sed -i 's/{TIMESCALEDB_METERING_YEAR_CHUNK_INTERVAL}/'${TIMESCALEDB_METERING_YEAR_CHUNK_INTERVAL}'/g'  ${HYPERCLOUD_API_SERVER_HOME}/02_timescaledb-create.yaml
sudo sed -i 's/{TIMESCALEDB_METERING_YEAR_RETENTION_POLICY}/'${TIMESCALEDB_METERING_YEAR_RETENTION_POLICY}'/g'  ${HYPERCLOUD_API_SERVER_HOME}/02_timescaledb-create.yaml
sudo sed -i 's#{CUSTOM_DOMAIN}#'${CUSTOM_DOMAIN}'#g' ${HYPERCLOUD_API_SERVER_HOME}/03_hypercloud-api-server.yaml
sudo sed -i 's#{CONSOLE_SUBDOMAIN}#'${CONSOLE_SUBDOMAIN}'#g' ${HYPERCLOUD_API_SERVER_HOME}/03_hypercloud-api-server.yaml
sudo sed -i 's#{KUBECTL_TIMEOUT}#'${KUBECTL_TIMEOUT}'#g' ${HYPERCLOUD_API_SERVER_HOME}/03_hypercloud-api-server.yaml

# step 3  - apply manifests
pushd $HYPERCLOUD_API_SERVER_HOME
  kubectl apply -f  01_init.yaml
  kubectl apply -f  02_timescaledb-create.yaml
  kubectl apply -f  03_hypercloud-api-server.yaml
  kubectl apply -f  04_default-role.yaml
popd

timeout 3m kubectl -n hypercloud5-system rollout status deployment/hypercloud5-api-server

#  step 4 - create and apply webhook and audit config
pushd $HYPERCLOUD_API_SERVER_HOME/config
  sudo chmod +x *.sh 
  sudo ./gen-audit-config.sh
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
sudo mv -f ./kube-apiserver.yaml /etc/kubernetes/manifests/kube-apiserver.yaml

#  step 6 - copy audit config files to all k8s-apiserver and modify k8s apiserver manifest
i=0
sudo cp /etc/kubernetes/pki/audit-policy.yaml .
sudo cp /etc/kubernetes/pki/audit-webhook-config .
#sudo cp /etc/kubernetes/pki/hypercloud-root-ca.crt .
for master in "${SUB_MASTER_IP[@]}"
do
  if [ $master == "$MAIN_MASTER_IP" ]; then
    continue
  fi
  sudo sshpass -p "${MASTER_NODE_ROOT_PASSWORD[i]}" scp audit-policy.yaml ${MASTER_NODE_ROOT_USER[i]}@"$master":/etc/kubernetes/pki/audit-policy.yaml
  sudo sshpass -p "${MASTER_NODE_ROOT_PASSWORD[i]}" scp audit-webhook-config ${MASTER_NODE_ROOT_USER[i]}@"$master":/etc/kubernetes/pki/audit-webhook-config
#  sudo sshpass -p "${MASTER_NODE_ROOT_PASSWORD[i]}" scp hypercloud-root-ca.crt ${MASTER_NODE_ROOT_USER[i]}@"$master":/etc/kubernetes/pki/hypercloud-root-ca.crt

  sudo sshpass -p "${MASTER_NODE_ROOT_PASSWORD[i]}" ssh -o StrictHostKeyChecking=no ${MASTER_NODE_ROOT_USER[i]}@"$master" sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml .
  sudo sshpass -p "${MASTER_NODE_ROOT_PASSWORD[i]}" ssh -o StrictHostKeyChecking=no ${MASTER_NODE_ROOT_USER[i]}@"$master" 'sudo yq e '"'"'.spec.containers[0].command += "--audit-webhook-mode=batch"'"'"' -i ./kube-apiserver.yaml'
  sudo sshpass -p "${MASTER_NODE_ROOT_PASSWORD[i]}" ssh -o StrictHostKeyChecking=no ${MASTER_NODE_ROOT_USER[i]}@"$master" 'sudo yq e '"'"'.spec.containers[0].command += "--audit-policy-file=/etc/kubernetes/pki/audit-policy.yaml"'"'"' -i ./kube-apiserver.yaml'
  sudo sshpass -p "${MASTER_NODE_ROOT_PASSWORD[i]}" ssh -o StrictHostKeyChecking=no ${MASTER_NODE_ROOT_USER[i]}@"$master" 'sudo yq e '"'"'.spec.containers[0].command += "--audit-webhook-config-file=/etc/kubernetes/pki/audit-webhook-config"'"'"' -i ./kube-apiserver.yaml'
  sudo sshpass -p "${MASTER_NODE_ROOT_PASSWORD[i]}" ssh -o StrictHostKeyChecking=no ${MASTER_NODE_ROOT_USER[i]}@"$master" 'sudo yq e '"'"'.spec.dnsPolicy += "ClusterFirstWithHostNet"'"'"' -i ./kube-apiserver.yaml'
  sudo sshpass -p "${MASTER_NODE_ROOT_PASSWORD[i]}" ssh -o StrictHostKeyChecking=no ${MASTER_NODE_ROOT_USER[i]}@"$master" sudo mv -f ./kube-apiserver.yaml /etc/kubernetes/manifests/kube-apiserver.yaml

  i=$((i+1))
done
rm -f audit-policy.yaml audit-webhook-config

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

#Install hypercloud-multi-server
if [ $HPCD_MODE == "multi" ]; then
pushd $HYPERCLOUD_MULTI_OPERATOR_HOME

# step 1 - put oidc, audit configuration to cluster-template yaml file
# oidc configuration
  sed -i 's#${HYPERAUTH_URL}#'${HYPERAUTH_URL}'#g' ./capi-*-template-v${HPCD_MULTI_OPERATOR_VERSION}.yaml
# audit configuration
  FILE=("hyperauth.crt" "audit-webhook-config" "audit-policy.yaml")
  PARAM=("\${HYPERAUTH_CERT}" "\${AUDIT_WEBHOOK_CONFIG}" "\${AUDIT_POLICY}")
  for i in ${!FILE[*]}
  do
    sudo awk '{print "          " $0}' /etc/kubernetes/pki/${FILE[$i]} > ./${FILE[$i]}
    sudo sed -e '/'${PARAM[$i]}'/r ./'${FILE[$i]}'' -e '/'${PARAM[$i]}'/d' -i ./capi-*-template-v${HPCD_MULTI_OPERATOR_VERSION}.yaml
    rm -f ./${FILE[$i]}
  done
  sed -i 's#'${INGRESS_DNSURL}'#'${INGRESS_SVCURL}'\/audit\/${Namespace}\/${clusterName}#g' ./capi-*-template-v${HPCD_MULTI_OPERATOR_VERSION}.yaml

# step 2 - install hypercloud multi operator
  sudo sed -i 's#${custom_domain}#'${CUSTOM_DOMAIN}'#g' hypercloud-multi-operator-v${HPCD_MULTI_OPERATOR_VERSION}.yaml
  if [ $REGISTRY != "{REGISTRY}" ]; then
    sudo sed -i 's#tmaxcloudck/hypercloud-multi-operator#'${REGISTRY}'/tmaxcloudck/hypercloud-multi-operator#g' hypercloud-multi-operator-v${HPCD_MULTI_OPERATOR_VERSION}.yaml
    sudo sed -i 's#gcr.io/kubebuilder/kube-rbac-proxy#'${REGISTRY}'/gcr.io/kubebuilder/kube-rbac-proxy#g' hypercloud-multi-operator-v${HPCD_MULTI_OPERATOR_VERSION}.yaml
  fi
  sudo sed -i 's/--zap-log-level=info/'--zap-log-level=${MULTI_OPERATOR_LOG_LEVEL}'/g' hypercloud-multi-operator-v${HPCD_MULTI_OPERATOR_VERSION}.yaml
  kubectl apply -f hypercloud-multi-operator-v${HPCD_MULTI_OPERATOR_VERSION}.yaml
  if [ -e "key-mapping/hypercloud-multi-operator-crd-v${HPCD_MULTI_OPERATOR_VERSION}.yaml" ]; then
    kubectl apply -f  key-mapping/hypercloud-multi-operator-crd-v${HPCD_MULTI_OPERATOR_VERSION}.yaml
  fi

  for capi_provider_template in capi-*-template-v${HPCD_MULTI_OPERATOR_VERSION}.yaml
  do
      kubectl apply -f ${capi_provider_template}
  done
popd

#pushd $HYPERCLOUD_MULTI_AGENT_HOME
#  sudo sed -i 's/{HPCD_MULTI_AGENT_VERSION}/b'${HPCD_MULTI_AGENT_VERSION}'/g'  ${HYPERCLOUD_MULTI_AGENT_HOME}/03_federate-deployment.yaml
#  if [ $REGISTRY != "{REGISTRY}" ]; then
#    sudo sed -i 's#tmaxcloudck/hypercloud-multi-agent#'${REGISTRY}'/tmaxcloudck/hypercloud-multi-agent#g' ${HYPERCLOUD_MULTI_AGENT_HOME}/03_federate-deployment.yaml
#  fi
#  kubectl apply -f ${HYPERCLOUD_MULTI_AGENT_HOME}/01_federate-namespace.yaml
#  kubectl apply -f ${HYPERCLOUD_MULTI_AGENT_HOME}/02_federate-clusterRoleBinding.yaml
#  kubectl apply -f ${HYPERCLOUD_MULTI_AGENT_HOME}/03_federate-deployment.yaml
#popd
#fi
