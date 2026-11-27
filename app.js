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
  const req=indexedDB.open('jinse-journal-v1',1)
  req.onupgradeneeded=()=>{
    const s=req.result.createObjectStore('entries',{keyPath:'id'})
    seed.forEach(e=>s.add(e))
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
  $('month').value=month
  try{localStorage.setItem('jinse-month',month)}catch{}
  const monthly=entries.filter(e=>e.date.startsWith(month+'-'))
  const [year,number]=month.split('-')
  $('monthName').textContent=year+' 年 '+Number(number)+' 月'
  $('total').textContent=monthly.length+' 篇'
  const months=[...new Set([month,...entries.map(e=>e.date.slice(0,7))])].sort().reverse()
  $('archives').replaceChildren(...months.map(key=>{
    const [y,m]=key.split('-')
    const link=button(y+' 年 '+Number(m)+' 月',()=>{month=key;day='';render()},month===key?'active':'')
    link.append(node('span',String(entries.filter(e=>e.date.startsWith(key)).length)))
    return link
  }))
  $('heading').textContent=calendar?'手记日历':'我的时间线'
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
  const filtered=monthly.filter(e=>(tag==='全部'||e.tag===tag)&&(!day||e.date===day)&&[e.title,e.body,e.place].some(s=>s.toLocaleLowerCase().includes(q)))
  const rows=$('rows');rows.replaceChildren()
  let previous=''
  for(const e of filtered){
    const b=button('',()=>show(e),'record')
    b.dataset.entryId=e.id
    const info=node('div',undefined,'entry')
    info.append(node('h2',e.title),node('div',[e.place,e.tag].filter(Boolean).join(' · '),'meta'))
    if(e.photos.length)info.append(picture(e.photos[0]));else info.append(node('div',e.body,'snippet'))
    const stamp=node('span',previous===e.date?'':e.date.slice(-2),'day')
    if(previous!==e.date)stamp.append(node('small',new Date(e.date+'T12:00:00').toLocaleDateString('zh-CN',{weekday:'long'})))
    b.append(stamp,info);rows.append(b);previous=e.date
  }
  if(!filtered.length){
    const box=node('div',undefined,'empty')
    box.append(node('p',monthly.length?'没有匹配的记录':'这个月还没有记录'),monthly.length?button('清除条件',()=>{reset();render()}):button('添加记录',()=>compose(null)))
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
  for(const n of ['title','body','date','place','tag'])field(n).value=e?.[n]??({date:day||today(),tag:'日常'}[n]||'')
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
    month=data.date.slice(0,7);calendar=false;reset();$('editor').close();await refresh()
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
$('timeline').onclick=()=>{calendar=false;day='';render()}
$('calendar').onclick=()=>{calendar=true;render()}
window.addEventListener('focus',()=>{if(!$('editor').open&&!$('detail').open)refresh()})
await refresh()
if('serviceWorker' in navigator)navigator.serviceWorker.register('./sw.js').catch(()=>{})
