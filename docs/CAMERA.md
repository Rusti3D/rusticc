# Camera: open issues

## Webcam stream fails on iPhone (open, 2026-10-25)

Mainsail's Webcam page shows "Error while connecting to http://192.168.1.148:8080/stream".

**Where it fails:** on the user's iPhone (iOS 18.7, Firefox 158, which runs on WebKit) at 192.168.1.142, on the
same Wi-Fi. The phone reaches the printer: its Mainsail websocket connects.

**Where it works:**
- from a PC (curl): HTTP 200, about 5.6 MB in 5 s, 9 fps;
- in headless Edge, desktop and Android emulation.

**Not known:** whether the phone worked before. It was never tested on COSMOS's 864x480 or on Rusticc's 720p.

**What Mainsail does:** its `mjpegstreamer` service reads the stream with fetch() in a Web Worker. On a failure it
shows this message and logs the reason to the browser console, so the real error is in the phone's console.

**Suspects:**
- WebKit's fetch() of multipart/x-mixed-replace;
- the 720p stream's size (136 KB frames, about 9 Mbit/s; ustreamer 1280x720 at 15 fps, camera-limited to 8-9).

**To do:**
1. Test on the iPhone at 864x480 (`-r 864x480 -f 10`). That tells us whether it is the resolution.
2. Get the console error, e.g. with Safari's Web Inspector over USB from a Mac.
3. Try Mainsail's `mjpegstreamer-adaptive` service, which polls snapshots and works without streaming fetch().
   It would be the camera's `service:` in moonraker-readonly.conf `[webcam webcam]`, or a Rusticc override.
4. Whatever fixes it, measure the CPU and memory of the camera service on the CC1 before shipping.
