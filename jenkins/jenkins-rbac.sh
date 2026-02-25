#!/bin/bash
set -e

NAMESPACE=jenkins
SA_NAME=jenkins-deployer
CRB_NAME=jenkins-deployer-admin

# Create namespace if it does not exist
kubectl get namespace $NAMESPACE >/dev/null 2>&1 || \
kubectl create namespace $NAMESPACE

# Create ServiceAccount
kubectl create serviceaccount $SA_NAME \
  --namespace $NAMESPACE \
  --dry-run=client -o yaml | kubectl apply -f -

# Create ClusterRoleBinding granting cluster-admin
kubectl create clusterrolebinding $CRB_NAME \
  --clusterrole=cluster-admin \
  --serviceaccount=$NAMESPACE:$SA_NAME \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Jenkins deployer ServiceAccount and RBAC configured successfully."
