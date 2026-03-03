#!/usr/bin/env bash
set -euo pipefail

NS="${NS:-default}"
PROD_SVC="${PROD_SVC:-inference-svc-prod}"
CANARY_ING="${CANARY_ING:-inference-green-canary}"

# --- kubectl discovery (works in non-interactive SSH / Jenkins) ---
KUBECTL="${KUBECTL:-/usr/local/bin/kubectl}"

# If the default path doesn't exist, fall back to PATH lookup.
if [ ! -x "$KUBECTL" ]; then
  KUBECTL="$(command -v kubectl || true)"
fi

if [ -z "${KUBECTL:-}" ] || [ ! -x "$KUBECTL" ]; then
  echo "ERROR: kubectl not found."
  echo "  Tried: /usr/local/bin/kubectl and PATH lookup."
  echo "  Fix: install kubectl or set KUBECTL=/full/path/to/kubectl"
  exit 127
fi
# ---------------------------------------------------------------

usage() {
  echo "Usage:"
  echo "  $0 status"
  echo "  $0 canary <0-100>"
  echo "  $0 promote <blue|green>"
  exit 1
}

live_color() {
  # Determine live color from service selector
  "$KUBECTL" -n "$NS" get svc "$PROD_SVC" -o jsonpath='{.spec.selector.version}{"\n"}' 2>/dev/null || true
}

case "${1:-}" in
  status)
    echo "=== kubectl ==="
    echo "KUBECTL=$KUBECTL"
    "$KUBECTL" version --client --short 2>/dev/null || "$KUBECTL" version --client=true 2>/dev/null || true
    echo

    echo "=== PROD SERVICE SELECTOR ==="
    "$KUBECTL" -n "$NS" get svc "$PROD_SVC" -o jsonpath='{.spec.selector}{"\n"}'
    echo "Live version: $(live_color)"
    echo
    echo "=== CANARY INGRESS ANNOTATIONS ==="
    "$KUBECTL" -n "$NS" get ingress "$CANARY_ING" -o jsonpath='{.metadata.annotations.nginx\.ingress\.kubernetes\.io/canary}{"\n"}' || true
    "$KUBECTL" -n "$NS" get ingress "$CANARY_ING" -o jsonpath='{.metadata.annotations.nginx\.ingress\.kubernetes\.io/canary-weight}{"\n"}' || true
    "$KUBECTL" -n "$NS" get ingress "$CANARY_ING" -o jsonpath='{.metadata.annotations.nginx\.ingress\.kubernetes\.io/canary-by-header}{"\n"}' || true
    "$KUBECTL" -n "$NS" get ingress "$CANARY_ING" -o jsonpath='{.metadata.annotations.nginx\.ingress\.kubernetes\.io/canary-by-header-value}{"\n"}' || true
    ;;

  canary)
    [ $# -eq 2 ] || usage
    W="$2"
    if ! [[ "$W" =~ ^[0-9]+$ ]] || [ "$W" -lt 0 ] || [ "$W" -gt 100 ]; then
      echo "Invalid weight: $W (must be 0-100)"
      exit 2
    fi
    echo "Setting canary weight to $W%"
    "$KUBECTL" -n "$NS" annotate ingress "$CANARY_ING" nginx.ingress.kubernetes.io/canary-weight="$W" --overwrite
    ;;

  promote)
    [ $# -eq 2 ] || usage
    COLOR="$2"
    if [[ "$COLOR" != "blue" && "$COLOR" != "green" ]]; then
      echo "promote expects blue|green"
      exit 2
    fi
    echo "Promoting $COLOR to PROD by switching $PROD_SVC selector"
    "$KUBECTL" -n "$NS" patch svc "$PROD_SVC" --type='merge' -p "{\"spec\":{\"selector\":{\"app\":\"inference\",\"version\":\"$COLOR\"}}}"
    echo "Now live: $(live_color)"
    ;;

  *)
    usage
    ;;
esac
