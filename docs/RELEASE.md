# Releasing Rusticc

What a Rusticc release must look like for printers to find and install it. The conventions are COSMOS's
(`cosmos/.github/workflows/build.yml`, `push.yml`), because Rusticc keeps COSMOS's updater scripts and only points
them at this repository (meta-rusticc's check-update, update-scripts and config-manager bbappends).

## The conventions the printer relies on

| | stable channel | nightly channel (`release = nightly` in cosmos.conf) |
|---|---|---|
| version (`DISTRO_VERSION`, the image's `/etc/issue`, `swu_version`) | the release tag | the first 10 characters of the commit |
| where `update-cosmos` downloads | `releases/latest/download/<asset>` | `releases/download/0.0.0/<asset>` (a prerelease whose tag CI moves to the build's commit) |
| how `check-update` decides | latest non-prerelease tag != version | latest commit on the default branch does not start with version |
| asset names | `cosmos-centauri-carbon-1.swu`, `cosmos-centauri-carbon-2.swu` (COSMOS's names: the scripts use them) | same |

Moonraker's update panel (Moonruster's swupdate updater, entry `[update_manager rusticc]`, written at each klipper
start by `build-klipper-var-config`) reads the same repository and asset name.

## Building the image

- Yocto, as COSMOS: `. ./rusticc-init-build-env; bitbake cosmos` gives
  `build/tmp/deploy/images/<machine>/cosmos-<machine>.swu`. Set the version first, as COSMOS's CI does:
  `sed -i -E 's/^DISTRO_VERSION = ".*"/DISTRO_VERSION = "<version>"/' meta-rusticc/conf/distro/rusticc.conf`.
  COSMOS builds on a self-hosted runner with a persistent download and sstate cache (`runs-on: self-hosted`,
  `/data/cache`); a Rusticc CI needs the same kind of machine.
- Local repack (no Yocto, CC1 only): `work/repack/repack.sh` (see NOTES "Rusticc as an installed image") from a
  dump of a running COSMOS slot; its version defaults to this repository's 10-character commit.

Either way the image is signed with COSMOS's published swupdate key, which every COSMOS printer trusts
(`/etc/swupdate_public.pem`), and its root filesystem is packed with lz4hc to fit the 134.3 MB root slot.

## Checks before publishing

- `tools/case_cmp.sh` over Kalico's tests, kaliru's cases and `cases/` (Rusticc's), `tools/cc1_cmp.sh`, kaliru's
  `tools/plugin_cmp.sh` (AFC): identical to the COSMOS reference.
- The image on a printer: boots the new slot, bed and toolhead flashed (their `.ver` files), klippy ready
  (`App Name: Rusticc` in klippy.log), Moonruster serving, `check-update` reports no update for its own version.
