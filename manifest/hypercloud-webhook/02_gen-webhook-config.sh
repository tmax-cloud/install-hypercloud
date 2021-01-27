#!/bin/bash

export HYPERCLOUD4_CA_CERT=$(openssl base64 -A <"${HPCD_HOME}/manifest/hypercloud-webhook-${HPCD_WEBHOOK_VERSION}/pki/ca.crt")

WEBHOOK_CONFIG_FILE=03_webhook-configuration.yaml
if [ -f ${HPCD_HOME}/manifest/hypercloud-webhook-${HPCD_WEBHOOK_VERSION}/"$WEBHOOK_CONFIG_FILE" ]; then
   echo "Remove existed webhook config file."
   rm ${HPCD_HOME}/manifest/hypercloud-webhook-${HPCD_WEBHOOK_VERSION}/$WEBHOOK_CONFIG_FILE
fi

echo "Generate webhook config file."
envsubst < ${HPCD_HOME}/manifest/hypercloud-webhook-${HPCD_WEBHOOK_VERSION}/"$WEBHOOK_CONFIG_FILE".template  > ${HPCD_HOME}/manifest/hypercloud-webhook-${HPCD_WEBHOOK_VERSION}/"$WEBHOOK_CONFIG_FILE"
