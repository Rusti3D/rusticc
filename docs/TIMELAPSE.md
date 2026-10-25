# Timelapse: incomplete, disabled in the image

Status (2026-10-25): **not finished. The image does not enable it.** The code stays in the tree, so the work can
continue. The user decides when it ships.

## What exists

- **Moonruster component** (patch 0005, `src/components/timelapse.rs`): moonraker-timelapse c7fff11 ported to Rust.
  It has the same API (`/machine/timelapse/*`, the `timelapse_*` remote methods, `timelapse:timelapse_event`,
  settings in the `timelapse` database namespace), so Mainsail's Timelapse page works with it.
  - It loads only when moonraker.conf has a `[timelapse]` section.
  - Cost on the CC1: 0.43 MB of Moonruster's own memory while loaded (5.37 vs 4.94 MB, same binary).
- **Klipper macros:** `meta-rusticc/recipes-apps/klipper/files/timelapse.cfg`, the plugin's own, unchanged.
- **Config:** `meta-rusticc/recipes-apps/moonruster/files/timelapse.conf`.
  - Frames and videos go to /user-resource, because /tmp is RAM.
  - `saveframes: True` keeps each print's frames as a zip.
- **Webcam page panels:** `meta-rusticc/recipes-apps/mainsail/files/panel-extender/panels/timelapse/panel.js`,
  on the panel extender, which does ship.
  - Settings, plus a live frame count.
  - Each print's frames, with render, download and delete.
  - Videos, with play, download and delete.
- **Rendering happens in the browser:**
  - The frames are drawn on a canvas and recorded with MediaRecorder as MP4. WebCodecs can't be used, because it
    needs HTTPS.
  - The video is uploaded to the `timelapse` root together with its preview.
  - The printer has no ffmpeg. An H.264 render of 720p frames on the CC1 measured 36-50 MB peak, and with the
    plugin's default preset it ran the CC1 out of memory: Klipper shut down with "Timer too close".

## Tested

On the CC1, idle, with headless Edge 156:
- frames come from the real macro, with no parking;
- the 720p snapshots are 136 KB each;
- zips are written;
- 40-frame sets render into 1280x720 H.264 with every frame at 1/30 s (after the fixes in 12d520b);
- the upload and the preview work.

## To do before it ships

1. **A real print, end to end.** That means TIMELAPSE_TAKE_FRAME in the slicer's layer-change G-code, the zip saved
   at the end, and a render of a few hundred frames. Check the browser's memory with large zips: the whole zip is
   held in memory.
2. **Firefox.** Check what MediaRecorder records there. If it is WebM only, the panel downloads the video instead of
   uploading it, because Mainsail's Timelapse page lists .mp4 only. Also test a real, non-headless Chrome.
3. **Mainsail's own Timelapse page.** Its Render button calls the server's render, which reports
   "ffmpeg not found". Hide or redirect it, or remove that page's render controls.
4. **Hyperlapse mode** (time-based frames) is untested.
5. **Old frame zips pile up** on /user-resource: about 40 MB per 300-layer print. Add a retention limit, or delete
   a print's zip after it is rendered.
6. **Optional: render automatically** when a print ends while a Mainsail tab is open (the component's
   timelapse_event).
7. **Known, as in the Python plugin:** frame requests sent faster than about 2 s apart can time out (2 s wget
   timeout), and saving frames while snapshots are in flight can make the frame counter go negative.
   Real prints don't hit either.
8. **Panel layout** on phones.

## Enabling it again

Revert the three "Timelapse is disabled" blocks:
- `kalico_%.bbappend`: install `timelapse.cfg` into klipper-readonly;
- `moonraker_%.bbappend`: install `timelapse.conf` into moonraker-readonly, plus its FILES entry;
- `mainsail_%.bbappend`: install `panels/timelapse/panel.js` into /var/www/addons/panels/timelapse.
