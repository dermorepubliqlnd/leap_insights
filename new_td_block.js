/* ── TRAINING DELIVERY ────────────────────────────────────────────────────────────────────
   Reads the SAME training_sessions records as the existing Training Sessions module (no
   duplicate data store, same TrSessionDB). Adds a shared List/Calendar experience with
   consistent filters + metric cards, plus a dedicated Add/Edit Training workflow covering
   the new delivery_type / owner_id / audience / assessment fields. Existing Training Sessions
   tab is untouched and keeps using its own simpler modal. ─────────────────────────────────── */
let tdF={status:'all',type:'all',program:'',person:'all',daterange:'all',audience:'all'};
let tdViewMode='list';
let tdPage=1;
const TD_PAGE_SIZE=10;
let tdCalCursor=new Date(); tdCalCursor.setDate(1);

const TD_TYPE_COLORS={
  'ILT':{bg:'#eff6ff',fg:'#1d4ed8',dot:'#3b82f6'},
  'VILT':{bg:'#f5f3ff',fg:'#6d28d9',dot:'#8b5cf6'},
  'Self-led':{bg:'#f0fdf4',fg:'#15803d',dot:'#22c55e'},
  'External':{bg:'#fff7ed',fg:'#c2410c',dot:'#f97316'}
};

function renderTrainingDashboard(){ /* placeholder — see #view-training-dashboard */ }

function _tdIsOwnerType(deliveryType){ return deliveryType==='Self-led'||deliveryType==='External'; }

function _tdPersonName(s){
  if(_tdIsOwnerType(s.deliveryType)){
    const o=s.ownerId?DB.byId(s.ownerId):null;
    return o?`${o.firstName} ${o.lastName}`:'—';
  }
  const t=s.trainerId?DB.byId(s.trainerId):null;
  return t?`${t.firstName} ${t.lastName}`:'—';
}

function _tdStatus(s){
  if(s.status==='cancelled') return 'Cancelled';
  if(s.status==='completed') return 'Completed';
  const today=new Date().toISOString().slice(0,10);
  const start=s.trainingDate||'';
  const end=s.endDate||s.trainingDate||'';
  if(start && today<start) return 'Upcoming';
  if(start && today>=start && today<=end) return 'In Progress';
  if(end && today>end) return 'In Progress'; // scheduled but date passed & not yet marked complete
  return 'Upcoming';
}

function _tdStatusBadge(st){
  const map={
    'Upcoming':'background:#fef9c3;color:#a16207',
    'In Progress':'background:#dbeafe;color:#1d4ed8',
    'Completed':'background:#dcfce7;color:#15803d',
    'Cancelled':'background:#fee2e2;color:#dc2626'
  };
  return `<span class="badge" style="${map[st]||''}">${st}</span>`;
}

function _tdTypeBadge(dt){
  if(!dt) return '<span style="color:var(--text3)">— not set —</span>';
  const c=TD_TYPE_COLORS[dt]||{bg:'#f1f5f9',fg:'#64748b'};
  return `<span class="badge" style="background:${c.bg};color:${c.fg}">${Utils.esc(dt)}</span>`;
}

function _tdDocStatus(s){
  const rep=TrainingReportsDB.all().find(r=>r.sessionId===s.id);
  if(!rep) return '<span class="badge" style="background:#fef9c3;color:#a16207">Report Pending</span>';
  if(rep.status==='approved') return '<span class="badge" style="background:#dcfce7;color:#15803d">Report Approved</span>';
  if(rep.status==='submitted') return '<span class="badge" style="background:#dbeafe;color:#1d4ed8">Report Submitted</span>';
  if(rep.status==='returned') return '<span class="badge" style="background:#fee2e2;color:#dc2626">Report Returned</span>';
  return '<span class="badge" style="background:#fef9c3;color:#a16207">Report Pending</span>';
}

function _tdEvalStatus(s){
  if(_tdIsOwnerType(s.deliveryType)) return '<span style="color:var(--text3)">N/A</span>';
  const evs=EvalDB.all().filter(e=>e.sessionId===s.id);
  if(!evs.length){
    return s.recordingLink?'<span class="badge" style="background:#dbeafe;color:#1d4ed8">Ready for Eval</span>':'<span style="color:var(--text3)">N/A</span>';
  }
  const done=evs.find(e=>e.status==='completed'||e.status==='pending_ack');
  return done?'<span class="badge" style="background:#dcfce7;color:#15803d">Evaluated</span>':'<span class="badge" style="background:#dbeafe;color:#1d4ed8">Ready for Eval</span>';
}

function _tdRecordingCell(s){
  if(_tdIsOwnerType(s.deliveryType)) return '<span style="color:var(--text3)">N/A</span>';
  return s.recordingLink?`<a href="${s.recordingLink}" target="_blank" rel="noopener" style="font-size:12.5px">▶ View</a>`:'<span style="color:var(--text3)">— none —</span>';
}

function _tdDateCell(s){
  if(s.endDate && s.endDate!==s.trainingDate) return `${Utils.esc(s.trainingDate||'—')} – ${Utils.esc(s.endDate)}`;
  return Utils.esc(s.trainingDate||'—');
}

function _tdFilteredRows(){
  const all=TrSessionDB.all();
  const today=new Date();
  return all.filter(s=>{
    const st=_tdStatus(s);
    if(tdF.status!=='all' && st!==tdF.status) return false;
    if(tdF.type!=='all' && (s.deliveryType||'')!==tdF.type) return false;
    if(tdF.program && !(s.trainingProgram||'').toLowerCase().includes(tdF.program.toLowerCase())) return false;
    if(tdF.person!=='all'){
      const pid=_tdIsOwnerType(s.deliveryType)?s.ownerId:s.trainerId;
      if(pid!==tdF.person) return false;
    }
    if(tdF.audience!=='all' && (s.audience||'')!==tdF.audience) return false;
    if(tdF.daterange!=='all'){
      const d=s.trainingDate?new Date(s.trainingDate):null;
      if(!d) return false;
      if(tdF.daterange==='next30'){ const diff=(d-today)/86400000; if(diff<0||diff>30) return false; }
      if(tdF.daterange==='past30'){ const diff=(today-d)/86400000; if(diff<0||diff>30) return false; }
      if(tdF.daterange==='thismonth'){ if(d.getMonth()!==today.getMonth()||d.getFullYear()!==today.getFullYear()) return false; }
      if(tdF.daterange==='thisyear'){ if(d.getFullYear()!==today.getFullYear()) return false; }
    }
    return true;
  }).sort((a,b)=>(b.trainingDate||'').localeCompare(a.trainingDate||''));
}

function tdSetFilter(key,val){ tdF[key]=val; tdPage=1; renderTrainingDelivery(); }

function tdResetFilters(){
  tdF={status:'all',type:'all',program:'',person:'all',daterange:'all',audience:'all'};
  tdPage=1;
  ['td-f-status','td-f-type','td-f-daterange','td-f-audience','td-f-person'].forEach(id=>{const el=document.getElementById(id); if(el) el.value='all';});
  const pEl=document.getElementById('td-f-program'); if(pEl) pEl.value='';
  renderTrainingDelivery();
}

function tdSwitchView(mode){
  tdViewMode=mode;
  document.getElementById('td-list-wrap').classList.toggle('hidden',mode!=='list');
  document.getElementById('td-cal-wrap').classList.toggle('hidden',mode!=='calendar');
  document.getElementById('td-view-list-btn').className='btn btn-sm '+(mode==='list'?'btn-primary':'btn-secondary');
  document.getElementById('td-view-cal-btn').className='btn btn-sm '+(mode==='calendar'?'btn-primary':'btn-secondary');
  if(mode==='calendar') renderTDCalendar(_tdFilteredRows()); else renderTDList(_tdFilteredRows());
}

function renderTDMetrics(){
  const all=TrSessionDB.all();
  const total=all.length;
  const today=new Date();
  const upcoming=all.filter(s=>{
    if(_tdStatus(s)!=='Upcoming') return false;
    if(!s.trainingDate) return false;
    const diff=(new Date(s.trainingDate)-today)/86400000;
    return diff>=0 && diff<=30;
  }).length;
  const completed=all.filter(s=>s.status==='completed').length;
  const inProgress=all.filter(s=>_tdStatus(s)==='In Progress').length;
  const reportPending=all.filter(s=>{
    const st=_tdStatus(s);
    if(st!=='Completed' && st!=='In Progress') return false;
    const rep=TrainingReportsDB.all().find(r=>r.sessionId===s.id);
    return !rep || rep.status!=='approved';
  }).length;
  document.getElementById('td-kpis').innerHTML=`
    <div class="kpi-card"><div class="kpi-icon" style="background:#f0f9ff">🗂</div><div class="kpi-label">Total Implementations</div><div class="kpi-value" style="color:#0369a1">${total}</div><div class="kpi-sub">All delivery types</div></div>
    <div class="kpi-card"><div class="kpi-icon" style="background:#fef9c3">📅</div><div class="kpi-label">Upcoming</div><div class="kpi-value" style="color:#a16207">${upcoming}</div><div class="kpi-sub">Next 30 days</div></div>
    <div class="kpi-card"><div class="kpi-icon" style="background:#dcfce7">✅</div><div class="kpi-label">Completed</div><div class="kpi-value" style="color:#16a34a">${completed}</div><div class="kpi-sub">All time</div></div>
    <div class="kpi-card"><div class="kpi-icon" style="background:#dbeafe">▶</div><div class="kpi-label">In Progress</div><div class="kpi-value" style="color:#1d4ed8">${inProgress}</div><div class="kpi-sub">Currently running</div></div>
    <div class="kpi-card"><div class="kpi-icon" style="background:#fff7ed">📋</div><div class="kpi-label">Report Pending</div><div class="kpi-value" style="color:#c2410c">${reportPending}</div><div class="kpi-sub">Awaiting submission</div></div>
  `;
}

function _tdPopulateFilterOptions(){
  const all=TrSessionDB.all();
  const personSel=document.getElementById('td-f-person');
  if(personSel && personSel.options.length<=1){
    const ids=new Set();
    all.forEach(s=>{ const pid=_tdIsOwnerType(s.deliveryType)?s.ownerId:s.trainerId; if(pid) ids.add(pid); });
    const people=[...ids].map(id=>DB.byId(id)).filter(Boolean).sort((a,b)=>(a.firstName+a.lastName).localeCompare(b.firstName+b.lastName));
    personSel.innerHTML='<option value="all">All</option>'+people.map(u=>`<option value="${u.id}">${Utils.esc(u.firstName+' '+u.lastName)}</option>`).join('');
    personSel.value=tdF.person;
  }
  const audSel=document.getElementById('td-f-audience');
  if(audSel && audSel.options.length<=1){
    const auds=[...new Set(all.map(s=>s.audience).filter(Boolean))].sort();
    audSel.innerHTML='<option value="all">All Audiences</option>'+auds.map(a=>`<option value="${Utils.esc(a)}">${Utils.esc(a)}</option>`).join('');
    audSel.value=tdF.audience;
  }
}

function renderTrainingDelivery(){
  renderTDMetrics();
  _tdPopulateFilterOptions();
  document.getElementById('td-view-list-btn').className='btn btn-sm '+(tdViewMode==='list'?'btn-primary':'btn-secondary');
  document.getElementById('td-view-cal-btn').className='btn btn-sm '+(tdViewMode==='calendar'?'btn-primary':'btn-secondary');
  document.getElementById('td-list-wrap').classList.toggle('hidden',tdViewMode!=='list');
  document.getElementById('td-cal-wrap').classList.toggle('hidden',tdViewMode!=='calendar');
  const rows=_tdFilteredRows();
  if(tdViewMode==='calendar') renderTDCalendar(rows); else renderTDList(rows);
}

function renderTDList(rows){
  const wrap=document.getElementById('td-list-wrap');
  if(!rows.length){
    wrap.innerHTML='<div class="empty-state"><div class="empty-ico">🗂</div><div class="empty-title">No training deliveries found</div><div style="font-size:13px;color:var(--text3);margin-top:4px">Try adjusting your filters, or click "+ Add Training" to log one.</div></div>';
    return;
  }
  const totalPages=Math.max(1,Math.ceil(rows.length/TD_PAGE_SIZE));
  if(tdPage>totalPages) tdPage=totalPages;
  const start=(tdPage-1)*TD_PAGE_SIZE;
  const pageRows=rows.slice(start,start+TD_PAGE_SIZE);
  const rowHtml=(s)=>`<tr>
      <td class="mono">${Utils.esc(s.code||s.id||'')}</td>
      <td>
        <div style="font-weight:600;font-size:13px">${Utils.esc(s.trainingProgram||'—')}</div>
        <div style="font-size:11.5px;color:var(--text3)">Batch ${Utils.esc(s.batchNo||'—')}</div>
      </td>
      <td>${_tdTypeBadge(s.deliveryType)}</td>
      <td style="font-size:13px">${Utils.esc(_tdPersonName(s))}</td>
      <td style="font-size:13px">${_tdDateCell(s)}</td>
      <td style="font-size:13px">${Utils.esc(s.audience||'—')}</td>
      <td>${_tdStatusBadge(_tdStatus(s))}</td>
      <td>${_tdDocStatus(s)}</td>
      <td style="font-size:13px">${_tdRecordingCell(s)}</td>
      <td>${_tdEvalStatus(s)}</td>
      <td><div class="td-acts">
        <button class="btn btn-sm btn-secondary" onclick="openTrainingModal('${s.id}')">Edit</button>
        <button class="btn btn-sm btn-ghost" style="color:#dc2626" onclick="deleteTrainingRecord('${s.id}')">Delete</button>
      </div></td>
    </tr>`;
  const pager=`<div style="display:flex;align-items:center;justify-content:space-between;padding:10px 4px">
      <div style="font-size:12.5px;color:var(--text3)">Showing ${rows.length?start+1:0}–${Math.min(start+TD_PAGE_SIZE,rows.length)} of ${rows.length}</div>
      <div style="display:flex;gap:6px">
        <button class="btn btn-sm btn-secondary" ${tdPage<=1?'disabled':''} onclick="tdGoPage(${tdPage-1})">‹ Prev</button>
        <span style="font-size:12.5px;padding:6px 8px">Page ${tdPage} of ${totalPages}</span>
        <button class="btn btn-sm btn-secondary" ${tdPage>=totalPages?'disabled':''} onclick="tdGoPage(${tdPage+1})">Next ›</button>
      </div>
    </div>`;
  wrap.innerHTML=`<div class="card"><div class="eval-tbl-wrap"><table class="eval-tbl">
    <thead><tr><th>Session ID</th><th>Program / Implementation</th><th>Type</th><th>Trainer / Owner</th><th>Date / Period</th><th>Audience</th><th>Status</th><th>Documentation</th><th>Recording</th><th>Trainer Evaluation</th><th>Actions</th></tr></thead>
    <tbody>${pageRows.map(rowHtml).join('')}</tbody>
  </table></div>${pager}</div>`;
}

function tdGoPage(p){ tdPage=p; renderTDList(_tdFilteredRows()); }

function tdCalPrev(){ tdCalCursor.setMonth(tdCalCursor.getMonth()-1); renderTDCalendar(_tdFilteredRows()); }
function tdCalNext(){ tdCalCursor.setMonth(tdCalCursor.getMonth()+1); renderTDCalendar(_tdFilteredRows()); }
function tdCalToday(){ tdCalCursor=new Date(); tdCalCursor.setDate(1); renderTDCalendar(_tdFilteredRows()); }

function renderTDCalendar(rows){
  const wrap=document.getElementById('td-cal-wrap');
  const year=tdCalCursor.getFullYear(), month=tdCalCursor.getMonth();
  const monthLabel=tdCalCursor.toLocaleDateString('en-US',{month:'long',year:'numeric'});
  const firstDow=new Date(year,month,1).getDay();
  const daysInMonth=new Date(year,month+1,0).getDate();
  const byDay={};
  rows.forEach(s=>{
    if(!s.trainingDate) return;
    const start=new Date(s.trainingDate+'T00:00:00');
    const end=s.endDate?new Date(s.endDate+'T00:00:00'):start;
    for(let d=new Date(start); d<=end; d.setDate(d.getDate()+1)){
      if(d.getFullYear()===year && d.getMonth()===month){
        const key=d.getDate();
        (byDay[key]=byDay[key]||[]).push(s);
      }
    }
  });
  let cells='';
  for(let i=0;i<firstDow;i++) cells+='<div style="background:#f8fafc;border:1px solid var(--border);min-height:92px"></div>';
  const todayStr=new Date().toISOString().slice(0,10);
  for(let day=1; day<=daysInMonth; day++){
    const dateStr=`${year}-${String(month+1).padStart(2,'0')}-${String(day).padStart(2,'0')}`;
    const isToday=dateStr===todayStr;
    const evs=(byDay[day]||[]).slice(0,3);
    const more=(byDay[day]||[]).length-evs.length;
    const chips=evs.map(s=>{
      const c=TD_TYPE_COLORS[s.deliveryType]||{bg:'#f1f5f9',fg:'#64748b',dot:'#94a3b8'};
      return `<div onclick="openTrainingModal('${s.id}')" title="${Utils.esc(s.trainingProgram||'')}" style="cursor:pointer;background:${c.bg};color:${c.fg};font-size:10.5px;padding:2px 5px;border-radius:4px;margin-top:2px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">● ${Utils.esc(s.trainingProgram||s.code||'')}</div>`;
    }).join('');
    cells+=`<div style="background:var(--white);border:1px solid var(--border);min-height:92px;padding:5px;${isToday?'box-shadow:inset 0 0 0 2px #4f46e5':''}">
      <div style="font-size:11.5px;font-weight:600;color:${isToday?'#4f46e5':'var(--text3)'}">${day}</div>
      ${chips}${more>0?`<div style="font-size:10px;color:var(--text3);margin-top:2px">+${more} more</div>`:''}
    </div>`;
  }
  const legend=Object.entries(TD_TYPE_COLORS).map(([k,c])=>`<span style="display:inline-flex;align-items:center;gap:4px;font-size:11.5px;color:var(--text2);margin-right:14px"><span style="width:9px;height:9px;border-radius:50%;background:${c.dot};display:inline-block"></span>${k}</span>`).join('');
  wrap.innerHTML=`<div class="card" style="padding:14px 16px">
    <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:10px;flex-wrap:wrap;gap:8px">
      <div style="display:flex;align-items:center;gap:8px">
        <button class="btn btn-sm btn-secondary" onclick="tdCalPrev()">‹</button>
        <button class="btn btn-sm btn-secondary" onclick="tdCalToday()">Today</button>
        <button class="btn btn-sm btn-secondary" onclick="tdCalNext()">›</button>
        <span style="font-weight:600;font-size:14.5px;margin-left:6px">${monthLabel}</span>
      </div>
      <div>${legend}</div>
    </div>
    <div style="display:grid;grid-template-columns:repeat(7,1fr);gap:0;border-top:1px solid var(--border);border-left:1px solid var(--border)">
      ${['Sun','Mon','Tue','Wed','Thu','Fri','Sat'].map(d=>`<div style="background:#f8fafc;border-right:1px solid var(--border);border-bottom:1px solid var(--border);padding:6px 8px;font-size:11px;font-weight:600;color:var(--text3)">${d}</div>`).join('')}
      ${cells}
    </div>
  </div>`;
}

/* ── ADD / EDIT TRAINING MODAL ────────────────────────────────────────────────────────── */
function _tdToggleTypeFields(){
  const dt=document.getElementById('td-type').value;
  const ownerType=_tdIsOwnerType(dt);
  document.getElementById('td-trainer-wrap').classList.toggle('hidden',ownerType);
  document.getElementById('td-owner-wrap').classList.toggle('hidden',!ownerType);
  document.getElementById('td-enddate-wrap').classList.toggle('hidden',!ownerType);
  document.getElementById('td-recording-wrap').classList.toggle('hidden',ownerType);
}

function openTrainingModal(id){
  document.getElementById('td-error').classList.add('hidden');
  const s=id?TrSessionDB.byId(id):null;
  const eligibleTrainers=DB.all().filter(u=>u.positionId==='pos_6'&&(u.isActive||u.id===(s&&s.trainerId)));
  document.getElementById('td-trainer').innerHTML='<option value="">— Select Trainer —</option>'+eligibleTrainers.map(u=>`<option value="${u.id}">${Utils.esc(u.firstName+' '+u.lastName)}${u.isActive?'':' (inactive)'}</option>`).join('');
  const activeUsers=DB.all().filter(u=>u.isActive||u.id===(s&&s.ownerId)).sort((a,b)=>(a.firstName+a.lastName).localeCompare(b.firstName+b.lastName));
  document.getElementById('td-owner').innerHTML='<option value="">— Select Owner —</option>'+activeUsers.map(u=>`<option value="${u.id}">${Utils.esc(u.firstName+' '+u.lastName)}${u.isActive?'':' (inactive)'}</option>`).join('');
  document.getElementById('td-venue').innerHTML='<option value="">— Select Venue —</option>'+Sel.active(Store.VENUES).map(v=>`<option value="${v.id}">${Utils.esc(v.name)}</option>`).join('');

  document.getElementById('td-id').value=id||'';
  document.getElementById('td-modal-title').textContent=id?'Edit Training':'Add Training';
  document.getElementById('td-type').value=s?.deliveryType||'';
  document.getElementById('td-program').value=s?.trainingProgram||'';
  document.getElementById('td-batch').value=s?.batchNo||'';
  document.getElementById('td-date').value=s?.trainingDate||'';
  document.getElementById('td-enddate').value=s?.endDate||'';
  document.getElementById('td-trainer').value=s?.trainerId||'';
  document.getElementById('td-owner').value=s?.ownerId||'';
  document.getElementById('td-venue').value=s?.venueId||'';
  document.getElementById('td-audience').value=s?.audience||'';
  document.getElementById('td-expected').value=s?.expectedParticipants??'';
  document.getElementById('td-recording').value=s?.recordingLink||'';
  document.getElementById('td-assessment').value=s?.assessmentType||'None';
  document.getElementById('td-passing').value=s?.passingScore??'';
  document.getElementById('td-status').value=s?.status||'scheduled';
  _tdToggleTypeFields();
  openModal('training');
}

async function saveTrainingModal(){
  const id=document.getElementById('td-id').value||null;
  const deliveryType=document.getElementById('td-type').value;
  const ownerType=_tdIsOwnerType(deliveryType);
  const expectedRaw=document.getElementById('td-expected').value.trim();
  const passingRaw=document.getElementById('td-passing').value.trim();
  const d={
    deliveryType,
    trainingProgram:document.getElementById('td-program').value.trim(),
    batchNo:document.getElementById('td-batch').value.trim(),
    trainingDate:document.getElementById('td-date').value,
    endDate:ownerType?(document.getElementById('td-enddate').value||null):null,
    trainerId:ownerType?null:(document.getElementById('td-trainer').value||null),
    ownerId:ownerType?(document.getElementById('td-owner').value||null):null,
    venueId:document.getElementById('td-venue').value||null,
    audience:document.getElementById('td-audience').value.trim(),
    expectedParticipants:expectedRaw?parseInt(expectedRaw,10):null,
    recordingLink:ownerType?'':document.getElementById('td-recording').value.trim(),
    assessmentType:document.getElementById('td-assessment').value,
    passingScore:passingRaw?parseInt(passingRaw,10):null,
    status:document.getElementById('td-status').value
  };
  const errs=[];
  if(!d.deliveryType) errs.push('Please select a Delivery Type.');
  if(!d.trainingProgram) errs.push('Training Program / Title is required.');
  if(!d.batchNo) errs.push('Batch No. is required.');
  if(!d.trainingDate) errs.push('Start Date is required.');
  if(!ownerType && !d.trainerId) errs.push('Please select a Trainer.');
  if(ownerType && !d.ownerId) errs.push('Please select an Owner.');
  if(ownerType && d.endDate && d.endDate<d.trainingDate) errs.push('End Date cannot be before Start Date.');
  const errEl=document.getElementById('td-error');
  if(errs.length){ errEl.textContent=errs[0]; errEl.classList.remove('hidden'); errEl.style.display='block'; return; }
  errEl.classList.add('hidden');
  const saveBtn=document.querySelector('#modal-training .btn-primary'); const origTxt=saveBtn?saveBtn.textContent:'';
  if(saveBtn){saveBtn.disabled=true;saveBtn.textContent='Saving…';}
  try{
    if(id){ await TrSessionDB.update(id,d); toast('Training updated.','success'); }
    else { await TrSessionDB.create({...d,code:generateSessionCode()}); toast('Training added.','success'); }
    closeModal('training');
    renderTrainingDelivery();
  }catch(e){ /* error already surfaced */ }
  finally{ if(saveBtn){saveBtn.disabled=false;saveBtn.textContent=origTxt;} }
}

function deleteTrainingRecord(id){
  const s=TrSessionDB.byId(id); if(!s) return;
  confirm$('Delete Training',
    `Delete <strong>${Utils.esc(s.trainingProgram||'this training')}</strong>${s.batchNo?` (Batch ${Utils.esc(s.batchNo)})`:''}? This cannot be undone.`,
    'Delete',async()=>{
      try{ await TrSessionDB.delete(id); toast('Training deleted.','success'); renderTrainingDelivery(); }
      catch(e){ /* error already surfaced */ }
    }
  );
}

function _durationToMinutes(str){
  if(!str) return -1;
  const m=String(str).match(/^(\d{1,3}):([0-5]\d)$/);
  if(!m) return -1;
  return parseInt(m[1],10)*60+parseInt(m[2],10);
}
