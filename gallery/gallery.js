'use strict';
(() => {
const $ = id => document.getElementById(id);
const catalog = window.GALLERY_CATALOG;
if (!catalog?.items?.length) {
  $('count').textContent = 'Каталог пока не собран. Запусти gallery/serve.py, чтобы добавить изображения проекта.';
  return;
}
const items = catalog.items;
const groups = [['all','Все'],['references','Референсы'],['ios','iOS'],['web','Веб-экраны'],['brand','Брендинг'],['other','Материалы']];
const groupName = Object.fromEntries(groups);
const order = new Map(groups.map(([key], index) => [key,index]));
const collator = new Intl.Collator('ru',{numeric:true,sensitivity:'base'});
const date = new Intl.DateTimeFormat('ru',{day:'numeric',month:'long',year:'numeric'});
let selectedGroup='all', filtered=[], visible=48, current=0, trigger=null, searchTimer;
const text = (tag, content, className='') => { const node=document.createElement(tag); node.textContent=content; if(className)node.className=className; return node; };
const fileSize = size => size<1024 ? size+' Б' : size<1048576 ? (size/1024).toFixed(0)+' КБ' : (size/1048576).toFixed(1)+' МБ';
const dimension = item => item.width&&item.height ? `${item.width} × ${item.height}` : 'Вектор';
for (const [key,name] of groups) {
  const count=key==='all'?items.length:items.filter(i=>i.category===key).length;
  if (!count) continue;
  const button=text('button',name); button.type='button'; button.dataset.group=key; button.setAttribute('aria-pressed',String(key===selectedGroup));
  button.append(text('span',count,'group-count'));
  button.addEventListener('click',()=>{selectedGroup=key;apply();}); $('groups').append(button);
}
for (const format of [...new Set(items.map(i=>i.format))].sort()) { const option=text('option',format); option.value=format; $('format').append(option); }
function apply() {
  visible=48;
  const query=$('search').value.trim().toLocaleLowerCase('ru');
  filtered=items.filter(item=>(selectedGroup==='all'||item.category===selectedGroup)&&($('format').value==='all'||item.format===$('format').value)&&(!query||[item.name,groupName[item.category],...item.tags,...item.sources.map(s=>s.path+' '+s.project)].join(' ').toLocaleLowerCase('ru').includes(query)));
  const kind=$('sort').value;
  filtered.sort((a,b)=>{
    const byName=()=>collator.compare(a.name,b.name)||a.id.localeCompare(b.id);
    if(kind==='name')return byName();
    if(kind==='newest')return b.modified-a.modified||byName();
    if(kind==='oldest')return a.modified-b.modified||byName();
    if(kind==='pixels')return b.width*b.height-a.width*a.height||byName();
    if(kind==='size')return b.bytes-a.bytes||byName();
    return order.get(a.category)-order.get(b.category)||byName();
  });
  for(const button of $('groups').children)button.setAttribute('aria-pressed',String(button.dataset.group===selectedGroup));
  render();
}
function render() {
  $('grid').replaceChildren();
  for (const [index,item] of filtered.slice(0,visible).entries()) {
    const article=document.createElement('article'); article.className='tile '+item.category; article.dataset.imageId=item.id;
    const button=document.createElement('button'); button.type='button'; button.className='tile-button'; button.setAttribute('aria-label','Просмотреть '+item.name);
    const frame=document.createElement('div'); frame.className='tile-picture';
    const img=document.createElement('img'); img.src=item.thumbnail; img.alt=''; img.loading='lazy'; img.decoding='async';
    img.addEventListener('error',()=>frame.replaceChildren(text('span','Миниатюра недоступна','load-failure')),{once:true}); frame.append(img);
    const caption=document.createElement('div'); caption.className='tile-caption'; caption.append(text('h2',item.name,'tile-title'));
    const meta=document.createElement('div'); meta.className='tile-meta'; meta.append(text('span',groupName[item.category]),text('span',item.format+'  '+dimension(item))); caption.append(meta);
    button.append(frame,caption); button.addEventListener('click',()=>open(index,button)); article.append(button); $('grid').append(article);
  }
  $('count').textContent=`${filtered.length} из ${items.length} изображений`;
  $('sources').textContent=`${catalog.sourceCount} исходных файлов · точные копии объединены`;
  $('empty').hidden=filtered.length>0; $('more').hidden=visible>=filtered.length;
  $('more').textContent=`Показать ещё ${Math.min(48,filtered.length-visible)}`;
}
function open(index,button) {
  current=index; trigger=button; showCurrent(); $('viewer').showModal(); document.body.style.overflow='hidden';
}
function showCurrent() {
  const item=filtered[current]; if(!item)return;
  $('viewer-title').textContent=item.name; $('position').textContent=`${current+1} из ${filtered.length}`;
  $('viewer-category').textContent=groupName[item.category];
  $('viewer-meta').textContent=`${item.format}, ${dimension(item)}, ${fileSize(item.bytes)}. Дата файла: ${date.format(new Date(item.modified*1000))}.`;
  $('viewer-size').textContent=dimension(item); $('download').href=item.url; $('download').download=item.name;
  $('previous').disabled=current===0; $('next').disabled=current===filtered.length-1;
  $('stage').classList.remove('zoomed'); $('zoom').setAttribute('aria-pressed','false'); $('zoom').textContent='Масштаб 1:1';
  $('full-image').hidden=false; $('image-error').hidden=true; $('full-image').alt=item.name; $('full-image').src=item.url;
  $('stage').scrollTop=0; $('stage').scrollLeft=0;
  $('locations').replaceChildren(...item.sources.map(source=>{ const li=document.createElement('li'); li.append(text('b',source.project),document.createTextNode(source.path)); return li; }));
}
$('full-image').addEventListener('error',()=>{$('full-image').hidden=true;$('image-error').hidden=false;});
$('close').addEventListener('click',()=>$('viewer').close());
$('viewer').addEventListener('close',()=>{document.body.style.overflow='';trigger?.focus();});
$('previous').addEventListener('click',()=>{if(current>0){current--;showCurrent();}});
$('next').addEventListener('click',()=>{if(current<filtered.length-1){current++;showCurrent();}});
$('zoom').addEventListener('click',()=>{const zoomed=$('stage').classList.toggle('zoomed');$('zoom').setAttribute('aria-pressed',String(zoomed));$('zoom').textContent=zoomed?'Вписать изображение':'Масштаб 1:1';});
$('background').addEventListener('click',()=>{const light=$('stage').classList.toggle('light');$('background').setAttribute('aria-pressed',String(light));$('background').textContent=light?'Тёмный фон':'Светлый фон';});
document.addEventListener('keydown',event=>{if(!$('viewer').open||$('stage').classList.contains('zoomed'))return;if(event.key==='ArrowRight'&&current<filtered.length-1){event.preventDefault();current++;showCurrent();}if(event.key==='ArrowLeft'&&current>0){event.preventDefault();current--;showCurrent();}});
$('search').addEventListener('input',()=>{clearTimeout(searchTimer);searchTimer=setTimeout(apply,120);});
$('format').addEventListener('change',apply); $('sort').addEventListener('change',apply);
$('reset').addEventListener('click',()=>{$('search').value='';$('format').value='all';selectedGroup='all';apply();$('search').focus();});
$('more').addEventListener('click',()=>{const previous=visible;visible+=48;render();$('grid').children[previous]?.querySelector('button')?.focus();});
apply();
})();
