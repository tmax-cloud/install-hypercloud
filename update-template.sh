SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $SCRIPTDIR/hypercloud.config
HYPERCLOUD_MULTI_OPERATOR_HOME=$SCRIPTDIR/hypercloud-multi-operator
KA_YAML=`sudo yq e '.spec.containers[0].command' /etc/kubernetes/manifests/kube-apiserver.yaml`
HYPERAUTH_URL=`echo "${KA_YAML#*--oidc-issuer-url=}" | tr -d '\12' | cut -d '-' -f1`
INGRESS_DNSURL="hypercloud5-api-server-service.hypercloud5-system.svc/audit"
INGRESS_IPADDR=$(kubectl get svc ingress-nginx-shared-controller -n ingress-nginx-shared -o jsonpath='{.status.loadBalancer.ingress[0:].ip}')
INGRESS_SVCURL="hypercloud5-api-server-service."${INGRESS_IPADDR}".nip.io"
CSB_NAME="$(kubectl get clusterservicebroker -o jsonpath='{.items[0].metadata.name}')"
CSB_URL="$(kubectl get clusterservicebroker -o jsonpath='{.items[0].spec.url}')"
# Update capi-template
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

# step 2 - replace template file
  #if [ $REGISTRY != "{REGISTRY}" ]; then
  #  sudo sed -i 's#gcr.io/kubebuilder/kube-rbac-proxy#'${REGISTRY}'/gcr.io/kubebuilder/kube-rbac-proxy#g' hypercloud-multi-operator-v${HPCD_MULTI_OPERATOR_VERSION}.yaml
  #fi

  for capi_provider_template in capi-*-template-v${HPCD_MULTI_OPERATOR_VERSION}.yaml
  do
      kubectl replace -f ${capi_provider_template}
  done

# step 3 - restart cluster service broker
  kubectl delete clusterservicebroker ${CSB_NAME}
  cat << EOF | kubectl apply -f -
  apiVersion: servicecatalog.k8s.io/v1beta1
  kind: ClusterServiceBroker
  metadata:
    name: "${CSB_NAME}"
  spec:
    url: "${CSB_URL}"
EOF
popd
