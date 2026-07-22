/* =========================================================================
   SKELORA INSTITUTE LOGISTICS SIMULATOR — OFFLINE AUTH & PROGRESS STORE
   No backend. Everything lives in this browser's localStorage, so accounts
   and progress are specific to the computer/browser they were created on.
   This file is shared by login.html, the dashboard, and the workstation.
   ========================================================================= */

const SKELORA_USERS_KEY   = 'skelora_users_v1';
const SKELORA_SESSION_KEY = 'skelora_session_v1';
const SKELORA_PROGRESS_PREFIX = 'skelora_progress_v1_';

/* ---------------------------------------------------------------------
   Internal helpers
   --------------------------------------------------------------------- */
function _sk_loadUsers(){
  try { return JSON.parse(localStorage.getItem(SKELORA_USERS_KEY)) || []; }
  catch(e){ return []; }
}
function _sk_saveUsers(users){
  localStorage.setItem(SKELORA_USERS_KEY, JSON.stringify(users));
}
// Simple non-cryptographic hash — this is an offline training simulator,
// not a system holding real credentials, so this is intentionally lightweight.
function _sk_hash(str){
  let h = 0;
  for(let i=0;i<str.length;i++){ h = (h<<5)-h + str.charCodeAt(i); h |= 0; }
  return 'h'+h;
}
function _sk_initials(name){
  const parts = (name||'').trim().split(/\s+/).filter(Boolean);
  if(parts.length===0) return '??';
  if(parts.length===1) return parts[0].slice(0,2).toUpperCase();
  return (parts[0][0]+parts[parts.length-1][0]).toUpperCase();
}

/* ---------------------------------------------------------------------
   Accounts
   --------------------------------------------------------------------- */
function skSignUp({name, email, password, role}){
  name = (name||'').trim();
  email = (email||'').trim().toLowerCase();
  if(!name || !email || !password) return {ok:false, error:'Please fill in your name, email, and password.'};
  const users = _sk_loadUsers();
  if(users.some(u=>u.email===email)){
    return {ok:false, error:'An account with this email already exists on this computer. Try signing in instead.'};
  }
  const user = {
    id: 'u_' + Date.now().toString(36) + Math.random().toString(36).slice(2,7),
    name, email,
    passHash: _sk_hash(password),
    role: role==='faculty' ? 'faculty' : 'student',
    createdAt: new Date().toISOString()
  };
  users.push(user);
  _sk_saveUsers(users);
  skSetSession(user.id);
  return {ok:true, user};
}
function skLogIn(email, password){
  email = (email||'').trim().toLowerCase();
  const users = _sk_loadUsers();
  const user = users.find(u=>u.email===email);
  if(!user) return {ok:false, error:'No account found with that email on this computer. Create an account first.'};
  if(user.passHash !== _sk_hash(password)) return {ok:false, error:'Incorrect password. Please try again.'};
  skSetSession(user.id);
  return {ok:true, user};
}
function skSetSession(userId){ localStorage.setItem(SKELORA_SESSION_KEY, userId); }
function skGetSessionId(){ return localStorage.getItem(SKELORA_SESSION_KEY); }
function skLogOut(){ localStorage.removeItem(SKELORA_SESSION_KEY); }
function skGetCurrentUser(){
  const id = skGetSessionId();
  if(!id) return null;
  return _sk_loadUsers().find(u=>u.id===id) || null;
}
// Call at the top of any protected page. Redirects to login if nobody is signed in.
function skRequireAuth(){
  const u = skGetCurrentUser();
  if(!u){ window.location.href = 'login.html'; return null; }
  return u;
}
function skListAllUsers(){ return _sk_loadUsers().slice().sort((a,b)=> new Date(b.createdAt)-new Date(a.createdAt)); }
function skUpdateUser(userId, patch){
  const users = _sk_loadUsers();
  const idx = users.findIndex(u=>u.id===userId);
  if(idx===-1) return {ok:false, error:'User not found.'};
  users[idx] = {...users[idx], ...patch};
  _sk_saveUsers(users);
  return {ok:true, user:users[idx]};
}
function skChangePassword(userId, currentPassword, newPassword){
  const users = _sk_loadUsers();
  const user = users.find(u=>u.id===userId);
  if(!user) return {ok:false, error:'User not found.'};
  if(user.passHash !== _sk_hash(currentPassword)) return {ok:false, error:'Your current password is incorrect.'};
  return skUpdateUser(userId, {passHash:_sk_hash(newPassword)});
}
function skDeleteUser(userId){
  const users = _sk_loadUsers().filter(u=>u.id!==userId);
  _sk_saveUsers(users);
  localStorage.removeItem(SKELORA_PROGRESS_PREFIX+userId);
}

/* ---------------------------------------------------------------------
   Per-student exercise progress
   --------------------------------------------------------------------- */
function _sk_progressKey(userId){ return SKELORA_PROGRESS_PREFIX + userId; }
function skGetAllProgress(userId){
  try { return JSON.parse(localStorage.getItem(_sk_progressKey(userId))) || {}; }
  catch(e){ return {}; }
}
function skGetDocProgress(userId, slug){ return skGetAllProgress(userId)[slug] || null; }
function skSaveDocProgress(userId, slug, patch){
  const all = skGetAllProgress(userId);
  all[slug] = {...(all[slug]||{startedAt:new Date().toISOString()}), ...patch, updatedAt:new Date().toISOString()};
  localStorage.setItem(_sk_progressKey(userId), JSON.stringify(all));
  return all[slug];
}
function skResetUserProgress(userId){
  localStorage.removeItem(_sk_progressKey(userId));
}
function skComputeStats(userId, totalExercises){
  const all = skGetAllProgress(userId);
  const entries = Object.values(all);
  const completed = entries.filter(e=>e.status==='completed').length;
  const inProgress = entries.filter(e=>e.status==='in-progress').length;
  const notStarted = Math.max(0, totalExercises - completed - inProgress);
  const pct = totalExercises>0 ? Math.round((completed/totalExercises)*100) : 0;
  return {completed, inProgress, notStarted, total:totalExercises, pct};
}
