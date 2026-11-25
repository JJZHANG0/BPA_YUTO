const view = document.querySelector('#view');
const escape = value => String(value ?? '').replace(/[&<>"']/g, char => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char]));
const cache = (key, fallback) => {
  try { return JSON.parse(localStorage.getItem('yuto.' + key)) ?? fallback; } catch { return fallback; }
};
const save = (key,value) => localStorage.setItem('yuto.' + key,JSON.stringify(value));
let profile = cache('profile',{});
let favorites = cache('favorites',[]);
let trips = cache('trips',[]);
let timer;
let renderVersion = 0;
let selectedAttraction;
let editingTrip;
const filters = {province:'',city:'',q:'',sort:'name'};
const notice = text => {
  const box = document.querySelector('#message');
  box.textContent = text;
  box.hidden = false;
  clearTimeout(timer);
  timer = setTimeout(() => { box.hidden = true; },3000);
};
async function api(path,body) {
  const response = await fetch('/api/' + path, body === undefined ? {} : {
    method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify(body)
  });
  const result = await response.json();
  if (!response.ok) throw Error(result.error || '请求失败，请稍后重试。');
  return result;
}
const option = (value,label,selected) => `<option value="${escape(value)}" ${value === selected ? 'selected' : ''}>${escape(label)}</option>`;
const field = (name,label,values,current) => `<label>${label}<select name="${name}">${option('','请选择',current ?? '')}${values.map(v=>option(v,v,current)).join('')}</select></label>`;
function cards(items) {
  if (!items.length) return '<p class="empty">没有找到符合条件的景区。试试其他地区或关键词。</p>';
  return `<div class="grid">${items.map(a=>`<a class="card" href="#attraction/${escape(a.id)}"><div class="placeholder" aria-hidden="true"></div><div class="card-body">
    <span class="tag">${escape(a.city)} · ${escape(a.grade || '景区')}</span><h3>${escape(a.name)}</h3>
    <p>${a.match != null ? '个人匹配度 '+a.match+' 分' : a.score != null ? '银发友好度 '+a.score+' 分' : '银发友好度待确认'}</p>
    ${a.reminders?.length ? `<p>${escape(a.reminders.slice(0,2).join('、'))}</p>` : ''}
  </div></a>`).join('')}</div>`;
}
async function home() {
  const items = await api('recommendations',{profile});
  const featured = profile.aid || profile.walk ? [] : (await Promise.all(['西湖风景','苏州园林','鼓浪屿'].map(q=>api('attractions?'+new URLSearchParams({q}))))).map(results=>results[0]).filter(Boolean);
  const ranked = items.some(a=>a.match != null) ? items : [...featured,...items.filter(a=>!featured.includes(a))];
  return `<section class="hero"><div class="hero-copy"><div class="greeting">您好${profile.nickname ? '，'+escape(profile.nickname) : ''} · 欢迎来到悠途</div>
    <h1>今天，想去哪里走走？</h1><p>找到真正适合自己的旅行目的地。</p>
    <form id="home-search" class="search"><input name="q" aria-label="搜索景区、城市或旅行需求" placeholder="搜景区、城市，或说说您想怎么玩" required maxlength="250"><button>搜索</button></form>
    </div><img src="/hero.jpg" alt="湖畔园林微缩模型，悠途品牌插画" width="1536" height="1024"></section>
    <div class="shortcut"><a class="button secondary" href="#match">适合我的目的地</a><a class="button plain" href="#discover">探索全国景区</a><a class="button plain" href="#trips">规划行程</a></div>
    <div class="section-head"><h2>为您精选</h2><a href="#discover">查看全部</a></div>${cards(ranked.slice(0,3))}`;
}
async function discover() {
  const [provinces,cities,items] = await Promise.all([
    api('provinces'),filters.province ? api('cities?province='+encodeURIComponent(filters.province)) : [],
    api('attractions?'+new URLSearchParams({province:filters.province,city:filters.city,q:filters.q}))
  ]);
  items.sort(filters.sort==='score' ? (a,b)=>(b.score??-1)-(a.score??-1) : (a,b)=>a.name.localeCompare(b.name,'zh-CN'));
  return `<h1>发现目的地</h1><form id="discover-form" class="stack">
    <div class="filters"><label>省份<select name="province">${option('','全国',filters.province)}${provinces.map(p=>option(p.name,p.name,filters.province)).join('')}</select></label>
    <label>城市<select name="city" ${cities.length?'':'disabled'}>${option('','全部城市',filters.city)}${cities.map(c=>option(c.name,c.name,filters.city)).join('')}</select></label>
    <label>排序<select name="sort">${option('name','按名称',filters.sort)}${option('score','按银发友好度',filters.sort)}</select></label></div>
    <div class="search"><input name="q" value="${escape(filters.q)}" aria-label="按名称搜索" placeholder="输入景区或城市名称"><button>筛选</button></div>
    </form><div class="section-head"><h2>景区</h2><small>共 ${items.length} 个</small></div>${cards(items)}`;
}
async function details(id) {
  const [a,analysis] = await Promise.all([api('attractions/'+encodeURIComponent(id)),api('attractions/'+encodeURIComponent(id)+'/analysis')]);
  selectedAttraction = a;
  return `<div class="stack"><a class="back" href="#discover">返回发现</a>
    <section class="detail-head"><span>${escape(a.province)} · ${escape(a.city)} · ${escape(a.grade)} 景区</span><h1>${escape(a.name)}</h1><div class="actions">
      <button data-action="favorite">${favorites.includes(a.id)?'取消收藏':'收藏景区'}</button>
      <button class="secondary" data-action="plan">加入行程</button><button class="plain" data-action="share">分享给家人</button></div></section>
    <section class="panel"><h2>银发友好度</h2><p class="score">${a.score==null?'待确认':a.score+' / 100'}</p><p>${escape(a.grade && a.score != null ? '依据已确认的游览条件计算。' : a.notice)}</p></section>
    <section class="panel"><h2>游览条件</h2>${a.dimensions.map(d=>`<div class="condition"><h3>${escape(d.name)}</h3><p>${d.conditions.every(c=>!c.confirmed)?'尚待确认':d.conditions.map(c=>escape(c.name)+(c.confirmed?'已核实':'待确认')).join('、')}</p></div>`).join('')}</section>
    <section class="panel"><h2>悠途出行建议</h2><p>${escape(analysis.recommendation)}</p>${analysis.strengths.length?`<p>已核实的优势 · ${escape(analysis.strengths.join('、'))}</p>`:''}${analysis.challenges.length?`<p>需要留意 · ${escape(analysis.challenges.join('、'))}</p>`:''}${analysis.focus?.length?`<p>优先确认 · ${escape(analysis.focus.join('、'))}</p>`:''}<p>${escape(analysis.notice)}</p></section>
    <section class="panel"><h2>真实旅行体验</h2><p>暂时还没有旅行体验分享。</p></section></div>`;
}
async function matching(query) {
  const found = await api('recommendations',{query,profile});
  return `<div class="stack"><h1>适合我的目的地</h1><form id="match-form" class="search"><input name="q" value="${escape(query)}" aria-label="旅行需求" placeholder="例如：想去浙江旅游，尽量少爬坡"><button>查找</button></form>
    <p>${query?'以下是相关景区。请查看需要提前确认的游览条件。':'设置旅行画像后，悠途会结合您的需求筛选。'}</p>${cards(found)}</div>`;
}
async function profilePage() {
  const items = favorites.length ? (await api('attractions')).filter(a=>favorites.includes(a.id)) : [];
  return `<div class="stack"><h1>我的悠途</h1><form class="panel stack" id="profile-form"><h2>旅行画像</h2><p>您可以跳过或随时修改。设置保存在当前浏览器，匹配时用于筛选景区。</p><div class="form-grid">
  <label>昵称<input name="nickname" value="${escape(profile.nickname)}" maxlength="30"></label>
  ${field('age','年龄区间',['55岁以下','55–64岁','65–74岁','75岁及以上'],profile.age)}
  ${field('walk','日常步行',['短距离','可独立步行'],profile.walk)}
  ${field('stairs','上下台阶',['尽量避免','可走少量台阶','可以接受'],profile.stairs)}
  ${field('standing','站立与休息',['需要常休息','可以长时间站立'],profile.standing)}
  ${field('aid','辅助工具',['不需要','手杖','轮椅'],profile.aid)}
  ${field('slope','坡道与登山',['尽量避免','可接受缓坡','可以登山'],profile.slope)}
  ${field('interest','旅行偏好',['自然风景','历史文化','城市休闲','温泉康养','轻松度假','家庭旅行'],profile.interest)}
  ${field('pace','旅行节奏',['轻松','适中'],profile.pace)}
  <label><input name="large" type="checkbox" ${profile.large?'checked':''}>使用大字号</label></div>
  <div class="actions"><button>保存设置</button><button type="button" class="plain" data-action="clear-profile">清除旅行画像</button></div></form>
  <h2>我的收藏</h2>${items.length?cards(items):'<p>您还没有收藏景区。</p>'}</div>`;
}
async function tripPage() {
  const current = trips.find(t=>t.key===editingTrip);
  const items = await api('attractions');
  const selected = current?.destination || selectedAttraction?.id || '';
  return `<div class="stack"><h1>我的行程</h1><form class="panel stack" id="trip-form"><h2>${current?'修改行程':'创建旅行计划'}</h2>
    <div class="form-grid"><label>出发城市<input name="origin" value="${escape(current?.origin)}" maxlength="50"></label>
    <label>第一站<select name="destination" required>${option('','请选择景区',selected)}${items.map(a=>option(a.id,a.city+' · '+a.name,selected)).join('')}</select></label>
    <label>出行日期<input name="date" type="date" value="${escape(current?.date)}"></label>
    <label>旅行天数<input name="days" type="number" min="1" max="14" value="${current?.days || 2}" required></label>
    <label>同行人数<input name="people" type="number" min="1" max="30" value="${current?.people || 2}" required></label>
    ${field('pace','旅行节奏',['轻松','适中'],current?.pace || profile.pace || '轻松')}</div><button>生成并保存行程</button></form>
    <h2>已保存行程</h2>${trips.length ? trips.map(t=>`<section class="panel stack"><h3>${escape(t.entries[0]?.name)} · ${t.days} 天</h3>
    <p>${escape(t.date || '日期待定')} · ${t.people} 人 · ${t.done?'已完成':'待出发'}</p>
    ${t.entries.map((day,i)=>`<div class="plan-row"><strong>第 ${i+1} 天 · ${escape(day.name)}</strong><small>${escape(day.note)}</small></div>`).join('')}
    <div class="actions"><button class="secondary" data-edit="${escape(t.key)}">修改</button><button class="plain" data-done="${escape(t.key)}">${t.done?'设为待出发':'标记完成'}</button><button class="plain" data-delete="${escape(t.key)}">删除</button></div></section>`).join('') : '<p>还没有保存的行程。</p>'}</div>`;
}
async function render() {
  const version = ++renderVersion;
  const [route,argument=''] = (location.hash.slice(1) || 'home').split('/');
  const pages = {home,discover,attraction:()=>details(argument),match:()=>matching(decodeURIComponent(argument)),profile:profilePage,trips:tripPage};
  for (const link of document.querySelectorAll('.dock a')) {
    if (link.hash === '#'+(route==='attraction'||route==='match'?'discover':route)) link.setAttribute('aria-current','page');
    else link.removeAttribute('aria-current');
  }
  document.documentElement.style.fontSize = profile.large ? '21px' : '';
  try {
    const markup = await (pages[route] || home)();
    if (version === renderVersion) view.innerHTML = markup;
  } catch (error) {
    if (version === renderVersion) view.innerHTML = `<p>${escape(error.message)}</p><button data-action="retry">重试</button>`;
  }
}
function changeQuery(query) {
  const target = '#match/'+encodeURIComponent(query.trim());
  if (location.hash === target) render();
  else location.hash = target;
}
view.addEventListener('submit', async event => {
  event.preventDefault();
  const form = event.target;
  const data = Object.fromEntries(new FormData(form));
  try {
    if (['home-search','match-form'].includes(form.id)) changeQuery(data.q);
    if (form.id==='discover-form') {
      Object.assign(filters,data);
      render();
    }
    if (form.id==='profile-form') {
      profile = data;
      save('profile',profile);
      render();
      notice('已保存旅行画像');
    }
    if (form.id==='trip-form') {
      const button = form.querySelector('button');
      button.disabled = true;
      try {
        const attraction = await api('attractions/'+data.destination);
        const entries = await api('trips',{...data,province:attraction.province,city:attraction.city,first:data.destination,profile});
        const prior = trips.find(t=>t.key===editingTrip);
        const item = {...data, entries, key:prior?.key || (crypto.randomUUID?.() ?? String(Date.now())), done:prior?.done || false};
        trips = [item,...trips.filter(t=>t.key!==item.key)];
        save('trips',trips);
        editingTrip = undefined;
        selectedAttraction = undefined;
        render();
        notice('已保存行程');
      } finally { button.disabled = false; }
    }
  } catch (error) { notice(error.message); }
});
view.addEventListener('change',event=>{
  if (event.target.form?.id!=='discover-form' || event.target.tagName!=='SELECT') return;
  Object.assign(filters,Object.fromEntries(new FormData(event.target.form)));
  if (event.target.name==='province') filters.city = '';
  render();
});
view.addEventListener('click',async event=>{
  const button = event.target.closest('button');
  if (!button) return;
  try {
    switch (button.dataset.action) {
      case 'retry': render(); break;
      case 'favorite':
        favorites = favorites.includes(selectedAttraction.id) ? favorites.filter(id=>id!==selectedAttraction.id) : [...favorites,selectedAttraction.id];
        save('favorites',favorites); render(); break;
      case 'plan': editingTrip = undefined; location.hash='trips'; break;
      case 'share':
        if (navigator.share) await navigator.share({title:selectedAttraction.name,url:location.href});
        else if (navigator.clipboard) { await navigator.clipboard.writeText(location.href); notice('已复制地点链接'); }
        else notice('可从地址栏复制地点链接');
        break;
      case 'clear-profile':
        if (confirm('清除当前浏览器保存的旅行画像？')) { profile={}; save('profile',profile); render(); }
        break;
    }
    if (button.dataset.edit) { editingTrip=button.dataset.edit; render(); window.scrollTo(0,0); }
    if (button.dataset.done) {
      trips = trips.map(t=>t.key===button.dataset.done?{...t,done:!t.done}:t);
      save('trips',trips); render();
    }
    if (button.dataset.delete && confirm('删除这份旅行计划？')) {
      trips=trips.filter(t=>t.key!==button.dataset.delete);
      save('trips',trips); render();
    }
  } catch (error) { if (error.name!=='AbortError') notice(error.message); }
});
window.addEventListener('hashchange',async()=>{ await render(); window.scrollTo(0,0); view.focus({preventScroll:true}); });
render();
