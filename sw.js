const cacheName='jinse-shell-v2'
self.addEventListener('install',event=>{
  event.waitUntil(caches.open(cacheName).then(cache=>cache.addAll(['./','./index.html','./app.js','./style.css','./coffee.jpg','./coast.jpg'])))
})
self.addEventListener('activate',event=>{
  event.waitUntil(caches.delete('jinse-shell-v1'))
})
self.addEventListener('fetch',event=>{
  if(event.request.method!=='GET'||!event.request.url.startsWith(self.registration.scope))return
  event.respondWith(fetch(event.request).catch(async()=>{
    const cache=await caches.open(cacheName)
    return await cache.match(event.request)||Response.error()
  }))
})
