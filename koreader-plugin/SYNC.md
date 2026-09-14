# Maintaining the private KOReader plugin patch

This directory contains a small local patch to the BookOrbit KOReader plugin.
The patch is kept in a custom tag and copied to the Docker host through
`sync-to-docker-host.sh`. The Docker deployment must bind-mount the destination
directory over `/app/koreader-plugin/bookorbit.koplugin`.

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
CUSTOM_TAG=v2.6.0-kostas
BRANCH="sync/${CUSTOM_TAG}"

# Start from the previous private tag.
git switch --detach "$LAST_CUSTOM_TAG"
git switch -c "$BRANCH"

# Bring in the upstream release.
git merge --no-edit "$UPSTREAM_TAG"
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
git branch -D "$BRANCH"
git switch --detach "$CUSTOM_TAG"
```

The tag is pushed to your fork (`origin`) so it remains available when you
move between machines. Verify it remotely if needed:

```bash
git ls-remote --tags origin "$CUSTOM_TAG"
```

Do not reuse an upstream tag name. The custom suffix makes it clear which tag
contains the private patch.

## Sync the plugin to the Docker host

From this directory, run:

```bash
cd /Users/kostas/dev/bookorbit/koreader-plugin
./sync-to-docker-host.sh
```

The script synchronizes the local plugin to:

```text
kostas@10.0.3.3:/home/kostas/dev/docker/bookorbit/bookorbit.koplugin
```

It streams the local plugin with the Mac's `tar` over SSH, then extracts it on
the Docker host. No `rsync` installation is required on the Docker host. Files
removed upstream are also removed from the mounted Docker directory. The
script does not rebuild the Docker image or restart the container. A
bind-mounted plugin is visible to the running container immediately; restart
the `app` service only if the running process has already cached the package
contents:

```bash
ssh kostas@10.0.3.3 \
  'cd /home/kostas/dev/docker/bookorbit && docker compose restart app'
```

## Optional checks

Confirm the remote files after syncing:

```bash
ssh kostas@10.0.3.3 \
  'find /home/kostas/dev/docker/bookorbit/bookorbit.koplugin -maxdepth 1 -type f -print | sort'
```

Confirm that the plugin version in the synced source is the expected one:

```bash
ssh kostas@10.0.3.3 \
  "grep '^local PLUGIN_VERSION' /home/kostas/dev/docker/bookorbit/bookorbit.koplugin/main.lua"
```

The sync script accepts these environment overrides when the host or path
changes:

```bash
REMOTE_USER=kostas \
REMOTE_HOST=10.0.3.3 \
REMOTE_PLUGIN_DIR=/home/kostas/dev/docker/bookorbit/bookorbit.koplugin \
./sync-to-docker-host.sh
```
