SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
HYPERCLOUD_API_SERVER_HOME=$SCRIPTDIR/hypercloud-api-server
source $SCRIPTDIR/hypercloud.config


pushd $HYPERCLOUD_API_SERVER_HOME/pki
  sudo chmod +x *.sh
  sudo ./generateTls.sh -name=hypercloud-api-server -dns=hypercloud5-api-server-service.hypercloud5-system.svc -dns=hypercloud5-api-server-service.hypercloud5-system.svc.cluster.local
  sudo chmod +777 hypercloud-api-server.*

  kubectl -n hypercloud5-system create secret generic hypercloud5-api-server-certs \
    --from-file=$HYPERCLOUD_API_SERVER_HOME/pki/hypercloud-api-server.crt \
    --from-file=$HYPERCLOUD_API_SERVER_HOME/pki/hypercloud-api-server.key

  sudo cp /etc/kubernetes/pki/hypercloud-root-ca.crt $HYPERCLOUD_API_SERVER_HOME/pki/
  sudo chmod +777 $HYPERCLOUD_API_SERVER_HOME/pki/hypercloud-root-ca.crt
  sudo chmod +777 $HYPERCLOUD_API_SERVER_HOME/pki/hypercloud-api-server.*
  kubectl -n hypercloud5-system create secret generic hypercloud-kafka-secret \
    --from-file=$HYPERCLOUD_API_SERVER_HOME/pki/hypercloud-root-ca.crt \
    --from-file=$HYPERCLOUD_API_SERVER_HOME/pki/hypercloud-api-server.crt \
    --from-file=$HYPERCLOUD_API_SERVER_HOME/pki/hypercloud-api-server.key
popd

pushd $HYPERCLOUD_API_SERVER_HOME
  sudo chmod +777 $HYPERCLOUD_API_SERVER_HOME/html/cluster-invitation.html
  kubectl create configmap html-config --from-file=$HYPERCLOUD_API_SERVER_HOME/html/cluster-invitation.html -n hypercloud5-system

  sudo sed -i 's/{KAFKA1_ADDR}/'DNS'/g'  ${HYPERCLOUD_API_SERVER_HOME}/03_hypercloud-api-server.yaml
  sudo sed -i 's/{KAFKA2_ADDR}/'DNS'/g'  ${HYPERCLOUD_API_SERVER_HOME}/03_hypercloud-api-server.yaml
  sudo sed -i 's/{KAFKA3_ADDR}/'DNS'/g'  ${HYPERCLOUD_API_SERVER_HOME}/03_hypercloud-api-server.yaml
  sudo sed -i 's/{HPCD_API_SERVER_VERSION}/b'${HPCD_API_SERVER_VERSION}'/g'  ${HYPERCLOUD_API_SERVER_HOME}/03_hypercloud-api-server.yaml
  sudo sed -i 's/{HPCD_MODE}/'${HPCD_MODE}'/g'  ${HYPERCLOUD_API_SERVER_HOME}/03_hypercloud-api-server.yaml
  sudo sed -i 's/{HPCD_POSTGRES_VERSION}/b'${HPCD_POSTGRES_VERSION}'/g'  ${HYPERCLOUD_API_SERVER_HOME}/02_postgres-create.yaml
  sudo sed -i 's/{INVITATION_TOKEN_EXPIRED_DATE}/'${INVITATION_TOKEN_EXPIRED_DATE}'/g'  ${HYPERCLOUD_API_SERVER_HOME}/02_postgres-create.yaml
  sudo sed -i 's/{INVITATION_TOKEN_EXPIRED_DATE}/'${INVITATION_TOKEN_EXPIRED_DATE}'/g'  ${HYPERCLOUD_API_SERVER_HOME}/03_hypercloud-api-server.yaml
  sudo sed -i 's/{KAFKA_GROUP_ID}/'hypercloud-api-server-$HOSTNAME-$(($RANDOM%100))'/g' ${HYPERCLOUD_API_SERVER_HOME}/03_hypercloud-api-server.yaml
  sudo sed -i 's#{HYPERAUTH_URL}#'${HYPERAUTH_URL}'#g'  ${HYPERCLOUD_API_SERVER_HOME}/01_init.yaml

  kubectl apply -f  01_init.yaml
  kubectl apply -f  02_postgres-create.yaml
  kubectl apply -f  03_hypercloud-api-server.yaml
  kubectl apply -f  04_default-role.yaml
popd


pushd $HYPERCLOUD_API_SERVER_HOME/config
  sudo chmod +x *.sh 
  sudo ./gen-audit-config.sh
  sudo cp audit-policy.yaml /etc/kubernetes/pki/
  sudo cp audit-webhook-config /etc/kubernetes/pki/
popd

sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml .
sudo yq e '.spec.containers[0].command += "--audit-webhook-mode=batch"' -i ./kube-apiserver.yaml
sudo yq e '.spec.containers[0].command += "--audit-policy-file=/etc/kubernetes/pki/audit-policy.yaml"' -i ./kube-apiserver.yaml
sudo yq e '.spec.containers[0].command += "--audit-webhook-config-file=/etc/kubernetes/pki/audit-webhook-config"' -i ./kube-apiserver.yaml
sudo yq e 'del(.spec.dnsPolicy)' -i kube-apiserver.yaml
sudo yq e '.spec.dnsPolicy += "ClusterFirstWithHostNet"' -i kube-apiserver.yaml
sudo mv -f ./kube-apiserver.yaml /etc/kubernetes/manifests/kube-apiserver.yaml
