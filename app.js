const $ = id => document.getElementById(id)
const node = (tag,text,cls) => {
  const el=document.createElement(tag)
  if(text!==undefined) el.textContent=text
  if(cls) el.className=cls
  return el
}
const button=(text,act,cls)=>{const b=node('button',text,cls); b.type='button'; b.onclick=act; return b}
const pad=n=>String(n).padStart(2,'0')
const today=()=>{const d=new Date();return [d.getFullYear(),pad(d.getMonth()+1),pad(d.getDate())].join('-')}
const seed=[
  {id:'sea',date:'2026-10-18',title:'沿着海岸散步',place:'厦门 · 环岛路',tag:'旅行',body:'',photos:['./sea.png']},
  {id:'cafe',date:'2026-10-12',title:'周末的咖啡馆',place:'杭州 · 天目里',tag:'日常',body:'',photos:['./cafe.png']}
]
const db=await new Promise((resolve,reject)=>{
  const req=indexedDB.open('jinse-journal-v1',2)
  req.onupgradeneeded=()=>{
    const db=req.result
    const fresh=!db.objectStoreNames.contains('entries')
    const s=fresh?db.createObjectStore('entries',{keyPath:'id'}):req.transaction.objectStore('entries')
    if(fresh)seed.forEach(e=>s.add(e))
    db.createObjectStore('covers')
    const samples=[
      ['独立开发日志','画出第一版首页','删掉重复的入口，给手记本身多留一点空间。','已完成'],
      ['独立开发日志','打磨离线体验','在地铁上记了一段话，准备到站后检查保存结果。','未完成'],
      ['独立开发日志','搁置桌面小组件','先把手机上的阅读体验做好。','暂时挂起'],
      ['海岸散步','走到白城沙滩','退潮后沿着潮线慢慢走，捡到一枚有细纹的贝壳。','已完成'],
      ['海岸散步','再去一次灯塔','想在傍晚同一个位置拍下涨潮后的样子。','未完成']]
    samples.forEach(([topic,title,body,status],i)=>s.add({id:'topic-example-'+i,topic,title,body,status,date:'2026-11-'+(20+i),tag:i<3?'日常':'旅行',place:'',photos:[]}))

  }
  req.onsuccess=()=>resolve(req.result)
  req.onerror=()=>reject(req.error)
}).catch(()=>{$('rows').textContent='无法打开本地存储，请检查浏览器的网站数据权限后刷新。';throw Error('Storage unavailable')})
function access(mode,op){
  return new Promise((resolve,reject)=>{
    const tx=db.transaction('entries',mode), req=op(tx.objectStore('entries'))
    tx.oncomplete=()=>resolve(req.result)
    tx.onabort=()=>reject(tx.error)
  })
}
let topic=localStorage.getItem('jinse-topic')||'生活手记'
const topicOf=e=>e.topic?.trim()||'生活手记'
const mark=t=>'./mark-'+({'独立开发日志':'build','海岸散步':'coast'}[t]||'life')+'.png'
const statusOf=entry=>entry.status || '未完成'
let entries=[],month='2026-10',tag='全部',day='',calendar=false,current=null,photos=[]
try{month=localStorage.getItem('jinse-month')||month}catch{}
const urls=new Map()
function picture(photo){
  const img=node('img');img.alt='记录配图';img.loading='lazy'
  if(typeof photo==='string')img.src=({'./sea.png':'./coast.jpg','./cafe.png':'./coffee.jpg'})[photo] || photo
  else {if(!urls.has(photo))urls.set(photo,URL.createObjectURL(photo));img.src=urls.get(photo)}
  return img
}
async function refresh(){
  entries=await access('readonly',s=>s.getAll())
  entries.sort((a,b)=>b.date.localeCompare(a.date)||b.id.localeCompare(a.id))
  for(const [blob,url] of urls){URL.revokeObjectURL(url);urls.delete(blob)}
  render()
}
function reset(){tag='全部';day='';$('query').value=''}
function render(){
  const route=location.hash.slice(1)
  const home=!['timeline','calendar'].includes(route)
  calendar=route==='calendar'
  $('landing').hidden=!home
  $('journal').hidden=home
  for(const link of document.querySelectorAll('.site-nav a')){
    if(link.hash===(home?'#home':location.hash))link.setAttribute('aria-current','page')
    else link.removeAttribute('aria-current')
  }
  document.body.classList.toggle('directory',home)
  if(home) renderDirectory();else if(bannerTopic!==topic)loadCover(topic)
  $('month').value=month
  try{localStorage.setItem('jinse-month',month)}catch{}
  const monthly=entries.filter(e=>topicOf(e)===topic && e.date.startsWith(month+'-'))
  const [year,number]=month.split('-')
  $('monthName').textContent=year+' 年 '+Number(number)+' 月'
  $('total').textContent=monthly.length+' 篇'
  $('heading').textContent=calendar?'手记日历':'事件'
  $('calendar').classList.toggle('on',calendar);$('timeline').classList.toggle('on',!calendar)
  $('tags').replaceChildren(...['全部','旅行','日常'].map(t=>{const b=button(t,()=>{tag=t;render()},t===tag?'on':'');b.setAttribute('aria-pressed',String(t===tag));return b}))
  const grid=$('grid');grid.hidden=!calendar;grid.replaceChildren()
  if(calendar){
    const [y,m]=month.split('-').map(Number)
    for(const w of '日一二三四五六')grid.append(node('small',w))
    for(let i=0;i<new Date(y,m-1,1).getDay();i++)grid.append(node('span'))
    for(let i=1;i<=new Date(y,m,0).getDate();i++){
      const date=month+'-'+pad(i)
      const b=button(i,()=>{day=day===date?'':date;render()})
      b.classList.toggle('marked',monthly.some(e=>e.date===date));b.classList.toggle('on',day===date);grid.append(b)
    }
  }
  const q=$('query').value.trim().toLocaleLowerCase()
  const source=q && !calendar ? entries:monthly
  const filtered=source.filter(e=>topicOf(e)===topic&&(tag==='全部'||e.tag===tag)&&(!day||e.date===day)&&[e.title,e.body,e.place].some(s=>s.toLocaleLowerCase().includes(q)))
  const rows=$('rows');rows.replaceChildren()
  let previous=''
  for(const e of filtered){
    const b=button('',()=>show(e),'record')
    b.dataset.entryId=e.id
    const info=node('div',undefined,'entry')
    const excerpt=e.body.trim()
    const meta=node('span',undefined,'meta')
    const state=statusOf(e)
    meta.append(node('small',({'已完成':'✓','未完成':'○','暂时挂起':'Ⅱ'}[state]||'')+' '+state,'event-state'),document.createTextNode(' '+[e.place,e.tag].filter(Boolean).join(' · ')))
    info.append(node('h2',e.title))
    if(e.photos.length){
      info.classList.add('with-photo')
      info.append(picture(e.photos[0]))
    }
    if(excerpt)info.append(node('div',excerpt,'snippet'))
    else if(!e.photos.length)info.classList.add('title-only')
    info.append(meta)
    if(e.date===previous)b.classList.add('same-day')
    const stamp=node('span',previous===e.date?'':e.date.slice(-2),'day')
    if(previous!==e.date)stamp.append(node('small',new Date(e.date+'T12:00:00').toLocaleDateString('zh-CN',{weekday:'long'})))
    b.append(stamp,info);rows.append(b);previous=e.date
  }
  if(!filtered.length){
    const box=node('div',undefined,'empty')
    box.append(node('p',(monthly.length||q)?'没有匹配的记录':'这个月还没有记录'),(monthly.length||q)?button('清除条件',()=>{reset();render()}):node('small','点右下角「添加事件」写下第一篇手记。'))
    rows.append(box)
  }
}
function show(e){
  current=e
  $('story').replaceChildren(node('h2',e.title),node('div',[e.date,e.place,e.tag].filter(Boolean).join(' · '),'meta'),node('p',e.body),...e.photos.map(picture))
  $('detail').showModal()
}
const form=$('form'),field=n=>form.elements.namedItem(n)
function preview(){
  $('preview').replaceChildren(...photos.map((photo,i)=>{
    const box=node('div');box.append(picture(photo),button('移除照片',()=>{photos.splice(i,1);preview()}));return box
  }))
}
function compose(e){
  current=e;photos=[...(e?.photos||[])];form.reset()
  for(const n of ['title','body','date','place','status','tag'])field(n).value=e?.[n]??({date:day||today(),tag:'日常',status:'未完成'}[n]||'')
  field('topic').value=e?topicOf(e):topic
  $('editorTitle').textContent=e?'编辑记录':'添加记录';$('error').textContent=''
  preview()
  const editor=$('editor')
  editor.showModal()
  if(!matchMedia('(prefers-reduced-motion: reduce)').matches){
    const anchor=$(e?'heading':'add').getBoundingClientRect()
    const box=editor.getBoundingClientRect()
    const dx=anchor.x+anchor.width/2-box.x-box.width/2
    const dy=anchor.y+anchor.height/2-box.y-box.height/2
    editor.animate([
      {transform:'translate('+dx+'px,'+dy+'px) scale(.09)',borderRadius:'60px',opacity:.2},
      {transform:'translate(0,0) scale(1)',borderRadius:'15px',opacity:1}
    ],{duration:340,easing:'cubic-bezier(.22,.9,.28,1)'})
  }
}
$('files').onchange=e=>{photos.push(...e.target.files);e.target.value='';preview()}
$('editor').onclose=()=>{
  photos=[];$('preview').replaceChildren()
  for(const [blob,url] of urls)if(!entries.some(e=>e.photos.includes(blob))){URL.revokeObjectURL(url);urls.delete(blob)}
}
form.onsubmit=async event=>{
  event.preventDefault()
  const data=Object.fromEntries(new FormData(form));data.title=data.title.trim()
  if(!data.title){$('error').textContent='请填写标题。';field('title').focus();return}
  const save=form.querySelector('.save');save.disabled=true
  try{
    const id=current?.id||crypto.randomUUID()
    await access('readwrite',s=>s.put({...data,id,photos:[...photos]}))
    topic=topicOf(data);localStorage.setItem('jinse-topic',topic)
    month=data.date.slice(0,7);location.hash='timeline';day='';reset();$('editor').close();await refresh()
    const saved=document.querySelector('[data-entry-id="'+CSS.escape(id)+'"]')
    saved?.scrollIntoView({block:'nearest'});saved?.classList.add('just-saved')
  }catch{$('error').textContent='保存失败，请检查浏览器剩余空间后重试。'}
  finally{save.disabled=false}
}
$('del').onclick=async()=>{
  if(!confirm('确定删除这条记录和其中的照片？'))return
  try{await access('readwrite',s=>s.delete(current.id));$('detail').close();await refresh()}catch{alert('删除失败，请重试。')}
}
$('edit').onclick=()=>{$('detail').close();compose(current)}
$('close').onclick=()=>$('detail').close()
$('cancel').onclick=()=>$('editor').close()
$('add').onclick=()=>compose(null)
$('month').onchange=e=>{if(e.target.value){month=e.target.value;day='';render()}}
$('find').onclick=()=>{const q=$('query');q.hidden=!q.hidden;$('find').setAttribute('aria-expanded',String(!q.hidden));if(q.hidden){q.value='';render()}else q.focus()}
$('query').oninput=render
window.addEventListener('hashchange',()=>{day='';render();window.scrollTo(0,0)})
window.addEventListener('focus',()=>{if(!$('editor').open&&!$('detail').open)refresh()})
let coverURL=''
let bannerTopic=''
async function loadCover(title){
  bannerTopic=title
  $('topicName').textContent=title
  $('topicMark').src=mark(title)
  const fallback=title==='海岸散步'?'./coast.jpg':'./coffee.jpg'
  $('coverImage').src=fallback
  const req=db.transaction('covers').objectStore('covers').get(title)
  req.onsuccess=()=>{
    if(bannerTopic!==title)return
    if(coverURL)URL.revokeObjectURL(coverURL)
    coverURL=req.result?URL.createObjectURL(req.result):''
    $('coverImage').src=coverURL||fallback
  }
}
$('pickCover').onchange=async event=>{
  const file=event.target.files[0],name=topic
  if(!file)return
  try{
    const url=URL.createObjectURL(file),image=new Image()
    try{image.src=url;await image.decode()}finally{URL.revokeObjectURL(url)}
    const tx=db.transaction('covers','readwrite')
    tx.objectStore('covers').put(file,name)
    tx.oncomplete=()=>{if(name===topic)loadCover(name)}
    tx.onabort=()=>alert('封面保存失败，请检查存储空间。')
  }catch{alert('无法读取图片，请重新选择。')}
  event.target.value=''
}
function renderDirectory(){
  const term=$('directoryQuery').value.trim().toLocaleLowerCase()
  const rows=[]
  for(const title of [...new Set([...entries.map(topicOf),'生活手记'])].sort()){
    const titleMatches=term && title.includes(term)
    const records=entries.filter(e=>topicOf(e)===title &&
      (!term||titleMatches||[e.title,e.body,e.place].some(value=>value.toLocaleLowerCase().includes(term))))
    if(term && !titleMatches && !records.length) continue
    const row=button('',()=>{
      reset()
      topic=title;localStorage.setItem('jinse-topic',topic)
      if(records.length && !records.some(e=>e.date.startsWith(month+'-'))) month=records[0].date.slice(0,7)
      const query=$('query')
      query.value=titleMatches?'':term
      query.hidden=!query.value
      $('find').setAttribute('aria-expanded',String(!query.hidden))
      location.hash='timeline'
      render()
    },'collection')
    const icon=node('img',undefined,'collection-icon');icon.alt='';icon.src=mark(title)
    icon.setAttribute('aria-hidden','true')
    const copy=node('span',undefined,'collection-copy')
    let count=records.length+' 个节点'
    if(records.length){
      const days=Math.round((Date.parse(records[0].date)-Date.parse(records.at(-1).date))/86400000)+1
      count+=' · 跨度 '+days+' 天'
    }
    copy.append(node('strong',title),node('small',count))
    row.append(icon,copy,node('span','进入','collection-action'))
    rows.push(row)
  }
  $('collections').replaceChildren(...(rows.length?rows:[node('p','没有匹配的时间线','directory-empty')]))
}
$('directoryQuery').oninput=renderDirectory
$('appearance').onclick=()=>$('appearanceDialog').showModal()
$('closeAppearance').onclick=()=>$('appearanceDialog').close()
function applyAppearance(mode){
  document.documentElement.dataset.appearance=mode
  for(const option of document.querySelectorAll('input[name=appearance]'))option.checked=option.value===mode
}
let theme='system'
try{theme=localStorage.getItem('jinse-appearance')||theme}catch{}
applyAppearance(theme)
for(const option of document.querySelectorAll('input[name=appearance]'))option.onchange=()=>{
  applyAppearance(option.value)
  try{localStorage.setItem('jinse-appearance',option.value)}catch{}
}
const Recognition=window.SpeechRecognition||window.webkitSpeechRecognition
if(Recognition){
  const mic=$('voice'),recognizer=new Recognition()
  let listening=false
  recognizer.lang='zh-CN'
  mic.hidden=false
  recognizer.onstart=()=>{listening=true;mic.setAttribute('aria-pressed','true');$('voiceFeedback').textContent='正在听写…'}
  recognizer.onend=()=>{listening=false;mic.setAttribute('aria-pressed','false');if($('voiceFeedback').textContent==='正在听写…')$('voiceFeedback').textContent=''}
  recognizer.onresult=event=>{$('directoryQuery').value=event.results[0][0].transcript;renderDirectory()}
  recognizer.onerror=()=>{$('voiceFeedback').textContent='听写未完成，请检查麦克风权限或使用键盘。'}
  mic.onclick=()=>{try{if(listening)recognizer.stop();else recognizer.start()}catch{$('voiceFeedback').textContent='请稍后重试。'}}
  window.addEventListener('hashchange',()=>{if(listening)recognizer.abort()})
}
await refresh()
if('serviceWorker' in navigator)navigator.serviceWorker.register('./sw.js').catch(()=>{})
