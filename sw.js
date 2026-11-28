const cacheName='jinse-shell-v8'
self.addEventListener('install',event=>{
  event.waitUntil(caches.open(cacheName).then(cache=>cache.addAll(['./','./index.html','./app.js','./style.css','./coffee.jpg','./coast.jpg','./mark-build.png','./mark-life.png','./mark-coast.png'])))
})
self.addEventListener('activate',event=>{
  event.waitUntil(Promise.all(['jinse-shell-v1','jinse-shell-v2','jinse-shell-v3','jinse-shell-v4','jinse-shell-v5','jinse-shell-v6','jinse-shell-v7'].map(key=>caches.delete(key))))
})
self.addEventListener('fetch',event=>{
  if(event.request.method!=='GET'||!event.request.url.startsWith(self.registration.scope))return
  event.respondWith(fetch(event.request).catch(async()=>{
    const cache=await caches.open(cacheName)
    return await cache.match(event.request)||Response.error()
  }))
})
