#!/usr/bin/env bash

set -euo pipefail

KUBE_CONTEXT="${KUBE_CONTEXT:-k3s-homelab}"
NAMESPACE="${NAMESPACE:-bookorbit}"
PVC_NAME="${PVC_NAME:-bookorbit-koplugin}"
HELPER_POD="${HELPER_POD:-bookorbit-koplugin-sync}"
HELPER_IMAGE="${HELPER_IMAGE:-busybox:1.37}"
LOCAL_PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/bookorbit.koplugin"
MOUNT_DIR=/plugin
KUBECTL=(kubectl --context "$KUBE_CONTEXT" -n "$NAMESPACE")

if [[ ! -f "$LOCAL_PLUGIN_DIR/main.lua" ]]; then
  printf 'Local plugin directory is missing or incomplete: %s\n' "$LOCAL_PLUGIN_DIR" >&2
  exit 1
fi

cleanup() {
  "${KUBECTL[@]}" delete pod "$HELPER_POD" --ignore-not-found --wait=false >/dev/null
}

# Remove a helper left behind by an interrupted run.
"${KUBECTL[@]}" delete pod "$HELPER_POD" --ignore-not-found --wait=true >/dev/null
trap cleanup EXIT

# A standalone helper pod means the sync works even when the app is down. It
# runs as the app's uid; the NFS share maps writes to k3s:media either way.
printf 'Starting helper pod %s with PVC %s\n' "$HELPER_POD" "$PVC_NAME"
"${KUBECTL[@]}" apply -f - >/dev/null <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: ${HELPER_POD}
  labels:
    app.kubernetes.io/name: bookorbit-koplugin-sync
spec:
  restartPolicy: Never
  activeDeadlineSeconds: 600
  securityContext:
    runAsUser: 1000
    runAsGroup: 1000
  containers:
    - name: sync
      image: ${HELPER_IMAGE}
      command: ["sleep", "600"]
      volumeMounts:
        - name: koplugin
          mountPath: ${MOUNT_DIR}
  volumes:
    - name: koplugin
      persistentVolumeClaim:
        claimName: ${PVC_NAME}
EOF

"${KUBECTL[@]}" wait --for=condition=Ready "pod/$HELPER_POD" --timeout=120s >/dev/null

printf 'Streaming local plugin into PVC %s\n' "$PVC_NAME"
COPYFILE_DISABLE=1 tar -C "$LOCAL_PLUGIN_DIR" -cf - . |
  "${KUBECTL[@]}" exec -i "$HELPER_POD" -- sh -c \
    "find '$MOUNT_DIR' -mindepth 1 -maxdepth 1 -exec rm -rf -- {} + && tar -xf - -C '$MOUNT_DIR'"

"${KUBECTL[@]}" exec "$HELPER_POD" -- sh -c "grep '^local PLUGIN_VERSION' '$MOUNT_DIR/main.lua'"

printf 'KOReader plugin synced to PVC %s in namespace %s\n' "$PVC_NAME" "$NAMESPACE"
