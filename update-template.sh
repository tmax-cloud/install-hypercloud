SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $SCRIPTDIR/hypercloud.config
HYPERCLOUD_MULTI_OPERATOR_HOME=$SCRIPTDIR/hypercloud-multi-operator
CSB_NAME="$(kubectl get clusterservicebroker -o jsonpath='{.items[0].metadata.name}')"
CSB_URL="$(kubectl get clusterservicebroker -o jsonpath='{.items[0].spec.url}')"
# Update capi-template
pushd $HYPERCLOUD_MULTI_OPERATOR_HOME
  
# step 1 - put oidc, audit configuration to cluster-template yaml file
# oidc configuration
  sed -i 's#${HYPERAUTH_URL}#'${HYPERAUTH_URL}'#g' ./capi-*-template-v${HPCD_MULTI_OPERATOR_VERSION}.yaml
# audit configuration
  FILE=("aws-en.cer" "audit-webhook-config" "audit-policy.yaml")
  PARAM=("\${HYPERAUTH_CERT}" "\${AUDIT_WEBHOOK_CONFIG}" "\${AUDIT_POLICY}")
  for i in ${!FILE[*]}
  do
    sudo awk '{print "          " $0}' /etc/kubernetes/pki/${FILE[$i]} > ./${FILE[$i]}
    sudo sed -e '/'${PARAM[$i]}'/r ./'${FILE[$i]}'' -e '/'${PARAM[$i]}'/d' -i ./capi-*-template-v${HPCD_MULTI_OPERATOR_VERSION}.yaml
    rm -f ./${FILE[$i]}
  done
  # 마스터 클러스터에서 audit 통합 관리할 시에는 주석 해제
  #sed -i 's#'${INGRESS_DNSURL}'#'${INGRESS_SVCURL}'\/audit\/${Namespace}\/${clusterName}#g' ./capi-*-template-v${HPCD_MULTI_OPERATOR_VERSION}.yaml

# step 2 - replace template file
  if [ $REGISTRY != "{REGISTRY}" ]; then
    sudo sed -i 's#tmaxcloudck/hypercloud-multi-operator#'${REGISTRY}'/tmaxcloudck/hypercloud-multi-operator#g' hypercloud-multi-operator-v${HPCD_MULTI_OPERATOR_VERSION}.yaml
    sudo sed -i 's#gcr.io/kubebuilder/kube-rbac-proxy#'${REGISTRY}'/gcr.io/kubebuilder/kube-rbac-proxy#g' hypercloud-multi-operator-v${HPCD_MULTI_OPERATOR_VERSION}.yaml
  fi
  kubectl apply -f hypercloud-multi-operator-v${HPCD_MULTI_OPERATOR_VERSION}.yaml

  for capi_provider_template in "$(ls service-catalog-template-CAPI-*.yaml)"
  do
      kubectl apply -f ${capi_provider_template}
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