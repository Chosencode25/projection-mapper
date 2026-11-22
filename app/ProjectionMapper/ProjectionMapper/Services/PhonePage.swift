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
          token = ''; drag = null; state = null; el('remote').hidden = true; el('pair').hidden = false;
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
      if (!token || updating || busy) return;
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
      state = next;
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
    const invitation = location.hash.slice(1);
    if (invitation) { history.replaceState(null,'',location.pathname); pair(invitation); }
    setInterval(refresh,800);
    """#
}
