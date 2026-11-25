const get = id => document.getElementById(id);
let token;
const labels = {provinces:'省份',cities:'城市',attractions:'景区',images:'图片',analyses:'分析'};
function make(tag,text,css) {
  const node = document.createElement(tag);
  node.textContent = text;
  if (css) node.className = css;
  return node;
}
async function request(path, body) {
  const options = {headers:{Authorization:'Bearer '+token,'Content-Type':'application/json'}};
  if (body) Object.assign(options,{method:'POST', body:JSON.stringify(body)});
  const response = await fetch('/api/admin'+path,options);
  const result = await response.json();
  if (!response.ok) throw Error(result.error);
  return result;
}
async function refresh() {
  try {
    const data = await request('');
    get('dashboard').hidden = false;
    get('status').textContent = '已刷新';
    get('counts').replaceChildren(...Object.entries(data.counts).map(([key,count])=>make('div',labels[key]+' · '+count,'panel')));
    get('sources').replaceChildren(...data.sources.map(s=>make('li',s.url)));
    get('logs').replaceChildren(...data.logs.map(l=>make('li',l.created+' · '+l.message)));
    get('jobs').replaceChildren(...data.jobs.map(job=>{
      const row = make('div','#'+job.id+' · '+job.state+' · 已处理 '+job.progress,'plan-row');
      const action = {FAILED:'retry',PAUSED:'resume',PENDING:'pause'}[job.state];
      if (action) {
        const button = make('button',{retry:'重试',resume:'继续',pause:'暂停'}[action],'secondary');
        button.addEventListener('click',()=>manage({id:job.id,action}));
        row.append(button);
      }
      return row;
    }));
  } catch (error) { get('dashboard').hidden = true; get('status').textContent = error.message; }
}
async function manage(body) {
  try { await request('/jobs',body); await refresh(); }
  catch (error) { get('status').textContent = error.message; }
}
get('login').addEventListener('submit',event=>{event.preventDefault(); token=new FormData(event.target).get('token'); event.target.reset(); refresh();});
get('queue').addEventListener('submit',event=>{event.preventDefault(); manage(Object.fromEntries(new FormData(event.target)));});
get('refresh').addEventListener('click',refresh);
async function showEvidence() {
  const form = get('evidence');
  const data = await request('/evidence?id='+encodeURIComponent(form.elements.id.value));
  form.elements.field.replaceChildren(...Object.entries(data.fields).map(([field,label])=>new Option(label,field)));
  get('evidence-list').replaceChildren(...data.records.map(row=>make('li',row.field+' · '+row.value+' · '+row.status+' · '+row.source)));
}
async function loadEvidence() {
  try {
    const response = await fetch('/api/attractions');
    if (!response.ok) throw Error('无法读取景区');
    const items = await response.json();
    get('evidence').elements.id.replaceChildren(...items.map(a=>new Option(a.city+' · '+a.name,a.id)));
    await showEvidence();
  } catch (error) { get('status').textContent = error.message; }
}
get('login').addEventListener('submit',loadEvidence);
get('evidence').elements.id.addEventListener('change',()=>showEvidence().catch(error=>{get('status').textContent=error.message;}));
get('evidence').addEventListener('submit',async event=>{
  event.preventDefault();
  try {
    await request('/evidence',Object.fromEntries(new FormData(event.target)));
    await showEvidence();
    await refresh();
    get('status').textContent='已保存并重新计算';
  } catch (error) { get('status').textContent=error.message; }
});
