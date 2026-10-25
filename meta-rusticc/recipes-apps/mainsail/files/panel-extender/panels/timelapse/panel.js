/*
 * Rusticc timelapse panels for Mainsail's Webcam page (panel extender,
 * `page`). Moonruster's timelapse component captures one JPEG per layer and
 * keeps each print's frames as a zip (saveframes); the printer has no
 * ffmpeg (an H.264 render needs more RAM than the CC1 can spare), so videos
 * are rendered here, in the browser: the frames are drawn on a canvas and
 * recorded with MediaRecorder (WebCodecs needs HTTPS, the printer serves
 * HTTP), with the component's own render settings, then uploaded to the
 * "timelapse" root with the last frame as preview, as the component's
 * ffmpeg render would. Mainsail's Timelapse page lists them too.
 */
;(function () {
    'use strict'
    var P = window.CosmosPanels
    if (!P) return

    // mdi-timelapse, mdi-filmstrip, mdi-refresh (@mdi/js 7.4.47)
    var ICON_TL =
        'M12,20A8,8 0 0,1 4,12A8,8 0 0,1 12,4A8,8 0 0,1 20,12A8,8 0 0,1 12,20' +
        'M12,2A10,10 0 0,0 2,12A10,10 0 0,0 12,22A10,10 0 0,0 22,12A10,10 0 0' +
        ',0 12,2M16.24,7.76C15.07,6.58 13.53,6 12,6V12L7.76,16.24C10.1,18.58 ' +
        '13.9,18.58 16.24,16.24C18.59,13.9 18.59,10.1 16.24,7.76Z'
    var ICON_VIDEOS =
        'M18,9H16V7H18M18,13H16V11H18M18,17H16V15H18M8,9H6V7H8M8,13H6V11H8M8,' +
        '17H6V15H8M18,3V5H16V3H8V5H6V3H4V21H6V19H8V21H16V19H18V21H20V3H18Z'
    var ICON_REFRESH =
        'M17.65,6.35C16.2,4.9 14.21,4 12,4A8,8 0 0,0 4,12A8,8 0 0,0 12,20C15.' +
        '73,20 18.84,17.45 19.73,14H17.65C16.83,16.33 14.61,18 12,18A6,6 0 0,' +
        '1 6,12A6,6 0 0,1 12,6C13.66,6 15.14,6.69 16.22,7.78L13,11H20V4L17.65' +
        ',6.35Z'

    var MODES = [['layermacro', 'One frame per layer'], ['hyperlapse', 'Every few seconds (hyperlapse)']]

    function api(path, opts) {
        return fetch(path, opts).then(function (r) {
            if (!r.ok) throw new Error(path.split('?')[0] + ': HTTP ' + r.status)
            return r
        })
    }
    function result(path, opts) {
        return api(path, opts).then(function (r) { return r.json() }).then(function (j) { return j.result })
    }
    function fileUrl(root, path) {
        return '/server/files/' + root + '/' + path.split('/').map(encodeURIComponent).join('/')
    }
    function el(tag, attrs, children) {
        var e = document.createElement(tag)
        for (var k in attrs || {}) {
            if (k === 'text') e.textContent = attrs[k]
            else if (k === 'style') e.style.cssText = attrs[k]
            else if (k.slice(0, 2) === 'on') e.addEventListener(k.slice(2), attrs[k])
            else e.setAttribute(k, attrs[k])
        }
        ;(children || []).forEach(function (c) { if (c != null) e.appendChild(typeof c === 'string' ? document.createTextNode(c) : c) })
        return e
    }
    function mb(n) { return (n / 1048576).toFixed(1) + ' MB' }
    // timelapse_<gcode file>_<date>[_frames].zip / .mp4 -> the print's name
    function printName(path) {
        var base = path.split('/').pop().replace(/(_frames)?\.(zip|mp4|webm)$/, '').replace(/^timelapse_/, '')
        var m = base.match(/^(.*)_(\d{8}_\d{4,6})$/)
        var name = (m ? m[1] : base).replace(/\.gcode$/i, '')
        return name || 'Untitled print'
    }
    function when(t) { return new Date(t * 1000).toLocaleString() }
    function btn(label, onclick, primary) {
        return el('button', {
            type: 'button', text: label, onclick: onclick,
            style: 'margin-left:6px;padding:3px 10px;border-radius:4px;cursor:pointer;font:inherit;font-size:13px;' +
                (primary ? 'background:var(--v-primary-base,#b7410e);color:#fff;border:0' :
                    'background:transparent;color:inherit;border:1px solid rgba(128,128,128,.6)'),
        })
    }
    function muted(text) { return el('div', { text: text, style: 'opacity:.7;font-size:13px' }) }

    /* -------------------------------------------------------------- */
    /* Timelapse settings and status                                  */
    /* -------------------------------------------------------------- */

    P.register({
        id: 'rusticc-timelapse',
        title: 'Timelapse',
        icon: ICON_TL,
        page: '/cam',
        mount: function (root) {
            var cfg = null, timer = null
            var status = el('div', { style: 'margin-bottom:10px' })
            var form = el('div')
            root.appendChild(status)
            root.appendChild(form)
            root.appendChild(muted('A frame per layer needs TIMELAPSE_TAKE_FRAME in the slicer\'s layer change G-code ' +
                '(OrcaSlicer / ElegooSlicer: Printer settings > Machine G-code > Time lapse G-code). ' +
                'Each print\'s frames are kept as a zip below, ready to render.'))

            function blocked(k) { return (cfg.blockedsettings || []).indexOf(k) >= 0 }
            function save(key, value) {
                return result('/machine/timelapse/settings?' + encodeURIComponent(key) + '=' + encodeURIComponent(value), { method: 'POST' })
                    .then(function (c) { cfg = c; draw() })
                    .catch(function (e) { status.textContent = 'Saving failed: ' + e.message })
            }
            function row(label, input) {
                return el('label', { style: 'display:flex;align-items:center;gap:10px;margin:6px 0' }, [
                    el('span', { text: label, style: 'min-width:150px' }), input])
            }
            function draw() {
                form.textContent = ''
                var en = el('input', { type: 'checkbox' })
                en.checked = !!cfg.enabled
                en.disabled = blocked('enabled')
                en.addEventListener('change', function () { save('enabled', en.checked) })
                form.appendChild(row('Capture frames', en))
                var mode = el('select', { style: 'background:transparent;color:inherit;border:1px solid rgba(128,128,128,.6);border-radius:4px;padding:2px 4px' })
                MODES.forEach(function (m) {
                    var o = el('option', { value: m[0], text: m[1] })
                    o.style.color = '#000'
                    if (cfg.mode === m[0]) o.selected = true
                    mode.appendChild(o)
                })
                mode.disabled = blocked('mode')
                mode.addEventListener('change', function () { save('mode', mode.value) })
                form.appendChild(row('Mode', mode))
                if (cfg.mode === 'hyperlapse') {
                    var cyc = el('input', { type: 'number', min: '2', step: '1', style: 'width:80px;background:transparent;color:inherit;border:1px solid rgba(128,128,128,.6);border-radius:4px;padding:2px 4px' })
                    cyc.value = cfg.hyperlapse_cycle
                    cyc.disabled = blocked('hyperlapse_cycle')
                    cyc.addEventListener('change', function () { save('hyperlapse_cycle', parseInt(cyc.value, 10) || 30) })
                    form.appendChild(row('Seconds per frame', cyc))
                }
                var fps = el('input', { type: 'number', min: '1', max: '60', step: '1', style: 'width:80px;background:transparent;color:inherit;border:1px solid rgba(128,128,128,.6);border-radius:4px;padding:2px 4px' })
                fps.value = cfg.output_framerate
                fps.disabled = blocked('output_framerate')
                fps.addEventListener('change', function () { save('output_framerate', parseInt(fps.value, 10) || 30) })
                form.appendChild(row('Video frame rate', fps))
            }
            function poll() {
                result('/machine/timelapse/lastframeinfo').then(function (i) {
                    status.textContent = cfg && !cfg.enabled ? 'Frame capture is off.' :
                        i.framecount ? i.framecount + ' frames captured in the current print.' : 'No frames captured in the current print yet.'
                }).catch(function () {})
            }
            result('/machine/timelapse/settings').then(function (c) {
                cfg = c
                draw()
                poll()
                timer = setInterval(poll, 5000)
            }).catch(function (e) {
                status.textContent = 'Timelapse is not available: ' + e.message
            })
            root._tlStop = function () { clearInterval(timer) }
        },
        unmount: function (root) { if (root._tlStop) root._tlStop() },
    })

    /* -------------------------------------------------------------- */
    /* Frames and videos: render in the browser, download, delete     */
    /* -------------------------------------------------------------- */

    // A stored (uncompressed) zip, as the timelapse component writes: its
    // JPEG entries from the central directory, in name order
    function zipEntries(buf) {
        var v = new DataView(buf), eocd = -1
        for (var i = buf.byteLength - 22; i >= Math.max(0, buf.byteLength - 65557); i--) {
            if (v.getUint32(i, true) === 0x06054b50) { eocd = i; break }
        }
        if (eocd < 0) throw new Error('not a zip file')
        var count = v.getUint16(eocd + 10, true), p = v.getUint32(eocd + 16, true)
        var dec = new TextDecoder(), out = []
        for (var n = 0; n < count; n++) {
            if (v.getUint32(p, true) !== 0x02014b50) throw new Error('bad zip directory')
            var method = v.getUint16(p + 10, true), size = v.getUint32(p + 20, true)
            var nameLen = v.getUint16(p + 28, true), extraLen = v.getUint16(p + 30, true), commentLen = v.getUint16(p + 32, true)
            var local = v.getUint32(p + 42, true)
            var name = dec.decode(new Uint8Array(buf, p + 46, nameLen))
            if (method !== 0) throw new Error(name + ': compressed zip entries are not supported')
            var data = local + 30 + v.getUint16(local + 26, true) + v.getUint16(local + 28, true)
            if (/\.jpe?g$/i.test(name)) out.push({ name: name, data: new Uint8Array(buf, data, size) })
            p += 46 + nameLen + extraLen + commentLen
        }
        out.sort(function (a, b) { return a.name < b.name ? -1 : 1 })
        return out.map(function (f) {
            return { name: f.name, blob: function () { return Promise.resolve(new Blob([f.data], { type: 'image/jpeg' })) } }
        })
    }

    // Timers for the recording: a worker's, which a background tab does not
    // throttle to once a second as it does the page's (that would stretch
    // every frame of the video to a second)
    var sleeper = null
    function sleep(ms) {
        if (!sleeper) {
            try {
                sleeper = { w: new Worker(URL.createObjectURL(new Blob(['onmessage=function(e){setTimeout(function(){postMessage(e.data[0])},e.data[1])}'], { type: 'text/javascript' }))), n: 0, cb: {} }
                sleeper.w.onmessage = function (e) { var f = sleeper.cb[e.data]; delete sleeper.cb[e.data]; f() }
            } catch (e) { sleeper = false }
        }
        if (!sleeper) return new Promise(function (r) { setTimeout(r, ms) })
        return new Promise(function (r) { var id = ++sleeper.n; sleeper.cb[id] = r; sleeper.w.postMessage([id, ms]) })
    }

    // MP4 first: Mainsail's timelapse page lists only .mp4 and .zip
    function recordType() {
        var types = ['video/mp4;codecs=avc1.640028', 'video/mp4;codecs=avc1', 'video/mp4', 'video/webm;codecs=vp9', 'video/webm']
        for (var i = 0; i < types.length; i++) {
            if (window.MediaRecorder && MediaRecorder.isTypeSupported(types[i])) return types[i]
        }
        return null
    }

    // Records frames into a video with the component's render settings
    // (frame rate or variable fps, duplicated last frame, rotation, flips);
    // one frame per 1/fps second of wall clock, as the recorder timestamps
    function record(frames, cfg, canvas, onProgress) {
        var type = recordType()
        if (!type) return Promise.reject(new Error('this browser cannot record video'))
        var dup = Math.max(0, cfg.duplicatelastframe | 0)
        var total = frames.length + dup
        var fps = cfg.output_framerate
        if (cfg.variable_fps) fps = Math.max(Math.min(Math.trunc(total / cfg.targetlength), cfg.variable_fps_max), cfg.variable_fps_min)
        fps = Math.max(1, Number(fps) || 30)
        var rot = (((Number(cfg.rotation) || 0) % 360) + 360) % 360
        var ctx = canvas.getContext('2d')
        function draw(img) {
            ctx.save()
            ctx.translate(canvas.width / 2, canvas.height / 2)
            ctx.rotate((rot * Math.PI) / 180)
            ctx.scale(cfg.flip_x ? -1 : 1, cfg.flip_y ? -1 : 1)
            ctx.drawImage(img, -img.width / 2, -img.height / 2)
            ctx.restore()
        }
        var decode = function (f) { return f.blob().then(function (b) { return createImageBitmap(b) }) }
        return decode(frames[0]).then(function (first) {
            var swap = rot === 90 || rot === 270
            canvas.width = swap ? first.height : first.width
            canvas.height = swap ? first.width : first.height
            var stream = canvas.captureStream(0), track = stream.getVideoTracks()[0]
            var rec = new MediaRecorder(stream, { mimeType: type, videoBitsPerSecond: Math.round(canvas.width * canvas.height * fps * 0.2) })
            var chunks = []
            rec.ondataavailable = function (e) { if (e.data.size) chunks.push(e.data) }
            var stopped = new Promise(function (res) { rec.onstop = res })
            // recording first: a frame is captured only when requestFrame
            // finds the canvas changed, so frame 1 is drawn in the loop
            rec.start(1000)
            // decoded frames 4 ahead, so a slow decode doesn't stall the
            // timeline; a late tick moves the timeline on rather than
            // sending a burst, which the recorder would merge into one frame
            var step = 1000 / fps, img = first, i = 0, at = performance.now()
            // the encoder hiccups once a third of a second in (measured:
            // ~7 frames merged), so the video opens on its first frame for
            // a second, as it closes on its last: the hiccup only merges
            // copies of it
            var pre = Math.ceil(fps), held = 0
            var ahead = [], nextDecode = 1
            function fill() {
                while (ahead.length < 4 && nextDecode < frames.length) ahead.push(decode(frames[nextDecode++]))
            }
            fill()
            function tick() {
                if (i >= total) {
                    return sleep(step).then(function () {
                        rec.stop()
                        return stopped
                    }).then(function () {
                        return { blob: new Blob(chunks, { type: type.split(';')[0] }), ext: type.indexOf('video/mp4') === 0 ? 'mp4' : 'webm', draw: draw }
                    })
                }
                var ready = Promise.resolve()
                if (held < pre) {
                    held++
                    return sleep(Math.max(0, (at += step) - performance.now())).then(function () {
                        draw(img)
                        ctx.fillStyle = 'rgba(' + (held % 2) + ',0,0,1)'
                        ctx.fillRect(0, 0, 1, 1)
                        track.requestFrame()
                        return tick()
                    })
                }
                if (i > 0 && i < frames.length) {
                    ready = ahead.shift().then(function (b) {
                        img.close()
                        img = b
                        fill()
                    })
                }
                return ready.then(function () {
                    at = Math.max(at + (i ? step : 0), performance.now())
                    return sleep(Math.max(0, at - performance.now()))
                }).then(function () {
                    draw(img)
                    // an unchanged canvas yields no frame: the held last frame
                    // (duplicatelastframe) gets a one-step change in a corner pixel
                    if (i >= frames.length) {
                        ctx.fillStyle = 'rgba(' + (i % 2) + ',0,0,1)'
                        ctx.fillRect(0, 0, 1, 1)
                    }
                    track.requestFrame()
                    i++
                    onProgress(i, total, fps)
                    return tick()
                })
            }
            return tick()
        })
    }

    function upload(blob, name) {
        var fd = new FormData()
        fd.append('root', 'timelapse')
        fd.append('file', blob, name)
        return api('/server/files/upload', { method: 'POST', body: fd })
    }
    function remove(root, path) {
        return api(fileUrl(root, path), { method: 'DELETE' })
    }

    P.register({
        id: 'rusticc-timelapse-videos',
        title: 'Timelapse Videos',
        icon: ICON_VIDEOS,
        page: '/cam',
        buttons: [{ icon: ICON_REFRESH, onClick: function () { if (window._rusticcTlRefresh) window._rusticcTlRefresh() } }],
        mount: function (root) {
            var busy = false
            var framesBox = el('div'), videosBox = el('div'), work = el('div', { style: 'display:none;margin:10px 0' })
            var statusLine = el('div', { style: 'margin-bottom:6px' })
            var bar = el('progress', { max: '1', value: '0', style: 'width:100%;height:10px;accent-color:var(--v-primary-base,#b7410e)' })
            var canvas = el('canvas', { style: 'display:block;max-width:100%;max-height:240px;margin-top:8px;border-radius:4px;background:#000' })
            work.appendChild(statusLine); work.appendChild(bar); work.appendChild(canvas)
            var player = el('div', { style: 'display:none;margin:10px 0' })
            root.appendChild(el('div', { text: 'Frames', style: 'font-weight:500;margin-bottom:4px' }))
            root.appendChild(framesBox)
            root.appendChild(work)
            root.appendChild(el('div', { text: 'Videos', style: 'font-weight:500;margin:14px 0 4px' }))
            root.appendChild(player)
            root.appendChild(videosBox)
            if (!recordType()) root.appendChild(muted('This browser cannot record video, so rendering is unavailable here.'))

            function line(label, info, buttons) {
                return el('div', { style: 'display:flex;align-items:center;flex-wrap:wrap;gap:4px;padding:6px 0;border-bottom:1px solid rgba(128,128,128,.25)' }, [
                    el('div', { style: 'flex:1 1 220px;min-width:0;overflow-wrap:anywhere' }, [el('div', { text: label }), muted(info)]),
                    el('div', { style: 'white-space:nowrap' }, buttons)])
            }
            function download(root, path) {
                var a = el('a', { href: fileUrl(root, path), download: path.split('/').pop() })
                document.body.appendChild(a); a.click(); a.remove()
            }
            function confirmDelete(root, path) {
                if (busy || !window.confirm('Delete ' + path.split('/').pop() + '?')) return
                var jobs = [remove(root, path)]
                if (/\.mp4$/.test(path)) jobs.push(remove(root, path.replace(/\.mp4$/, '.jpg')).catch(function () {}))
                Promise.all(jobs).then(refresh).catch(function (e) { window.alert('Delete failed: ' + e.message) })
            }

            function render(src) {
                if (busy) return
                busy = true
                work.style.display = ''
                bar.value = 0
                statusLine.textContent = 'Preparing...'
                var cfg, name, frames
                result('/machine/timelapse/settings').then(function (c) {
                    cfg = c
                    if (src.zip) {
                        statusLine.textContent = 'Downloading ' + src.zip + '...'
                        name = src.zip.replace(/_frames\.zip$/, '').split('/').pop()
                        return api(fileUrl('timelapse', src.zip)).then(function (r) { return r.arrayBuffer() }).then(zipEntries)
                    }
                    // named as the component names its renders: timelapse_<file>_<date>
                    var d = new Date(), z = function (n) { return (n < 10 ? '0' : '') + n }
                    var stamp = d.getFullYear() + z(d.getMonth() + 1) + z(d.getDate()) + '_' + z(d.getHours()) + z(d.getMinutes())
                    return result('/printer/objects/query?print_stats').then(function (r) {
                        return r.status.print_stats.filename || ''
                    }).catch(function () { return '' }).then(function (file) {
                        name = 'timelapse_' + file.split('/').pop() + '_' + stamp
                        return src.files.map(function (p) {
                            return { name: p, blob: function () { return api(fileUrl('timelapse_frames', p)).then(function (r) { return r.blob() }) } }
                        })
                    })
                }).then(function (f) {
                    frames = f
                    if (!frames.length) throw new Error('no frames')
                    return record(frames, cfg, canvas, function (i, total, fps) {
                        bar.max = total; bar.value = i
                        statusLine.textContent = 'Recording frame ' + i + ' of ' + total + ' at ' + fps + ' fps...'
                    })
                }).then(function (out) {
                    var file = name + '.' + out.ext
                    if (out.ext !== 'mp4') {
                        statusLine.textContent = 'This browser records WebM only, which Mainsail\'s timelapse page does not list: downloading it instead.'
                        var a = el('a', { href: URL.createObjectURL(out.blob), download: file })
                        document.body.appendChild(a); a.click(); a.remove()
                        return
                    }
                    statusLine.textContent = 'Uploading ' + file + ' (' + mb(out.blob.size) + ')...'
                    return upload(out.blob, file).then(function () {
                        if (!cfg.previewimage) return
                        // the preview the component makes: the last frame, rotated as the video
                        return frames[frames.length - 1].blob().then(function (b) {
                            if (!(Number(cfg.rotation) || cfg.flip_x || cfg.flip_y)) return b
                            return createImageBitmap(b).then(function (img) {
                                out.draw(img)
                                return new Promise(function (r) { canvas.toBlob(r, 'image/jpeg', 0.9) })
                            })
                        }).then(function (jpg) { return upload(jpg, name + '.jpg') })
                    }).then(function () {
                        statusLine.textContent = 'Saved ' + file + '.'
                    })
                }).catch(function (e) {
                    statusLine.textContent = 'Render failed: ' + e.message
                }).then(function () {
                    busy = false
                    refresh()
                })
            }

            function refresh() {
                Promise.all([
                    result('/server/files/list?root=timelapse').catch(function () { return [] }),
                    result('/server/files/list?root=timelapse_frames').catch(function () { return [] }),
                ]).then(function (r) {
                    var files = r[0], current = r[1].filter(function (f) { return /^frame\d+\.jpg$/.test(f.path) })
                    var zips = files.filter(function (f) { return /_frames\.zip$/.test(f.path) }).sort(function (a, b) { return b.modified - a.modified })
                    var videos = files.filter(function (f) { return /\.(mp4|webm)$/.test(f.path) }).sort(function (a, b) { return b.modified - a.modified })
                    framesBox.textContent = ''
                    // the last print's frames stay until the next print starts:
                    // once saved as a zip they are listed by that
                    var newestFrame = Math.max.apply(null, current.map(function (f) { return f.modified }).concat([0]))
                    var saved = zips.some(function (z) { return z.modified >= newestFrame })
                    if (current.length && !saved) {
                        var paths = current.map(function (f) { return f.path }).sort()
                        framesBox.appendChild(line('Current print', current.length + ' frames so far', [
                            btn('Render', function () { render({ files: paths }) }, true)]))
                    }
                    zips.forEach(function (z) {
                        framesBox.appendChild(line(printName(z.path), mb(z.size) + ', ' + when(z.modified), [
                            btn('Render', function () { render({ zip: z.path }) }, true),
                            btn('Download', function () { download('timelapse', z.path) }),
                            btn('Delete', function () { confirmDelete('timelapse', z.path) })]))
                    })
                    if (!framesBox.firstChild) framesBox.appendChild(muted('No frames yet: they are captured while printing with frame capture on.'))
                    videosBox.textContent = ''
                    videos.forEach(function (v) {
                        videosBox.appendChild(line(printName(v.path), mb(v.size) + ', ' + when(v.modified), [
                            btn('Play', function () {
                                player.textContent = ''
                                player.appendChild(el('video', { src: fileUrl('timelapse', v.path), controls: '', autoplay: '', style: 'width:100%;max-height:420px;border-radius:4px;background:#000' }))
                                player.style.display = ''
                            }),
                            btn('Download', function () { download('timelapse', v.path) }),
                            btn('Delete', function () { confirmDelete('timelapse', v.path) })]))
                    })
                    if (!videosBox.firstChild) videosBox.appendChild(muted('No videos yet.'))
                })
            }
            window._rusticcTlRefresh = refresh
            refresh()
        },
        unmount: function () { window._rusticcTlRefresh = null },
    })
})()
