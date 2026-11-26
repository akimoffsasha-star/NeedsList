const sb = supabase.createClient(APP_CONFIG.SUPABASE_URL, APP_CONFIG.SUPABASE_ANON_KEY);
const $ = id => document.getElementById(id);
const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const fmt = n => Number(n || 0).toLocaleString('uk-UA', {minimumFractionDigits: 2, maximumFractionDigits: 2});
const STATUS = {new: 'Нова', approved: 'Схвалена', rejected: 'Відхилена'};
async function getUser() {
  const {data: {session}} = await sb.auth.getSession();
  if (!session) return null;
  const {data: profile} = await sb.from('nl_profiles')
    .select('role,enterprise_id').eq('user_id', session.user.id).maybeSingle();
  if (!profile) return null;
  if (profile.enterprise_id) {
    const {data: e} = await sb.from('nl_enterprises').select('name').eq('id', profile.enterprise_id).maybeSingle();
    profile.enterprises = e;
  }
  return {session, profile};
}
function home(role) { location.href = role === 'admin' ? 'admin.html' : 'enterprise.html'; }
async function requireUser(role) {
  const u = await getUser();
  if (!u) { location.href = 'index.html'; return null; }
  if (role && u.profile.role !== role) { home(u.profile.role); return null; }
  return u;
}
async function logout() { await sb.auth.signOut(); location.href = 'index.html'; }
function topbar(u) {
  const adm = u.profile.role === 'admin', page = location.pathname.split('/').pop();
  const links = [[adm ? 'admin.html' : 'enterprise.html', adm ? 'Адміністратор' : 'Мої потреби'], ...(adm ? [['dashboard.html', 'Головна аналітика'], ['qa.html', 'Контроль якості'], ['proposal.html', 'Проєктна пропозиція'], ['portfolio.html', 'Портфель проєктів'], ['monitoring.html', 'Моніторинг / M&E'], ['assistance.html', 'Міжнародна допомога']] : []), ['reports.html', 'Звіти / запити']];
  $('top').innerHTML = links.map(([h, l]) => `<a href="${h}" class="${page === h ? 'on' : ''}">${l}</a>`).join('') +
    `<span class="sp"></span><span>${esc(adm ? 'Адміністратор' : u.profile.enterprises.name)}</span><button class="ghost" onclick="logout()">Вийти</button>`;
}
// універсальна таблиця для редагування довідників
async function crud(table, cols, box) {
  const {data} = await sb.from(table).select('*').order(cols[0][0]);
  const again = () => crud(table, cols, box);
  box.innerHTML = `<table><tr>${cols.map(c => `<th>${c[1]}</th>`).join('')}<th></th></tr>` +
    [...(data || []), {}].map(r => `<tr data-id="${r.id ?? ''}">${cols.map(c => `<td><input data-k="${c[0]}" value="${esc(r[c[0]])}"></td>`).join('')}
    <td><button class="s">${r.id ? 'Зберегти' : 'Додати'}</button>${r.id ? ' <button class="d danger">✕</button>' : ''}</td></tr>`).join('') + '</table>';
  box.querySelectorAll('tr[data-id]').forEach(tr => {
    const id = tr.dataset.id;
    tr.querySelector('.s').onclick = async () => {
      const rec = {}; tr.querySelectorAll('input').forEach(i => rec[i.dataset.k] = i.value.trim() || null);
      const {error} = await (id ? sb.from(table).update(rec).eq('id', id) : sb.from(table).insert(rec));
      if (error) return alert(error.message); again();
    };
    const d = tr.querySelector('.d');
    if (d) d.onclick = async () => {
      if (!confirm('Видалити запис? Для підприємства будуть видалені й усі його потреби.')) return;
      const {error} = await sb.from(table).delete().eq('id', id);
      if (error) return alert(error.message); again();
    };
  });
}