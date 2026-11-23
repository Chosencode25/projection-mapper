enum PhonePage {
    static let html = """
    <!doctype html>
    <html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
    <title>Projection Mapper Remote</title><link rel="stylesheet" href="/remote.css"><script defer src="/remote.js"></script></head>
    <body><main>
    <h1>Projection Mapper</h1>
    <p id="status" role="status">Pair on the Mac to continue.</p>
    <form id="pair"><label>Invitation <input id="code" required autocomplete="off"></label><button>Request Access</button></form>
    <section id="remote" hidden>
      <h2 id="project"></h2><p id="connection"></p>
      <div class="clock" id="time"></div><p id="next"></p><p id="output"></p><p id="showState"></p>
      <div id="operator" hidden>
        <div class="actions">
          <button data-action="play" class="primary">Play</button><button data-action="pause">Pause</button>
          <button data-action="stop">Stop</button><button data-action="go">GO</button>
        </div>
        <form id="seek"><label>Seek to seconds <input id="seekTime" type="number" min="0" max="3600" step=".01" required></label><button>Seek</button></form>
        <div class="actions"><button id="projection"></button><button id="fixtures"></button><button id="mute"></button></div>
      </div>
      <div id="readinessPanel" hidden><button data-action="readiness">Check Readiness</button><p id="readiness"></p></div>
      <details id="previewPanel"><summary>Mac Preview</summary>
        <div class="actions"><button id="previewToggle">Start Preview</button></div>
        <img id="macPreview" alt="Projection preview captured on the Mac" hidden>
        <p id="previewInfo" class="small">Snapshots reflect the Mac’s show clock.</p>
      </details>
      <details id="timelinePanel"><summary>Timeline &amp; Lighting Cues</summary>
        <div class="actions">
          <button id="timelineBack" aria-label="Previous time range">− Time</button>
          <button id="timelineNow">Playhead</button>
          <button id="timelineNext" aria-label="Next time range">+ Time</button>
          <label>View <select id="timelineSpan"><option value="10">10 s</option><option value="30" selected>30 s</option><option value="60">60 s</option><option value="120">120 s</option></select></label>
        </div>
        <div class="actions"><button id="trackBack">Previous Tracks</button><button id="trackNext">Next Tracks</button>
          <span id="trackPage" class="small"></span><label><input id="timelineSnap" type="checkbox" checked> Snap to 0.5 s</label>
        </div>
        <p id="timelineInfo" class="small"></p>
        <canvas id="phoneTimeline" width="680" height="120" aria-label="Timeline. Use the clip and cue controls below for accessible editing."></canvas>
        <fieldset id="timelineEdit">
          <label>Clip <select id="clipChoice"></select></label>
          <div id="clipFields" hidden>
            <div class="timeFields">
              <label>Start <input id="clipStart" type="number" min="0" max="3600" step="any"></label>
              <label>End <input id="clipEnd" type="number" min="0" max="3600" step="any"></label>
            </div>
            <div class="actions"><button id="clipMove">Move to Start</button><button id="clipTrim">Apply Trim</button></div>
            <div id="sourceFields" hidden>
              <div class="timeFields"><label>Source in <input id="sourceIn" type="number" min="0" max="86400" step="any"></label>
                <label>Source out <input id="sourceOut" type="number" min="0" max="86400" step="any"></label></div>
              <button id="sourceApply">Apply Source Range</button>
            </div>
          </div>
          <label>Lighting cue <select id="cueChoice"></select></label>
          <div id="cueFields" hidden>
            <label>Cue time <input id="cueTime" type="number" min="0" max="3600" step="any"></label>
            <div class="actions"><button id="cueSelect">Select on Mac</button><button id="cueApply">Apply Cue Time</button></div>
          </div>
        </fieldset>
      </details>
      <details><summary>Fixture status</summary><ul id="fixtureList"></ul></details>
      <section id="editor" hidden>
        <h2>Mapping</h2><p id="lock"></p>
        <fieldset id="editing">
          <label>Surface <select id="face"></select></label>
          <label>View <select id="mode"><option value="corner">Corners</option><option value="mask">Face mask</option></select></label>
          <label>Zoom <input id="zoom" type="range" min="1" max="3" step=".25" value="1"></label>
          <div id="diagram"><canvas id="map" width="600" height="380" aria-label="Drag a mapping point"></canvas></div>
          <div id="mappingControls" class="actions">
            <label>Point <select id="point"></select></label>
            <button data-nudge="0,-1" aria-label="Nudge up">↑</button><button data-nudge="-1,0" aria-label="Nudge left">←</button>
            <button data-nudge="1,0" aria-label="Nudge right">→</button><button data-nudge="0,1" aria-label="Nudge down">↓</button>
          </div>
          <div id="maskTools" hidden>
            <label>Mask rings in face coordinates <textarea id="rings" rows="4"></textarea></label>
            <div class="actions"><button id="addHole">Add Hole</button><button id="applyMask">Apply Mask</button></div>
          </div>
          <div class="actions"><button data-action="identify">Identify</button><button data-action="finish">Finish</button></div>
          <label>Effect <select id="effect"></select></label>
          <label>Effect rate <input id="rate" type="number" min=".25" max="4" step=".05"></label>
          <details><summary>More effect settings</summary>
            <label>Scale <input id="scale" type="number" min=".5" max="4" step=".05"></label>
            <label>Intensity <input id="intensity" type="number" min=".1" max="1" step=".05"></label>
          </details>
          <label>Color <input id="color" type="color"></label><label>Palette color <select id="palette"></select></label>
          <label>Master brightness <input id="brightness" type="range" min="0" max="1" step=".01"></label>
          <div class="actions"><button data-action="undo">Undo</button><button data-action="redo">Redo</button><button data-action="save">Save</button></div>
          <p id="saveStatus"></p>
        </fieldset>
      </section>
    </section>
    </main></body></html>
    """

    static let css = """
    :root { color-scheme:dark; font-family:system-ui,sans-serif; background:#14151a; color:#f4f2ff }
    main { max-width:42rem; margin:auto; padding:1rem }
    h1 { font-size:1.45rem; margin:.4rem 0 } h2 { font-size:1.15rem }
    p { color:#ccc8db; margin:.65rem 0 } section,details { margin-block:1rem }
    button,input,select,textarea { font:inherit; color:inherit; border:1px solid #595666; border-radius:.5rem; background:#24252d; padding:.55rem }
    button { min-height:44px } button:disabled,fieldset:disabled { opacity:.55 }
    button.primary { background:#51419d } button:focus-visible { outline:2px solid #b9aaff }
    label { display:flex; flex-wrap:wrap; align-items:center; justify-content:space-between; gap:.5rem; margin:.4rem 0 }
    input:not([type=color]),select,textarea { max-width:100%; min-width:5rem } textarea { width:100% }
    .actions,form { display:flex; flex-wrap:wrap; gap:.45rem; align-items:center; margin:.55rem 0 }
    .clock { font:2rem ui-monospace,monospace; color:#c2afff }
    fieldset { border:1px solid #3d3b49; padding:.7rem; border-radius:.7rem; min-width:0 }
    canvas { display:block; width:100%; touch-action:none; background:#191924; border-radius:.4rem }
    #macPreview { display:block; width:100%; max-width:480px; height:auto; border-radius:.4rem; background:#181823 }
    #phoneTimeline { touch-action:none; margin-bottom:.65rem }
    #timelineEdit { margin-top:.45rem }
    #timelineSnap { min-width:unset }
    .timeFields { display:flex; flex-wrap:wrap; gap:.6rem }
    .timeFields input { width:7rem }
    .small { font-size:.86rem; color:#c2bdcf }
    details { margin:.6rem 0 }
    summary { min-height:30px; cursor:pointer }
    #status { min-height:1.3em } [hidden] { display:none !important }
    """

    static let script = #"""
    'use strict';
    const el = id => document.getElementById(id);
    let token = '', sequence = 0, state = null, busy = false, drag = null;
    let updating = false, stateEpoch = 0, lastEditorKey = '';
    const canvas = el('map'), ctx = canvas.getContext('2d');
    const defaultRings = [[[0,0],[1,0],[1,1],[0,1]]];
    const face = () => state?.faces?.find(item => item.id === el('face').value);
    const clamp = value => Math.min(1, Math.max(0, value));
    const message = text => { el('status').textContent = text; };
    const clone = value => JSON.parse(JSON.stringify(value));

    async function api(path, payload) {
      const headers = {'Content-Type':'application/json'};
      if (token) headers.Authorization = 'Bearer ' + token;
      const response = await fetch(path, {method:'POST', headers, body:JSON.stringify(payload), signal:AbortSignal.timeout(4500)});
      const result = await response.json();
      if (!response.ok) {
        if (response.status === 401) {
          token = ''; drag = null; clearTimeline(); stopPreview(); state = null; el('remote').hidden = true; el('pair').hidden = false;
        }
        if (result.state) render(result.state);
        throw Error(result.error || 'Request failed.');
      }
      return result;
    }
    async function pair(code) {
      if (!code || busy) return;
      busy = true;
      try {
        token = (await api('/pair',{code})).token;
        sequence = 0;
        el('pair').hidden = true;
        message('Approve this phone on the Mac.');
      } catch (error) { message(error.message); }
      finally { busy = false; }
    }
    async function refresh() {
      if (!token || updating || busy || document.hidden) return;
      updating = true;
      const epoch = stateEpoch;
      try {
        const next = await api('/state',{});
        if (epoch !== stateEpoch) return;
        if (next.pending) message('Approve this phone on the Mac.');
        else { render(next); if (el('status').dataset.disconnected) { message('Connected'); delete el('status').dataset.disconnected; } }
      } catch (error) {
        el('status').dataset.disconnected = '1';
        el('remote').hidden = true;
        drag = null;
        clearTimeline();
        clearPreviewFrame();
        message(error.message);
      } finally { updating = false; }
    }
    async function command(action, extra = {}, baseline = state) {
      if (!state || !baseline || busy) return;
      busy = true;
      stateEpoch += 1;
      try {
        const next = await api('/command',{
          action, sequence:++sequence, projectID:baseline.projectID, revision:baseline.revision,
          face:face()?.id, ...extra
        });
        render(next);
        message(action === 'save' ? next.saveStatus : 'Applied on Mac');
      } catch (error) { message(error.message); }
      finally { busy = false; }
    }
    function options(select, items, value) {
      const previous = value ?? select.value;
      select.replaceChildren(...items.map(item => new Option(item.name,item.id)));
      if (items.some(item => item.id === previous)) select.value = previous;
    }
    function render(next) {
      const first = !state;
      if (drag && (drag.base.projectID !== next.projectID || next.workspace !== 'Edit' || next.role !== 'Editor')) drag = null;
      const previous = state;
      state = next;
      updatePhoneTimeline(previous, next);
      if (previous?.projectID !== next.projectID) clearPreviewFrame();
      if (!next.previewAvailable && (previewActive || previous?.previewAvailable !== next.previewAvailable)) stopPreview();
      el('previewToggle').disabled = !next.previewAvailable;
      if (first) message('Connected');
      el('remote').hidden = false;
      el('project').textContent = next.project;
      el('connection').textContent = [next.workspace,next.role,next.song].filter(Boolean).join(' · ');
      const secs = Math.max(0, next.time);
      el('time').textContent = String(Math.floor(secs/60)).padStart(2,'0') + ':' + (secs%60).toFixed(2).padStart(5,'0');
      el('next').textContent = next.next ? (next.wrap ? 'After loop · ' : 'Next · ') + next.next + ' · ' + next.delay.toFixed(1) + ' s' : 'No upcoming cue';
      el('output').textContent = next.output;
      const showLocked = next.workspace === 'Show' && next.showArmState !== 'Armed';
      el('showState').textContent = next.workspace === 'Show' ? [next.showArmState, next.showStatus].filter(Boolean).join(' · ') : '';
      el('operator').hidden = next.role === 'Viewer';
      el('readinessPanel').hidden = next.role === 'Viewer';
      el('readiness').textContent = next.readiness;
      el('editor').hidden = next.role !== 'Editor';
      el('editing').disabled = next.workspace !== 'Edit';
      el('lock').textContent = next.workspace === 'Edit' ? '' : 'Switch to Edit on the Mac to change mapping.';
      el('saveStatus').textContent = next.saveStatus;
      el('projection').textContent = next.projectionBlackout ? 'Restore Projection' : 'Projection Blackout';
      el('fixtures').textContent = next.fixtureBlackout ? 'Restore Fixtures' : 'Fixture Blackout';
      el('mute').textContent = next.muted ? 'Enable Audio' : 'Mute Audio';
      document.querySelector('[data-action=play]').disabled = next.playing || showLocked;
      document.querySelector('[data-action=go]').disabled = showLocked;
      document.querySelector('[data-action=pause]').disabled = !next.playing;
      const rows = next.fixtures.map(item => {
        const row = document.createElement('li');
        row.textContent = [item.name,item.state,item.status].filter(Boolean).join(' · ');
        return row;
      });
      el('fixtureList').replaceChildren(...rows);
      const key = next.revision + next.role;
      if (next.role === 'Editor' && key !== lastEditorKey && !drag) {
        lastEditorKey = key;
        options(el('face'),next.faces.map(item => ({
          id:item.id, name:item.name + (item.object ? ' · ' + item.object : '') + (item.locked ? ' · Locked' : '')
        })));
        options(el('effect'),[{id:'',name:'Choose effect'},...next.effects]);
        options(el('palette'),[{id:'',name:'Choose palette color'},...next.palettes.map((item,index) => ({id:String(index),name:item.name}))]);
        el('brightness').value = next.brightness;
        syncFace();
      }
    }
    function ringsFor(item) { return item.mask.length ? item.mask : defaultRings; }
    function pointsFor(item) {
      return el('mode').value === 'corner' ? item.corners.map((p,i) => ({p,ring:0,index:i})) :
        ringsFor(item).flatMap((ring,r) => ring.map((p,i) => ({p,ring:r,index:i})));
    }
    function syncFace() {
      const item = face();
      if (!item) { draw(); return; }
      el('effect').value = item.effect;
      for (const key of ['rate','scale','intensity']) el(key).value = item[key];
      el('color').value = '#' + item.color.map(value => Math.round(value*255).toString(16).padStart(2,'0')).join('');
      if (document.activeElement !== el('rings')) el('rings').value = JSON.stringify(ringsFor(item));
      el('maskTools').hidden = el('mode').value !== 'mask';
      options(el('point'),pointsFor(item).map((point,index) => ({
        id:String(index),name:(point.ring ? 'Hole ' + point.ring + ' · ' : '') + 'Point ' + (point.index+1)
      })));
      draw();
    }
    function view() {
      const zoom = Number(el('zoom').value);
      const point = pointsFor(face() ?? {corners:[],mask:[]})[Number(el('point').value)]?.p ?? [.5,.5];
      const focus = zoom === 1 ? [.5,.5] : (drag?.focus ?? point);
      return {zoom,focus};
    }
    function screen(point, geometry) {
      return [(0.5+(point[0]-geometry.focus[0])*geometry.zoom)*canvas.width,
              (0.5+(point[1]-geometry.focus[1])*geometry.zoom)*canvas.height];
    }
    function local(event, geometry) {
      const rect = canvas.getBoundingClientRect();
      return [clamp(((event.clientX-rect.left)/rect.width-.5)/geometry.zoom+geometry.focus[0]),
              clamp(((event.clientY-rect.top)/rect.height-.5)/geometry.zoom+geometry.focus[1])];
    }
    function draw() {
      ctx.clearRect(0,0,canvas.width,canvas.height);
      const item = face();
      if (!item) return;
      const geometry = view();
      const rings = el('mode').value === 'corner' ? [item.corners] : ringsFor(item);
      let flat = 0;
      rings.forEach((ring,r) => {
        const positions = ring.map((point,i) => screen(drag?.ring===r && drag.index===i ? drag.value : point,geometry));
        ctx.strokeStyle = '#b9aaff'; ctx.lineWidth = 3; ctx.beginPath();
        positions.forEach(([x,y],i) => i ? ctx.lineTo(x,y) : ctx.moveTo(x,y));
        ctx.closePath(); ctx.stroke();
        positions.forEach(([x,y]) => {
          ctx.beginPath(); ctx.arc(x,y,10,0,2*Math.PI);
          ctx.fillStyle = flat++ === Number(el('point').value) ? '#ffad66' : '#d8d0ff'; ctx.fill();
        });
      });
    }
    function editPoint(point,value,base,id) {
      if (el('mode').value === 'corner') command('corner',{face:id,index:point.index,point:value},base);
      else {
        const rings = clone(ringsFor(base.faces.find(item => item.id===id)));
        rings[point.ring][point.index] = value;
        command('mask',{face:id,rings},base);
      }
    }
    canvas.onpointerdown = event => {
      const item = face();
      if (drag || !item || item.locked || state.workspace !== 'Edit' || busy) return;
      const geometry = view();
      const rect = canvas.getBoundingClientRect();
      const candidates = pointsFor(item);
      let index = -1, best = 26;
      candidates.forEach((point,i) => {
        const [x,y] = screen(point.p,geometry);
        const distance = Math.hypot(event.clientX-rect.left-x/canvas.width*rect.width,
                                    event.clientY-rect.top-y/canvas.height*rect.height);
        if (distance < best) { best = distance; index = i; }
      });
      if (index < 0) return;
      drag = {...candidates[index],value:candidates[index].p,base:state,id:item.id,focus:geometry.focus,pointer:event.pointerId};
      el('point').value = String(index);
      canvas.setPointerCapture(event.pointerId); draw();
    };
    canvas.onpointermove = event => {
      if (!drag || event.pointerId !== drag.pointer) return;
      drag.value = local(event,view());
      draw();
    };
    canvas.onpointerup = event => {
      if (!drag || event.pointerId !== drag.pointer) return;
      const current = drag;
      drag = null;
      editPoint(current,current.value,current.base,current.id);
      draw();
    };
    canvas.onpointercancel = canvas.onlostpointercapture = () => { drag = null; draw(); };

    el('pair').onsubmit = event => { event.preventDefault(); pair(el('code').value.trim()); };
    el('seek').onsubmit = event => { event.preventDefault(); command('seek',{time:Number(el('seekTime').value)}); };
    document.querySelectorAll('[data-action]').forEach(button => button.onclick = () => command(button.dataset.action));
    el('projection').onclick = () => command(state.projectionBlackout ? 'projectionOn' : 'projectionOff');
    el('fixtures').onclick = () => command(state.fixtureBlackout ? 'fixturesOn' : 'fixturesOff');
    el('mute').onclick = () => command(state.muted ? 'unmute' : 'mute');
    el('face').onchange = el('mode').onchange = () => { drag = null; syncFace(); };
    el('point').onchange = el('zoom').oninput = draw;
    document.querySelectorAll('[data-nudge]').forEach(button => button.onclick = () => {
      const item = face();
      if (!item || item.locked) return;
      const point = pointsFor(item)[Number(el('point').value)];
      if (!point) return;
      const [x,y] = button.dataset.nudge.split(',').map(Number);
      editPoint(point,[clamp(point.p[0]+x*.002),clamp(point.p[1]+y*.002)],state,item.id);
    });
    el('applyMask').onclick = () => {
      try { command('mask',{rings:JSON.parse(el('rings').value)}); }
      catch { message('Enter valid mask ring coordinates.'); }
    };
    el('addHole').onclick = () => {
      try {
        const rings = JSON.parse(el('rings').value);
        rings.push([[.4,.4],[.6,.4],[.6,.6],[.4,.6]]);
        el('rings').value = JSON.stringify(rings);
        message('Adjust the new ring coordinates, then Apply Mask.');
      } catch { message('Enter valid mask ring coordinates.'); }
    };
    el('effect').onchange = () => { if (el('effect').value) command('effect',{value:el('effect').value}); };
    for (const key of ['rate','scale','intensity']) el(key).onchange = () => command(key,{value:Number(el(key).value)});
    el('brightness').onchange = () => command('brightness',{value:Number(el('brightness').value)});
    el('color').onchange = () => command('color',{color:el('color').value.slice(1).match(/../g).map(n => parseInt(n,16)/255)});
    el('palette').onchange = () => {
      if (el('palette').value !== '') command('palette',state.palettes[Number(el('palette').value)]);
    };

    const phoneTimeline = el('phoneTimeline'), tl = phoneTimeline.getContext('2d');
    let timeline = null, timelineStart = 0, timelinePage = 0, timelineEpoch = 0;
    let timelineLoading = false, timelineDrag = null, timelineHits = [];
    const editTimelineAllowed = () => state?.role === 'Editor' && state.workspace === 'Edit';
    const timelineSpan = () => Number(el('timelineSpan').value);
    const clipValue = () => timeline?.clips.find(item => item.id === el('clipChoice').value);
    const cueValue = () => timeline?.cues.find(item => item.id === el('cueChoice').value);
    const numberField = id => el(id).value === '' ? NaN : Number(el(id).value);
    const validTime = value => Number.isFinite(value) && value >= 0 && value <= 3600;
    const cleanTime = value => Math.round(value * 1000) / 1000;
    const snapTime = value => cleanTime(el('timelineSnap').checked ? Math.round(value * 2) / 2 : value);
    function clearTimeline() {
      timeline = null; timelineDrag = null; timelineEpoch += 1;
      timelineHits = [];
      tl.clearRect(0, 0, phoneTimeline.width, phoneTimeline.height);
      el('timelineEdit').disabled = true;
    }
    function updatePhoneTimeline(previous, next) {
      if (previous?.projectID !== next.projectID) {
        clearTimeline(); timelinePage = 0; timelineStart = 0;
      } else if (timelineDrag && (!editTimelineAllowed() || next.revision !== timelineDrag.base.revision)) {
        timelineDrag = null;
      }
      el('timelineEdit').disabled = !editTimelineAllowed() || !timeline || timeline.revision !== next.revision;
      if (!el('timelinePanel').open) return;
      if (!timeline || timeline.revision !== next.revision) fetchTimeline();
      else drawPhoneTimeline();
    }
    async function fetchTimeline() {
      if (!state || !token || document.hidden || timelineLoading || !el('timelinePanel').open) return;
      timelineLoading = true;
      const epoch = timelineEpoch;
      const projectID = state.projectID;
      try {
        const value = await api('/timeline',{projectID, start:timelineStart, span:timelineSpan(), page:timelinePage});
        if (epoch !== timelineEpoch || !el('timelinePanel').open ||
            projectID !== state?.projectID || value.revision !== state.revision) return;
        timeline = value;
        timelinePage = value.page;
        options(el('clipChoice'), [{id:'',name:'Select a clip'}, ...value.clips.map(item => ({
          id:item.id,name:(value.tracks.find(track => track.id === item.owner)?.name || '') +
            ' · ' + item.name + ' · ' + cleanTime(item.start) + ' s'
        }))]);
        options(el('cueChoice'), [{id:'',name:'Select a cue'}, ...value.cues.map(item => ({
          id:item.id,name:item.name + ' · ' + cleanTime(item.time) + ' s'
        }))]);
        el('trackPage').textContent = 'Tracks ' + (value.page + 1) + ' / ' + value.pages;
        el('trackBack').disabled = value.page === 0;
        el('trackNext').disabled = value.page + 1 >= value.pages;
        el('timelineEdit').disabled = !editTimelineAllowed();
        el('timelineInfo').textContent = value.limited ? 'Dense range. Zoom in to see more clips or cues.' :
          (editTimelineAllowed() ? 'Drag a clip or cue. Select a clip’s edges to trim.' : 'Read-only timeline');
        syncTimelineFields();
        drawPhoneTimeline();
      } catch (error) {
        if (epoch === timelineEpoch) el('timelineInfo').textContent = error.message;
      } finally {
        timelineLoading = false;
        if (epoch !== timelineEpoch && state && el('timelinePanel').open && !document.hidden) fetchTimeline();
      }
    }
    function syncTimelineFields() {
      const clip = clipValue(), cue = cueValue();
      el('clipFields').hidden = !clip;
      el('cueFields').hidden = !cue;
      if (clip) {
        el('clipStart').value = cleanTime(clip.start);
        el('clipEnd').value = cleanTime(clip.end);
        el('sourceFields').hidden = clip.in === undefined;
        if (clip.in !== undefined) {
          el('sourceIn').value = cleanTime(clip.in); el('sourceOut').value = cleanTime(clip.out);
        }
      }
      if (cue) el('cueTime').value = cleanTime(cue.time);
    }
    function drawPhoneTimeline() {
      if (!timeline) return;
      const width = phoneTimeline.width, label = 138, rowHeight = 36, ruler = 28;
      const end = timeline.start + timeline.span;
      const plot = width - label;
      const x = time => label + (time - timeline.start) / timeline.span * plot;
      const clipped = value => Math.max(label, Math.min(width, value));
      const height = ruler + (timeline.tracks.length + 1) * rowHeight;
      if (phoneTimeline.height !== height) phoneTimeline.height = height;
      tl.fillStyle = '#191924'; tl.fillRect(0,0,width,height);
      tl.font = '14px system-ui';
      for (let i=0;i<=6;i++) {
        const time=timeline.start + timeline.span * i / 6, pos=x(time);
        tl.fillStyle='#373643'; tl.fillRect(pos,ruler,1,height-ruler);
        if (i<6) { tl.fillStyle='#d6d1e1'; tl.fillText(cleanTime(time)+' s',pos+4,19); }
      }
      timelineHits = [];
      timeline.tracks.forEach((track,index) => {
        const y = ruler + index * rowHeight;
        tl.fillStyle='#211f30'; tl.fillRect(0,y,label,rowHeight-1);
        tl.fillStyle='#ddd7ef'; tl.fillText(track.name,6,y+23,label-12);
        for (const clip of timeline.clips.filter(item => item.owner === track.id)) {
          const edit = timelineDrag?.item.id === clip.id ? timelineDrag : null;
          const left = clipped(x(edit?.start ?? clip.start)), right = clipped(x(edit?.end ?? clip.end));
          if (right <= left) continue;
          const selected = clip.id === el('clipChoice').value;
          tl.fillStyle = selected ? '#9179ec' : '#554499';
          tl.fillRect(left,y+4,Math.max(2,right-left),rowHeight-8);
          if (right-left>25) { tl.fillStyle='#fff'; tl.fillText(clip.name,left+4,y+22,right-left-8); }
          if (selected && editTimelineAllowed()) {
            tl.fillStyle='#ebe2ff';
            if (clip.start >= timeline.start) tl.fillRect(left,y+4,4,rowHeight-8);
            if (clip.end <= end) tl.fillRect(right-4,y+4,4,rowHeight-8);
          }
          timelineHits.push({item:clip,left,right,y,cue:false});
        }
      });
      const cueY = ruler + timeline.tracks.length * rowHeight;
      tl.fillStyle='#272533'; tl.fillRect(0,cueY,label,rowHeight-1);
      tl.fillStyle='#f6c987'; tl.fillText('Lighting cues',6,cueY+23);
      for (const cue of timeline.cues) {
        const time = timelineDrag?.item.id === cue.id ? timelineDrag.start : cue.time;
        const center = clipped(x(time)), cy = cueY+18;
        tl.fillStyle=cue.id === el('cueChoice').value ? '#fff0af' : '#f5aa66';
        tl.beginPath(); tl.moveTo(center,cy-8); tl.lineTo(center+8,cy); tl.lineTo(center,cy+8); tl.lineTo(center-8,cy); tl.fill();
        timelineHits.push({item:cue,left:center-12,right:center+12,y:cueY,cue:true});
      }
      if (state.time >= timeline.start && state.time < end) {
        tl.fillStyle='#ff793b'; tl.fillRect(x(state.time),0,2,height);
      }
    }
    function refreshTimelineWindow() {
      clearTimeline();
      el('timelineInfo').textContent = 'Loading timeline…';
      fetchTimeline();
    }
    el('timelinePanel').ontoggle = () => {
      if (el('timelinePanel').open) refreshTimelineWindow();
      else clearTimeline();
    };
    el('timelineBack').onclick = () => { timelineStart=Math.max(0,timelineStart-timelineSpan()); refreshTimelineWindow(); };
    el('timelineNext').onclick = () => {
      timelineStart=Math.min(3600-timelineSpan(),timelineStart+timelineSpan()); refreshTimelineWindow();
    };
    el('timelineNow').onclick = () => {
      timelineStart=Math.max(0,Math.min(3600-timelineSpan(),(state?.time || 0)-timelineSpan()/3)); refreshTimelineWindow();
    };
    el('timelineSpan').onchange = () => { timelineStart=Math.min(timelineStart,3600-timelineSpan()); refreshTimelineWindow(); };
    el('trackBack').onclick = () => { timelinePage=Math.max(0,timelinePage-1); refreshTimelineWindow(); };
    el('trackNext').onclick = () => { timelinePage+=1; refreshTimelineWindow(); };
    el('clipChoice').onchange = el('cueChoice').onchange = () => { syncTimelineFields(); drawPhoneTimeline(); };
    function editClip(action, fields) {
      const item=clipValue();
      if (!editTimelineAllowed() || !item || !timeline || timeline.revision !== state.revision) return;
      command(action,{clip:item.id,owner:item.owner,...fields},timeline);
    }
    el('clipMove').onclick = () => {
      const start=numberField('clipStart');
      if (validTime(start)) editClip('clipMove',{start}); else message('Enter a valid start time.');
    };
    el('clipTrim').onclick = () => {
      const start=numberField('clipStart'), end=numberField('clipEnd');
      if (validTime(start) && validTime(end)) editClip('clipTrim',{start,end}); else message('Enter valid trim times.');
    };
    el('sourceApply').onclick = () => {
      const begin=numberField('sourceIn'), end=numberField('sourceOut');
      if (Number.isFinite(begin) && Number.isFinite(end)) editClip('clipSource',{in:begin,out:end});
      else message('Enter both source times.');
    };
    el('cueSelect').onclick = () => {
      const item=cueValue();
      if (item && timeline) command('selectCue',{cue:item.id},timeline);
    };
    el('cueApply').onclick = () => {
      const item=cueValue(), time=numberField('cueTime');
      if (item && timeline && validTime(time)) command('cueTime',{cue:item.id,time},timeline);
    };
    function timelinePoint(event) {
      const rect=phoneTimeline.getBoundingClientRect();
      return {x:(event.clientX-rect.left)*phoneTimeline.width/rect.width, y:(event.clientY-rect.top)*phoneTimeline.height/rect.height};
    }
    phoneTimeline.onpointerdown = event => {
      if (!timeline || !editTimelineAllowed() || busy || timeline.revision !== state.revision || timelineDrag) return;
      const {x,y}=timelinePoint(event);
      const hit=[...timelineHits].reverse().find(h=>x>=h.left && x<=h.right && y>=h.y && y<h.y+36);
      if (!hit) return;
      const item=hit.item, selected=el('clipChoice').value===item.id;
      if (hit.cue) el('cueChoice').value=item.id; else el('clipChoice').value=item.id;
      const mode=hit.cue ? 'cueTime' : selected && x-hit.left<14 && item.start>=timeline.start ? 'left' :
        selected && hit.right-x<14 && item.end<=timeline.start+timeline.span ? 'right' : 'clipMove';
      timelineDrag={item,mode,base:timeline,x,pointer:event.pointerId,start:item.time??item.start,end:item.end,moved:false};
      event.preventDefault();
      phoneTimeline.setPointerCapture(event.pointerId);
      syncTimelineFields(); drawPhoneTimeline();
    };
    phoneTimeline.onpointermove = event => {
      const d=timelineDrag;
      if (!d || event.pointerId!==d.pointer) return;
      const dx=timelinePoint(event).x-d.x;
      if (!d.moved && Math.abs(dx)<4) return;
      d.moved=true;
      const delta=dx/Math.max(1,phoneTimeline.width-138)*d.base.span, item=d.item;
      if (d.mode==='cueTime') d.start=Math.max(0,Math.min(3600,snapTime(item.time+delta)));
      if (d.mode==='left') d.start=Math.max(0,Math.min(item.end-.1,snapTime(item.start+delta)));
      if (d.mode==='right') d.end=Math.min(3600,Math.max(item.start+.1,snapTime(item.end+delta)));
      if (d.mode==='clipMove') {
        const length=item.end-item.start;
        d.start=Math.min(3600-length,Math.max(0,snapTime(item.start+delta))); d.end=d.start+length;
      }
      drawPhoneTimeline();
    };
    phoneTimeline.onpointerup = event => {
      const d=timelineDrag;
      if (!d || event.pointerId!==d.pointer) return;
      timelineDrag=null; drawPhoneTimeline();
      if (!d.moved || !editTimelineAllowed() || d.base.revision!==state.revision) return;
      if (d.mode==='cueTime') command('cueTime',{cue:d.item.id,time:d.start},d.base);
      else {
        const action=d.mode==='clipMove'?'clipMove':'clipTrim';
        command(action,{clip:d.item.id,owner:d.item.owner,start:d.start,end:d.end},d.base);
      }
    };
    phoneTimeline.onpointercancel = phoneTimeline.onlostpointercapture = () => { timelineDrag=null; drawPhoneTimeline(); };

    let previewActive=false, previewBusy=false, previewEpoch=0, previewDisplayed=0;
    function clearPreviewFrame() {
      previewEpoch+=1; previewDisplayed=0;
      el('macPreview').hidden=true; el('macPreview').removeAttribute('src');
    }
    function stopPreview() {
      previewActive=false; clearPreviewFrame();
      el('previewToggle').textContent='Start Preview';
      el('previewInfo').textContent=state?.previewAvailable===false?'Preview is disabled on the Mac.':'Preview stopped.';
    }
    async function refreshPreview() {
      if (!previewActive || previewBusy || document.hidden || !state || !token ||
          el('remote').hidden || !el('previewPanel').open) return;
      previewBusy=true;
      const epoch=previewEpoch, projectID=state.projectID, start=performance.now();
      try {
        const frame=await api('/preview',{projectID});
        if (epoch!==previewEpoch || projectID!==state?.projectID || !previewActive || document.hidden) return;
        if (frame.pending) {
          if (!previewDisplayed || performance.now()-previewDisplayed>4000) {
            el('macPreview').hidden=true; el('previewInfo').textContent='Waiting for a frame from the Mac…';
          }
          return;
        }
        if (typeof frame.jpeg!=='string' || frame.jpeg.length>200000) throw Error('Preview frame unavailable.');
        el('macPreview').src='data:image/jpeg;base64,'+frame.jpeg;
        el('macPreview').hidden=false; previewDisplayed=performance.now();
        const age=frame.age + (previewDisplayed-start)/1000;
        el('previewInfo').textContent='Captured at '+frame.time.toFixed(2)+' s · about '+age.toFixed(1)+' s old';
      } catch (error) {
        if (epoch===previewEpoch) { clearPreviewFrame(); el('previewInfo').textContent=error.message; }
      } finally { previewBusy=false; }
    }
    el('previewToggle').onclick = () => {
      if (previewActive) { stopPreview(); return; }
      previewActive=true; el('previewToggle').textContent='Stop Preview'; refreshPreview();
    };
    el('previewPanel').ontoggle = () => { if (!el('previewPanel').open) stopPreview(); };
    document.addEventListener('visibilitychange', () => {
      drag=null; timelineDrag=null;
      if (document.hidden) { clearPreviewFrame(); clearTimeline(); }
      else { refresh(); if (el('timelinePanel').open) fetchTimeline(); refreshPreview(); }
    });
    setInterval(refreshPreview,1250);
    const invitation = location.hash.slice(1);
    if (invitation) { history.replaceState(null,'',location.pathname); pair(invitation); }
    setInterval(refresh,800);
    """#
}
