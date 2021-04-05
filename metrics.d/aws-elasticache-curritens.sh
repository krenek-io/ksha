#!/bin/bash

aws cloudwatch get-metric-statistics \
  --region ${AWS_DEFAULT_REGION} \
  --namespace AWS/ElastiCache \
  --metric-name CurrItems \
  --statistics Sum \
  --start-time $(date -u +%Y-%m-%dT%T --date 'now -1 mins') --end-time $(date -u +%Y-%m-%dT%T) --period 60 \
  --dimensions Name=CacheClusterId,Value=$REDIS_CLUSTER | jq -r '.Datapoints[0].Sum'
