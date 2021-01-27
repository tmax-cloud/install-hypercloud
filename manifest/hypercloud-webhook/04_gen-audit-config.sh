#!/bin/bash
export HYPERCLOUD4_CA_CERT=$(openssl base64 -A <"${HPCD_HOME}/manifest/hypercloud-webhook-${HPCD_WEBHOOK_VERSION}/pki/ca.crt")

AUDIT_CONFIG_FILE=05_audit-webhook-config
if [ -f ${HPCD_HOME}/manifest/hypercloud-webhook-${HPCD_WEBHOOK_VERSION}/"$AUDIT_CONFIG_FILE" ]; then
   echo "Remove existed audit config file."
   rm ${HPCD_HOME}/manifest/hypercloud-webhook-${HPCD_WEBHOOK_VERSION}/$AUDIT_CONFIG_FILE
fi

echo "Generate audit config file."
envsubst < ${HPCD_HOME}/manifest/hypercloud-webhook-${HPCD_WEBHOOK_VERSION}/"$AUDIT_CONFIG_FILE".template  > ${HPCD_HOME}/manifest/hypercloud-webhook-${HPCD_WEBHOOK_VERSION}/"$AUDIT_CONFIG_FILE"
