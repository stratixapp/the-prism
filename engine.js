/* =========================================================================
   SKELORA INSTITUTE LOGISTICS SIMULATOR — SHARED EXERCISE ENGINE
   This file is intentionally generic: it knows nothing about any specific
   document. Each document (Commercial Invoice, Bill of Lading, ...) is just
   a config object in documents-data.js. To add a new document, add a new
   config — you should not need to touch this file.
   ========================================================================= */

const ICONS = {
  check:'<circle cx="12" cy="12" r="9"/><polyline points="8,12.5 11,15.5 16,9"/>',
  x:'<line x1="6" y1="6" x2="18" y2="18"/><line x1="18" y1="6" x2="6" y2="18"/>',
  plus:'<circle cx="12" cy="12" r="9"/><line x1="12" y1="8" x2="12" y2="16"/><line x1="8" y1="12" x2="16" y2="12"/>',
  printer:'<polyline points="6,9 6,2 18,2 18,9"/><path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2"/><rect x="6" y="14" width="12" height="8"/>',
  refresh:'<polyline points="23,4 23,10 17,10"/><polyline points="1,20 1,14 7,14"/><path d="M3.5 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.65 4.36A9 9 0 0 0 20.5 15"/>',
  chevRight:'<polyline points="9,6 15,12 9,18"/>',
  chevLeft:'<polyline points="15,18 9,12 15,6"/>',
  clock:'<circle cx="12" cy="12" r="9"/><polyline points="12,7 12,12 16,14"/>'
};
const ic = (n)=>`<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${ICONS[n]||''}</svg>`;

/* ---------------------------------------------------------------------
   STATE
   --------------------------------------------------------------------- */
let CONFIG = null;
let CURRENT_SLUG = null;
let CURRENT_USER = null;
let formData = {};
let currentStep = 0;
let maxReached = 0;
let fieldErrors = new Set();
let fieldErrorMsgs = {};
let startTime = Date.now();
let timerInterval = null;

/* ---------------------------------------------------------------------
   GENERIC FIELD RENDERING
   Supported field.type: text, textarea, date, select, checkbox,
   static (read-only HTML block), computed (derived value display),
   table (repeatable rows)
   --------------------------------------------------------------------- */
function renderLearnPanel(f){
  if(!f.learn) return "";
  const l = f.learn;
  const row = (icon,label,content)=> content ? `<div style="margin-bottom:8px;"><div style="font-weight:600;font-size:11.5px;color:var(--text-2);margin-bottom:2px;">${icon} ${label}</div><div style="font-size:12.5px;color:var(--text-2);line-height:1.55;">${content}</div></div>` : "";
  return `<details class="learn-panel" style="margin-top:6px;border:1px solid var(--border);border-radius:8px;background:var(--surface-2,#F7F6F2);">
    <summary style="cursor:pointer;padding:8px 12px;font-size:12px;font-weight:600;color:var(--accent,#8A6D3B);list-style:none;">💡 Learn about this field</summary>
    <div style="padding:4px 14px 12px;">
      ${row("📖","Explanation",l.explanation)}
      ${row("🎯","Purpose",l.purpose)}
      ${row("📝","Example",l.example)}
      ${row("⚠️","Common Mistakes",l.mistakes)}
      ${row("✅","Validation",l.validation)}
      ${row("⭐","Hint",l.hint)}
    </div>
  </details>`;
}

function renderField(f){
  if(f.showIf && !f.showIf(formData)) return "";
  if(f.type==="static"){
    return `<div class="declaration-box" style="grid-column:1/-1;">${f.html}</div>`;
  }
  if(f.type==="table") return renderTableField(f);
  if(f.type==="computed") return renderComputedField(f);

  const val = formData[f.name] ?? "";
  const req = f.required ? '<span class="req">*</span>' : "";
  const errCls = fieldErrors.has(f.name) ? "field-error" : "";
  const fullCls = f.full ? "field full" : "field";

  if(f.type==="checkbox"){
    return `<div class="${fullCls}"><label class="check-row"><input type="checkbox" data-field="${f.name}" ${formData[f.name]?"checked":""}/> <span>${f.label}</span></label>${renderLearnPanel(f)}</div>`;
  }
  let input;
  if(f.type==="textarea"){
    input = `<textarea class="finput ${errCls}" data-field="${f.name}" placeholder="${f.placeholder||""}">${val}</textarea>`;
  } else if(f.type==="select"){
    input = `<select class="finput ${errCls}" data-field="${f.name}"><option value="">Select…</option>${f.options.map(o=>`<option value="${o}" ${val===o?"selected":""}>${o}</option>`).join("")}</select>`;
  } else {
    const upStyle = f.uppercase ? ' style="text-transform:uppercase;letter-spacing:.3px;"' : "";
    input = `<input class="finput ${errCls}" type="${f.type}" data-field="${f.name}" placeholder="${f.placeholder||""}" value="${val}"${upStyle}/>`;
  }
  return `<div class="${fullCls}">
    <label>${f.label}${req}</label>
    ${input}
    ${f.help?`<div class="fhelp">${f.help}</div>`:""}
    ${fieldErrors.has(f.name)?`<div class="ferr">${fieldErrorMsgs[f.name]||"This field is required."}</div>`:""}
    ${renderLearnPanel(f)}
  </div>`;
}

function renderComputedField(f){
  const value = f.compute(formData);
  const fullCls = f.full ? "field full" : "field";
  return `<div class="${fullCls}">
    <label>${f.label}</label>
    <div class="computed-box" id="computed-${f.name}">${value}</div>
    ${f.help?`<div class="fhelp">${f.help}</div>`:""}
    ${renderLearnPanel(f)}
  </div>`;
}

function renderTableField(f){
  if(!formData[f.name] || formData[f.name].length===0){
    formData[f.name] = f.defaultRows ? f.defaultRows.map(r=>({...r})) : [ emptyRow(f) ];
  }
  const rows = formData[f.name].map((row,i)=>{
    const cells = f.columns.map(col=>{
      if(col.computed){
        const v = col.computed(row);
        return `<td class="li-amount" id="cell-${f.name}-${i}-${col.key}">${v}</td>`;
      }
      return `<td><input class="li-input ${col.numeric?"li-num":""}" data-table="${f.name}" data-row="${i}" data-col="${col.key}" value="${row[col.key]||""}" placeholder="${col.placeholder||""}"/></td>`;
    }).join("");
    const removeBtn = formData[f.name].length>1 ? `<button class="li-remove" data-table-remove="${f.name}" data-row="${i}">${ic("x")}</button>` : "";
    return `<tr>${cells}<td>${removeBtn}</td></tr>`;
  }).join("");
  let footerRow = "";
  if(f.footer){
    footerRow = `<tfoot><tr>
      <td colspan="${f.columns.length-1}" style="text-align:right;font-weight:700;">${f.footer.label}</td>
      <td id="footer-${f.name}" style="font-weight:700;font-family:var(--mono);">${f.footer.compute(formData[f.name])}</td>
      <td></td>
    </tr></tfoot>`;
  }
  return `<div class="field full">
    <label>${f.label}${f.required?'<span class="req">*</span>':""}</label>
    ${f.help?`<div class="fhelp" style="margin-bottom:10px;">${f.help}</div>`:""}
    <div class="li-table-wrap"><table class="li-table">
      <thead><tr>${f.columns.map(c=>`<th>${c.label}</th>`).join("")}<th></th></tr></thead>
      <tbody id="tbody-${f.name}">${rows}</tbody>
      ${footerRow}
    </table></div>
    <button class="btn-secondary" data-table-add="${f.name}" style="margin-top:12px;">${ic("plus")} ${f.addLabel||"Add Row"}</button>
    ${fieldErrors.has(f.name)?`<div class="ferr" style="margin-top:8px;">${f.errorMsg||"Please complete at least one row."}</div>`:""}
  </div>`;
}
function emptyRow(f){ const r={}; f.columns.forEach(c=>{ if(!c.computed) r[c.key]=""; }); return r; }

/* Recompute a table's row + footer without a full re-render (keeps input focus) */
function refreshTableRow(tableName, rowIdx){
  const f = findFieldByName(tableName);
  if(!f) return;
  const row = formData[tableName][rowIdx];
  f.columns.forEach(col=>{
    if(col.computed){
      const cell = document.getElementById(`cell-${tableName}-${rowIdx}-${col.key}`);
      if(cell) cell.textContent = col.computed(row);
    }
  });
  if(f.footer){
    const footCell = document.getElementById(`footer-${tableName}`);
    if(footCell) footCell.textContent = f.footer.compute(formData[tableName]);
  }
  refreshDependentComputed(tableName);
}
function findFieldByName(name){
  for(const step of CONFIG.steps){
    if(step.fields){
      const f = step.fields.find(x=>x.name===name);
      if(f) return f;
    }
  }
  return null;
}

/* Update any top-level "computed" field whose deps include the changed field/table */
function refreshDependentComputed(changedName){
  CONFIG.steps.forEach(step=>{
    if(!step.fields) return;
    step.fields.forEach(f=>{
      if(f.type==="computed" && f.deps && f.deps.includes(changedName)){
        const el = document.getElementById(`computed-${f.name}`);
        if(el) el.textContent = f.compute(formData);
      }
    });
  });
}

/* ---------------------------------------------------------------------
   STEP RENDERING
   --------------------------------------------------------------------- */
const stepBody = () => document.getElementById("stepBody");

function renderStep(idx){
  const step = CONFIG.steps[idx];
  document.getElementById("stepEyebrow").textContent = `Step ${idx+1} of ${CONFIG.steps.length} · ~${step.est} min`;
  document.getElementById("stepTitle").textContent = step.title;
  document.getElementById("stepSub").textContent = step.sub || "";
  document.getElementById("progressPill").textContent = `Step ${idx+1} of ${CONFIG.steps.length}`;

  let html = "";
  if(step.intro) html += `<div class="step-intro">${step.intro}</div>`;

  if(step.custom==="review"){
    html += wrapAsLetterhead(step.renderReview(formData));
  } else if(step.custom==="complete"){
    html += renderComplete();
  } else {
    html += `<div class="field-grid">${(step.fields||[]).map(renderField).join("")}</div>`;
  }
  stepBody().innerHTML = html;

  document.getElementById("backBtn").disabled = (idx===0);
  const nextBtn = document.getElementById("nextBtn");
  if(idx===CONFIG.steps.length-1){
    nextBtn.style.display = "none";
  } else if(step.custom==="review"){
    nextBtn.style.display = "flex";
    nextBtn.innerHTML = `Mark Complete ${ic("check")}`;
  } else {
    nextBtn.style.display = "flex";
    nextBtn.innerHTML = `Save & Continue ${ic("chevRight")}`;
  }
  renderTracker();
  bindStepButtons(step);
}

/* ---------------------------------------------------------------------
   PROGRESS PERSISTENCE (offline, per-student, this computer only)
   --------------------------------------------------------------------- */
function saveProgressSnapshot(status){
  if(!CURRENT_USER || !CURRENT_SLUG) return;
  skSaveDocProgress(CURRENT_USER.id, CURRENT_SLUG, {
    status,
    currentStep,
    maxReached,
    formData,
    docTitle: CONFIG.title
  });
}

/* ---------------------------------------------------------------------
   GENERIC LETTERHEAD WRAPPER
   Every one of the 11 (and future) exercise configs already renders its
   own review document via renderReview(). This wraps that output in a
   shared, professional letterhead — company name, doc-type/number,
   watermark, footer metadata, and a terms strip — without any config
   needing to know about it.
   --------------------------------------------------------------------- */
let letterheadMeta = null;
function getLetterheadMeta(){
  if(!letterheadMeta){
    letterheadMeta = {
      docId: "DOC-" + Math.random().toString(36).slice(2,10).toUpperCase(),
      verifyCode: Math.random().toString(36).slice(2,10).toUpperCase()
    };
  }
  return letterheadMeta;
}
const ISSUER_NAME_FIELDS = ["terminalName","carrierName","oceanCarrier","airlineName","issuingBankName","bankName","insuranceCompany","transporterName","vendorName","accreditedAgencyName","labName","inspectionAgency","packerCompanyName","preparedByCompany","warehouseNameOnReceipt","manufacturerName",
  "consignorName","expName","exporterName","exporterNamePhyto","importerName","shipperName","buyerName","supName","supplierName","applicantName","beneficiaryName","sellerName","fromName","drawerName","shippingLineName"];
const DOC_NUMBER_FIELDS = ["jobNumber","igmNumber","requestNumber","referenceNo","billNo","creditNoteNo","debitNoteNo","receiptNo","invoiceNo","blNumber","plNumber","lrNumber","grnNumber","flightNumber","documentNumber",
  "certificateNo","bgNumber","swbNumber",
  "lcNumber","poNumber","mawbNumber","blAwbNo",
  "packingListNo","challanNo","leoNumber","lcNo","deliveryNoteNo","ewayBillNo",
  "awbNumber","sbNumberGenerated","beNumberGenerated","lcMt700Ref","ebnGenerated","swbNumberGenerated","soNumberGenerated","proformaNo","mrNumberGenerated","declarationNo","dutyWorksheetNo","whrNumberGenerated","msdsNo","oocNumberGenerated","bookingNo","podNumber"];

function firstNonEmpty(fields, data){
  for(const f of fields){ if(data[f] && String(data[f]).trim()) return data[f]; }
  return null;
}

function wrapAsLetterhead(innerHtml){
  const issuer = firstNonEmpty(ISSUER_NAME_FIELDS, formData) || "Skelora Institute Logistics Simulator";
  const docNumber = firstNonEmpty(DOC_NUMBER_FIELDS, formData) || CONFIG.docCodeExample;
  const meta = getLetterheadMeta();
  const placeOfIssue = firstNonEmpty(["placeOfIssue","portOfLoading","originCity","issuePlace","signPlace"], formData) || "—";
  const issueDate = firstNonEmpty(["shippedOnBoardDate","issueDate","dateOfIssue","jobDate","importDate","invoiceDate","docDate","signDate"], formData) || new Date().toISOString().slice(0,10);
  return `<div class="doc-letterhead">
    <div class="doc-watermark"><span>${CONFIG.title}</span></div>
    <div class="doc-lh-head">
      <div>
        <div class="doc-lh-name">${issuer}</div>
        <div class="doc-lh-sub">${CONFIG.subtitle}</div>
      </div>
      <div class="doc-lh-type">
        <div class="t">${CONFIG.title}</div>
        <div class="n">No. ${docNumber}</div>
      </div>
    </div>
    <div class="doc-lh-rule"></div>
    ${innerHtml}
    <div class="doc-stamp-row">
      <div>
        <div style="font-size:11.5px;color:var(--text-2);margin-bottom:10px;">Issued: <b>${issueDate}</b> — Place of Issue: <b>${placeOfIssue}</b></div>
        <div class="doc-stamp-circle">Official<br>Stamp Area</div>
      </div>
      <div class="doc-sig-blank">
        <div class="box"></div>
        <div class="cap">Authorized Signatory — ${issuer}</div>
      </div>
    </div>
    <div class="doc-footer-meta">
      <span>Document ID: ${meta.docId}</span>
      <span>Verification Code: ${meta.verifyCode}</span>
      <span>Issued: ${new Date().toISOString()}</span>
      <span>Rev. 1 · Page 1 of 1</span>
    </div>
    <div class="doc-terms">
      <h5>Terms &amp; Conditions (Training Reference Copy)</h5>
      <ol>
        <li>This document is a specimen produced for educational purposes within a training simulation and carries no legal or commercial validity.</li>
        <li>In practice, the issuer's full liability terms, jurisdiction, and governing conventions would be printed in full on the reverse of an original document.</li>
        <li>The party who supplied these particulars warrants their accuracy; the simulator does not verify them against any real-world registry.</li>
        <li>This training document should be used strictly for classroom, assessment, and simulation purposes.</li>
      </ol>
    </div>
  </div>`;
}

function renderComplete(){
  clearInterval(timerInterval);
  const secs = Math.floor((Date.now()-startTime)/1000);
  const mm = String(Math.floor(secs/60)).padStart(2,"0"), ss=String(secs%60).padStart(2,"0");
  saveProgressSnapshot("completed");
  return `<div class="cert">
    <div class="cert-ic">${ic("check")}</div>
    <h2>Exercise Completed</h2>
    <p>${CONFIG.completionMessage}</p>
    <div class="cert-stats">
      <div class="cert-stat"><div class="v">${CONFIG.docCodeExample}</div><div class="l">Document Number Assigned</div></div>
      <div class="cert-stat"><div class="v">${mm}:${ss}</div><div class="l">Time Taken</div></div>
      <div class="cert-stat"><div class="v">${CONFIG.steps.length} / ${CONFIG.steps.length}</div><div class="l">Sections Completed</div></div>
    </div>
    <div class="cert-actions">
      <button class="btn-secondary" id="restartBtn">${ic("refresh")} Restart Exercise</button>
      <button class="btn-secondary" id="reviewAgainBtn">Review Document Again</button>
      <a class="btn-secondary" href="skelora-institute-dashboard.html">Back to Document Library</a>
    </div>
  </div>`;
}

function bindStepButtons(step){
  const printBtn = document.getElementById("printBtn");
  if(printBtn) printBtn.addEventListener("click", ()=>window.print());
  const restartBtn = document.getElementById("restartBtn");
  if(restartBtn) restartBtn.addEventListener("click", ()=>{
    formData = {};
    currentStep = 0; maxReached = 0; fieldErrors.clear();
    startTime = Date.now();
    letterheadMeta = null;
    clearInterval(timerInterval); timerInterval = setInterval(updateTimer,1000);
    if(CURRENT_USER && CURRENT_SLUG) skSaveDocProgress(CURRENT_USER.id, CURRENT_SLUG, {status:'in-progress', currentStep:0, maxReached:0, formData:{}, docTitle:CONFIG.title});
    renderStep(0);
  });
  const reviewAgainBtn = document.getElementById("reviewAgainBtn");
  if(reviewAgainBtn) reviewAgainBtn.addEventListener("click", ()=>{
    const reviewIdx = CONFIG.steps.findIndex(s=>s.custom==="review");
    currentStep = reviewIdx; renderStep(currentStep);
  });
}

/* ---------------------------------------------------------------------
   TRACKER
   --------------------------------------------------------------------- */
function renderTracker(){
  const t = document.getElementById("tracker");
  t.innerHTML = CONFIG.steps.map((s,i)=>{
    let cls = "track-item";
    if(i===currentStep) cls+=" current";
    else if(i<=maxReached) cls+=" done";
    const showCheck = (i<maxReached || i<currentStep);
    const num = showCheck ? `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" style="width:12px;height:12px;"><polyline points="20,6 9,17 4,12"/></svg>` : (i+1);
    return `<div class="${cls}" data-step="${i}">
      <div class="track-num">${num}</div>
      <div class="track-text"><div class="track-title">${s.title}</div><div class="track-time">~${s.est} min</div></div>
    </div>`;
  }).join("");
  t.querySelectorAll(".track-item").forEach(el=>{
    el.addEventListener("click", ()=>{
      const idx = +el.dataset.step;
      if(idx<=maxReached || idx===currentStep){ currentStep=idx; renderStep(idx); window.scrollTo({top:0,behavior:"smooth"}); }
      else showToast("Complete the current section first.");
    });
  });
}

/* ---------------------------------------------------------------------
   VALIDATION
   --------------------------------------------------------------------- */
function validateStep(idx){
  const step = CONFIG.steps[idx];
  fieldErrors.clear();
  fieldErrorMsgs = {};
  let valid = true;
  (step.fields||[]).forEach(f=>{
    if(f.type==="static" || f.type==="computed") return;
    if(f.showIf && !f.showIf(formData)) return;
    if(f.type==="table"){
      if(f.required){
        const rows = formData[f.name]||[];
        const ok = rows.some(r => (f.requiredCols||[]).every(c=>r[c] && String(r[c]).trim()!==""));
        if(!ok){ fieldErrors.add(f.name); valid=false; }
      }
      // Strict per-cell pattern checks (e.g. container numbers, HS codes) on filled rows.
      if(f.cellPatterns){
        const rows = formData[f.name]||[];
        rows.forEach(r=>{
          Object.keys(f.cellPatterns).forEach(colKey=>{
            const cv = r[colKey];
            if(cv && String(cv).trim()!==""){
              const re = new RegExp(f.cellPatterns[colKey].pattern);
              if(!re.test(String(cv).trim())){ fieldErrors.add(f.name); valid=false; }
            }
          });
        });
      }
      return;
    }
    const v = formData[f.name];
    if(f.type==="checkbox"){
      if(f.required && !v){ fieldErrors.add(f.name); valid=false; }
      return;
    }
    const has = v!==undefined && v!==null && String(v).trim()!=="";
    if(f.required && !has){ fieldErrors.add(f.name); fieldErrorMsgs[f.name]=f.requiredMsg||"This field is required."; valid=false; return; }
    if(has && f.pattern){
      const re = new RegExp(f.pattern);
      if(!re.test(String(v).trim())){ fieldErrors.add(f.name); fieldErrorMsgs[f.name]=f.patternMsg||"Invalid format."; valid=false; }
    }
  });
  return valid;
}

/* ---------------------------------------------------------------------
   NAVIGATION
   --------------------------------------------------------------------- */
function goNext(){
  if(!validateStep(currentStep)){ renderStep(currentStep); showToast("Please complete the required fields before continuing."); return; }
  maxReached = Math.max(maxReached, currentStep+1);
  currentStep = Math.min(currentStep+1, CONFIG.steps.length-1);
  saveProgressSnapshot('in-progress');
  renderStep(currentStep);
  window.scrollTo({top:0,behavior:"smooth"});
}
function goBack(){
  if(currentStep>0){ currentStep--; renderStep(currentStep); window.scrollTo({top:0,behavior:"smooth"}); }
}

/* ---------------------------------------------------------------------
   EVENT DELEGATION (bound once, works for every step since content is
   swapped inside #stepBody)
   --------------------------------------------------------------------- */
function attachDelegation(){
  const body = stepBody();
  body.addEventListener("input", e=>{
    const t = e.target;
    if(t.dataset.field){
      const f = findFieldByName(t.dataset.field);
      let val = t.value;
      if(f && f.uppercase){ val = val.toUpperCase(); t.value = val; }
      formData[t.dataset.field] = val;
      fieldErrors.delete(t.dataset.field);
      t.classList.remove("field-error");
      refreshDependentComputed(t.dataset.field);
    } else if(t.dataset.table!==undefined){
      const tableName = t.dataset.table, rowIdx = +t.dataset.row, col = t.dataset.col;
      formData[tableName][rowIdx][col] = t.value;
      refreshTableRow(tableName, rowIdx);
    }
  });
  body.addEventListener("change", e=>{
    const t = e.target;
    if(t.type==="checkbox" && t.dataset.field){
      formData[t.dataset.field] = t.checked;
      fieldErrors.delete(t.dataset.field);
      const f = findFieldByName(t.dataset.field);
      if(f && f.reRenderOnChange) renderStep(currentStep);
    } else if(t.tagName==="SELECT" && t.dataset.field){
      formData[t.dataset.field] = t.value;
      fieldErrors.delete(t.dataset.field);
      const f = findFieldByName(t.dataset.field);
      if(f && f.reRenderOnChange) renderStep(currentStep);
    }
  });
  body.addEventListener("click", e=>{
    const addBtn = e.target.closest("[data-table-add]");
    if(addBtn){
      const name = addBtn.dataset.tableAdd;
      const f = findFieldByName(name);
      formData[name].push(emptyRow(f));
      renderStep(currentStep);
      return;
    }
    const remBtn = e.target.closest("[data-table-remove]");
    if(remBtn){
      const name = remBtn.dataset.tableRemove, row = +remBtn.dataset.row;
      formData[name].splice(row,1);
      renderStep(currentStep);
    }
  });
  document.getElementById("nextBtn").addEventListener("click", goNext);
  document.getElementById("backBtn").addEventListener("click", goBack);
}

/* ---------------------------------------------------------------------
   TIMER + TOAST
   --------------------------------------------------------------------- */
function updateTimer(){
  const secs = Math.floor((Date.now()-startTime)/1000);
  const m = String(Math.floor(secs/60)).padStart(2,"0");
  const s = String(secs%60).padStart(2,"0");
  const el = document.getElementById("timerDisplay");
  if(el) el.textContent = `${m}:${s}`;
}
let toastTimer;
function showToast(msg){
  const t = document.getElementById("toast");
  t.textContent = msg;
  t.style.opacity = "1"; t.style.transform = "translateX(-50%) translateY(0)";
  clearTimeout(toastTimer);
  toastTimer = setTimeout(()=>{ t.style.opacity="0"; t.style.transform="translateX(-50%) translateY(20px)"; }, 3200);
}

/* ---------------------------------------------------------------------
   BOOT
   --------------------------------------------------------------------- */
function boot(){
  CURRENT_USER = skRequireAuth();
  if(!CURRENT_USER) return; // skRequireAuth already redirects to login.html

  const params = new URLSearchParams(window.location.search);
  const slug = params.get("doc") || Object.keys(DOCUMENT_CONFIGS)[0];
  CURRENT_SLUG = slug;
  CONFIG = DOCUMENT_CONFIGS[slug];
  if(!CONFIG){
    document.body.innerHTML = `<div style="max-width:560px;margin:80px auto;text-align:center;font-family:sans-serif;color:#5B6472;">
      <h2 style="color:#101828;">Exercise not found</h2>
      <p>No fill-in exercise is configured for "<b>${slug}</b>" yet.</p>
      <a href="skelora-institute-dashboard.html" style="color:#1F6FEB;font-weight:700;">← Back to Document Library</a>
    </div>`;
    return;
  }
  document.title = `${CONFIG.title} — Fill & Learn Exercise | Skelora Institute Logistics Simulator`;
  document.getElementById("tbTitle1").textContent = CONFIG.title;
  document.getElementById("tbTitle2").textContent = CONFIG.subtitle;
  document.getElementById("bannerEyebrow").textContent = CONFIG.moduleLabel;
  document.getElementById("bannerTitle").textContent = CONFIG.heroTitle;
  document.getElementById("bannerDesc").textContent = CONFIG.heroDesc;
  document.getElementById("bannerObjectives").innerHTML = CONFIG.objectives.map(o=>
    `<li><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><polyline points="20,6 9,17 4,12"/></svg>${o}</li>`
  ).join("");

  // Resume saved progress for this student, if any exists on this computer.
  const saved = skGetDocProgress(CURRENT_USER.id, slug);
  const alreadyCompleted = saved && saved.status === 'completed';
  if(saved && saved.formData && !alreadyCompleted){
    formData = saved.formData || {};
    currentStep = Math.min(saved.currentStep || 0, CONFIG.steps.length-1);
    maxReached = saved.maxReached || 0;
  } else {
    formData = {};
    currentStep = 0; maxReached = 0;
  }
  fieldErrors.clear();
  startTime = Date.now();
  letterheadMeta = null;
  timerInterval = setInterval(updateTimer, 1000);

  attachDelegation();
  renderStep(currentStep);
  if(saved && saved.formData && !alreadyCompleted && currentStep>0){
    showToast(`Resuming your saved progress on ${CONFIG.title}.`);
  } else if(alreadyCompleted){
    showToast(`You already completed this exercise — starting a fresh attempt.`);
    formData = {}; currentStep = 0; maxReached = 0;
    renderStep(0);
  }
}
document.addEventListener("DOMContentLoaded", boot);
