#!/usr/bin/env bash
set -euo pipefail

NAMESPACE_DEFAULT="default"
PROD_SVC="inference-svc-blue"     # production entrypoint
GREEN_SVC="inference-svc-green"   # canary/green backend
APP_LABEL="inference"

cleanup() {
  kubectl delete pod curl-green -n "$NAMESPACE_DEFAULT" --ignore-not-found >/dev/null 2>&1 || true
  kubectl delete pod curl-prod  -n "$NAMESPACE_DEFAULT" --ignore-not-found >/dev/null 2>&1 || true
}

rollback() {
  echo "🔁 Rolling back production to BLUE (selector version=blue)"
  kubectl patch svc "$PROD_SVC" -n "$NAMESPACE_DEFAULT" \
    -p '{"spec":{"selector":{"app":"inference","version":"blue"}}}' >/dev/null || true
  kubectl get svc "$PROD_SVC" -n "$NAMESPACE_DEFAULT" -o yaml | sed -n '/selector:/,/ports:/p' || true
}

on_error() {
  echo "❌ Pipeline failed."
  rollback
  cleanup
}
trap on_error ERR
trap cleanup EXIT

echo "==> Sanity: workloads"
kubectl get pods -n "$NAMESPACE_DEFAULT" | egrep 'inference-blue|inference-green' || true
kubectl get svc  -n "$NAMESPACE_DEFAULT" | egrep 'inference-svc-blue|inference-svc-green' || true
kubectl get ingress -n "$NAMESPACE_DEFAULT" | egrep 'inference-blue|inference-green-canary' || true

echo "==> Smoke test GREEN (service: $GREEN_SVC)"
kubectl delete pod curl-green -n "$NAMESPACE_DEFAULT" --ignore-not-found >/dev/null || true

kubectl run curl-green -n "$NAMESPACE_DEFAULT" --restart=Never --image=alpine:3.19 -- \
  sh -lc "apk add --no-cache curl >/dev/null && curl -s --max-time 10 http://${GREEN_SVC}/health"

# Wait for completion and capture logs
kubectl wait -n "$NAMESPACE_DEFAULT" --for=condition=Ready pod/curl-green --timeout=60s || true
kubectl wait -n "$NAMESPACE_DEFAULT" --for=condition=Complete pod/curl-green --timeout=60s || true

GREEN_OUT="$(kubectl logs -n "$NAMESPACE_DEFAULT" curl-green || true)"
echo "$GREEN_OUT"

echo "$GREEN_OUT" | grep -q '"deploy_color":"green"'

echo "✅ GREEN smoke test passed"

echo "==> Promote GREEN to PROD by switching ${PROD_SVC} selector to version=green"
kubectl patch svc "$PROD_SVC" -n "$NAMESPACE_DEFAULT" \
  -p '{"spec":{"selector":{"app":"inference","version":"green"}}}'

kubectl get svc "$PROD_SVC" -n "$NAMESPACE_DEFAULT" -o yaml | sed -n '/selector:/,/ports:/p'

echo "==> Smoke test PROD path (service: $PROD_SVC) should now hit GREEN"
kubectl delete pod curl-prod -n "$NAMESPACE_DEFAULT" --ignore-not-found >/dev/null || true

kubectl run curl-prod -n "$NAMESPACE_DEFAULT" --restart=Never --image=alpine:3.19 -- \
  sh -lc "apk add --no-cache curl >/dev/null && curl -s --max-time 10 http://${PROD_SVC}/health"

kubectl wait -n "$NAMESPACE_DEFAULT" --for=condition=Ready pod/curl-prod --timeout=60s || true
kubectl wait -n "$NAMESPACE_DEFAULT" --for=condition=Complete pod/curl-prod --timeout=60s || true

PROD_OUT="$(kubectl logs -n "$NAMESPACE_DEFAULT" curl-prod || true)"
echo "$PROD_OUT"

echo "$PROD_OUT" | grep -q '"deploy_color":"green"'

echo "🎉 Promotion verified. Production is now GREEN."
