#!/usr/bin/env bash
set -euo pipefail

echo "==> Granting cluster-admin to the Jenkins controller service account (demo-friendly)"
kubectl apply -f - <<'YAML'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: jenkins-controller-admin
subjects:
- kind: ServiceAccount
  name: jenkins
  namespace: jenkins
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
YAML

kubectl get clusterrolebinding jenkins-controller-admin
echo "✅ Jenkins controller now has cluster-admin."
