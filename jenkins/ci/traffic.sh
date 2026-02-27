#!/usr/bin/env bash
set -euo pipefail

NS="${NS:-default}"
PROD_SVC="${PROD_SVC:-inference-svc-prod}"
CANARY_ING="${CANARY_ING:-inference-green-canary}"

usage() {
  echo "Usage:"
  echo "  $0 status"
  echo "  $0 canary <0-100>"
  echo "  $0 promote <blue|green>"
  exit 1
}

live_color() {
  # Determine live color from service selector
  kubectl -n "$NS" get svc "$PROD_SVC" -o jsonpath='{.spec.selector.version}{"\n"}' 2>/dev/null || true
}

case "${1:-}" in
  status)
    echo "=== PROD SERVICE SELECTOR ==="
    kubectl -n "$NS" get svc "$PROD_SVC" -o jsonpath='{.spec.selector}{"\n"}'
    echo "Live version: $(live_color)"
    echo
    echo "=== CANARY INGRESS ANNOTATIONS ==="
    kubectl -n "$NS" get ingress "$CANARY_ING" -o jsonpath='{.metadata.annotations.nginx\.ingress\.kubernetes\.io/canary}{"\n"}' || true
    kubectl -n "$NS" get ingress "$CANARY_ING" -o jsonpath='{.metadata.annotations.nginx\.ingress\.kubernetes\.io/canary-weight}{"\n"}' || true
    kubectl -n "$NS" get ingress "$CANARY_ING" -o jsonpath='{.metadata.annotations.nginx\.ingress\.kubernetes\.io/canary-by-header}{"\n"}' || true
    kubectl -n "$NS" get ingress "$CANARY_ING" -o jsonpath='{.metadata.annotations.nginx\.ingress\.kubernetes\.io/canary-by-header-value}{"\n"}' || true
    ;;

  canary)
    [ $# -eq 2 ] || usage
    W="$2"
    if ! [[ "$W" =~ ^[0-9]+$ ]] || [ "$W" -lt 0 ] || [ "$W" -gt 100 ]; then
      echo "Invalid weight: $W (must be 0-100)"
      exit 2
    fi
    echo "Setting canary weight to $W%"
    kubectl -n "$NS" annotate ingress "$CANARY_ING" nginx.ingress.kubernetes.io/canary-weight="$W" --overwrite
    ;;

  promote)
    [ $# -eq 2 ] || usage
    COLOR="$2"
    if [[ "$COLOR" != "blue" && "$COLOR" != "green" ]]; then
      echo "promote expects blue|green"
      exit 2
    fi
    echo "Promoting $COLOR to PROD by switching $PROD_SVC selector"
    kubectl -n "$NS" patch svc "$PROD_SVC" --type='merge' -p "{\"spec\":{\"selector\":{\"app\":\"inference\",\"version\":\"$COLOR\"}}}"
    echo "Now live: $(live_color)"
    ;;

  *)
    usage
    ;;
esac
