const cacheName='jinse-shell-v1'
self.addEventListener('install',event=>{
  event.waitUntil(caches.open(cacheName).then(cache=>cache.addAll(['./','./index.html','./app.js','./style.css','./cafe.png','./sea.png'])))
})
self.addEventListener('fetch',event=>{
  if(event.request.method!=='GET'||!event.request.url.startsWith(self.registration.scope))return
  event.respondWith(fetch(event.request).catch(async()=>await caches.match(event.request)||Response.error()))
})
