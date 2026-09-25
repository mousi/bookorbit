# Maintaining the private KOReader plugin patch

This directory contains a small local patch to the BookOrbit KOReader plugin.
The patch is kept in a custom tag and copied into the k3s cluster through
`sync-to-k3s.sh`. The `bookorbit-app` deployment mounts the `bookorbit-koplugin`
PVC over `/app/koreader-plugin/bookorbit.koplugin`.

The repository remotes used by this workflow are:

```text
origin  git@github.com:mousi/bookorbit.git
upstream git@github.com:bookorbit/bookorbit.git
```

## Start a new custom tag

Run these commands from the repository root, not from this directory. Replace
the example tags with the last custom tag and the latest upstream release you
want to merge.

```bash
cd /Users/kostas/dev/bookorbit

git fetch origin --tags
git fetch upstream --tags

LAST_CUSTOM_TAG=v2.5.0-kostas
UPSTREAM_TAG=v2.6.0
CUSTOM_TAG=${UPSTREAM_TAG}-kostas
BRANCH="sync/${CUSTOM_TAG}"

# Start from the new upstream release.
git switch --detach "$UPSTREAM_TAG"
git switch -c "$BRANCH"

# Bring in the previous private patch.
git merge --no-edit "$LAST_CUSTOM_TAG"
```

If Git reports conflicts, resolve them while preserving the catalog sorting
changes, then finish the merge:

```bash
git add koreader-plugin/bookorbit.koplugin
git commit
```

Before tagging, inspect the resulting patch and verify that the intended
changes are still present:

```bash
git diff "$UPSTREAM_TAG" -- koreader-plugin/bookorbit.koplugin
git status
```

Create the custom tag, then remove the temporary branch as planned:

```bash
git tag -a "$CUSTOM_TAG" -m "BookOrbit $CUSTOM_TAG with persistent KOReader sorting"
git push origin "$CUSTOM_TAG"
git switch --detach "$CUSTOM_TAG"
git branch -D "$BRANCH"
```

The tag is pushed to your fork (`origin`) so it remains available when you
move between machines. Verify it remotely if needed:

```bash
git ls-remote --tags origin "$CUSTOM_TAG"
```

Do not reuse an upstream tag name. The custom suffix makes it clear which tag
contains the private patch.

## Sync the plugin to k3s

From this directory, run:

```bash
cd /Users/kostas/dev/bookorbit/koreader-plugin
./sync-to-k3s.sh
```

The script starts a short-lived `busybox` helper pod that mounts the
`bookorbit-koplugin` PVC, streams the local plugin into it with the Mac's `tar`
over `kubectl exec`, prints the synced `PLUGIN_VERSION`, and deletes the helper
pod. It does not depend on the app pod, so it also works while the app is down
or scaled to zero. Files removed upstream are also removed from the PVC.

The PVC lives on TrueNAS under `/mnt/storage/k8s-dynamic/`. Its NFS share maps
every write to `k3s:media`, so synced files keep the expected ownership without
SSH or sudo on TrueNAS.

The script does not restart the app. The server reads the plugin from disk on
each download, so a restart is only needed if the running process has cached
the package contents:

```bash
kubectl --context k3s-homelab -n bookorbit rollout restart deploy/bookorbit-app
```

## Optional checks

Confirm the files from the app pod after syncing:

```bash
kubectl --context k3s-homelab -n bookorbit exec deploy/bookorbit-app -- \
  ls -l /app/koreader-plugin/bookorbit.koplugin
```

The sync script accepts these environment overrides when the cluster changes:

```bash
KUBE_CONTEXT=k3s-homelab \
NAMESPACE=bookorbit \
PVC_NAME=bookorbit-koplugin \
HELPER_IMAGE=busybox:1.37 \
./sync-to-k3s.sh
```
