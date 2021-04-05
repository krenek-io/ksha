#!/bin/bash
#
# Name: KSHA <controller.sh>
# Author: Vagner Rodrigues Fernandes <team@krenek.io>
# Description: Simple Kubernetes Shell Script Autoscaler Controller 
# Version: 0.1b
#

# LOCK POINTER
LOCK_PODS=0

# CURL OUTPUT LOG FILE
LOG_FILE="${LOG_CURL:-/var/log/ksha.log}"
touch $LOG_FILE 

# CUSTOM METRIC SCRIPT
if [ -z "$METRIC_SCRIPT" ]; then
  echo "[ERROR] \$METRIC_SCRIPT required environment"
  exit
fi

# SCALE CONDITIONS
if [ -z "$CONDITIONS" ]; then
  echo "[ERROR] \$CONDITIONS required environment"
  exit
fi
CONDITIONS=($CONDITIONS)

# LOOP INTERVAL
INTERVAL_CONTROLLER="${INTERVAL_CONTROLLER:-60}"

while [ 0 ]; do
x=0;
CURRENT_VALUE=`bash ./metrics.d/$METRIC_SCRIPT.sh`

  while [ $x != ${#CONDITIONS[@]} ]; do

    MIN_VALUE=`echo ${CONDITIONS[$x]} | cut -d\= -f1`
    MIN_PODS=`echo ${CONDITIONS[$x]} | cut -d\= -f2`

    if (( "$CURRENT_VALUE" > "$MIN_VALUE" )); then
      SCALE_MIN_PODS=$MIN_PODS
      SCALE_MIN_VALUE=$MIN_VALUE
    fi

    let "x = x +1"

  done;

  echo "[CURRENT_VALUE: ${CURRENT_VALUE} MIN_VALUE: ${SCALE_MIN_VALUE} SCALE ${SCALE_MIN_PODS} PODS - ACTIVE_SCALE: $ACTIVE_SCALE]"

  # SCALE on KUBERNETES (Deployment)
  if [ "$ACTIVE_SCALE" == "true" ]; then
    if [ "$SCALE_MIN_PODS" != "$LOCK_PODS" ]; then
      curl -s -X PATCH --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
        -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
        https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_PORT_443_TCP_PORT/apis/apps/v1/namespaces/${NAMESPACE}/deployments/${DEPLOYMENT} \
        -H 'Content-Type: application/strategic-merge-patch+json' \
        -d '{"spec":{"replicas":'$SCALE_MIN_PODS'}}' -o $LOG_FILE
      echo "[SCALE ${SCALE_MIN_PODS} PODS on ${DEPLOYMENT}]"
      LOCK_PODS=$SCALE_MIN_PODS
    fi
  fi

  sleep $INTERVAL_CONTROLLER

done
