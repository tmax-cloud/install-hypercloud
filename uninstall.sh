SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
HYPERCLOUD_API_SERVER_HOME=$SCRIPTDIR/hypercloud-api-server
HYPERCLOUD_SINGLE_OPERATOR_HOME=$SCRIPTDIR/hypercloud-single-operator
HYPERCLOUD_MULTI_OPERATOR_HOME=$SCRIPTDIR/hypercloud-multi-operator
source $SCRIPTDIR/hypercloud.config
#KUSTOMIZE_VERSION=${KUSTOMIZE_VERSION:-"v3.8.5"}
#YQ_VERSION=${YQ_VERSION:-"v4.4.1"}
set -xe



pushd $HYPERCLOUD_API_SERVER_HOME/config
  rm /etc/kubernetes/pki/audit-policy.yaml
  rm /etc/kubernetes/pki/audit-webhook-config

  kubectl delete -f webhook-configuration.yaml
popd

pushd $HYPERCLOUD_API_SERVER_HOME
  timeout 5m kubectl delete -f 05_default-role.yaml
  suc=`echo $?`
  if [ $suc != 0 ]; then
    echo "Failed to delete 05_default-role.yaml"
  fi
  timeout 5m kubectl delete -f 04_hypercloud-api-server.yaml
  suc=`echo $?`
  if [ $suc != 0 ]; then
    echo "Failed to delete 04_hypercloud-api-server.yaml"
  fi
  timeout 5m kubectl delete -f 03_postgres-create.yaml
  suc=`echo $?`
  if [ $suc != 0 ]; then
    echo "Failed to delete 03_postgres-create.yaml"
  fi
  timeout 5m kubectl delete -f 02_mysql-create.yaml
  suc=`echo $?`
  if [ $suc != 0 ]; then
    echo "Failed to delete 02_mysql-create.yaml"
  fi
  timeout 5m kubectl delete -f 01_init.yaml
  suc=`echo $?`
  if [ $suc != 0 ]; then
    echo "Failed to delete 01_init.yaml"
  fi
popd

pushd $HYPERCLOUD_API_SERVER_HOME/pki
  timeout 5m kubectl -n hypercloud5-system delete secret hypercloud5-api-server-certs
  suc=`echo $?`
  if [ $suc != 0 ]; then
    echo "Failed to delete secret"
  fi
popd

pushd $HYPERCLOUD_MULTI_OPERATOR_HOME
  timeout 5m kubectl delete -f hypercloud-multi-operator-v${HPCD_MULTI_OPERATOR_VERSION}.yaml
  suc=`echo $?`
  if [ $suc != 0 ]; then
    echo "Failed to delete hypercloud-multi-operator"
  fi
popd

pushd $HYPERCLOUD_SINGLE_OPERATOR_HOME
  timeout 5m kubectl delete -f hypercloud-single-operator.yaml
  suc=`echo $?`
  if [ $suc != 0 ]; then
    echo "Failed to delete hypercloud-single-operator"
  fi
popd

timeout 5m kubectl delete namespace hypercloud5-system
suc=`echo $?`
if [ $suc != 0 ]; then
  echo "Failed to delete namespace hypercloud5-system"
fi

timeout 5m kubectl delete -f https://github.com/jetstack/cert-manager/releases/download/v1.2.0/cert-manager.yaml
if [ $suc != 0 ]; then
  echo "Failed to delete cert-manager"
fi

sudo yq e 'del(.spec.dnsPolicy)' -i /etc/kubernetes/manifests/kube-apiserver.yaml
