// Heap Analytics initialization
// Dev env ID: 349428408
// Prod env ID: 218974947

@@live
let envId = if Client__Env.isDev {
  "349428408"
} else {
  "218974947"
}

let init = () => {
  let _: unit = %raw(`
    (function(envId) {
      window.heapReadyCb=window.heapReadyCb||[];
      window.heap=window.heap||[];
      heap.load=function(e,t){
        window.heap.envId=e;
        window.heap.clientConfig=t=t||{};
        window.heap.clientConfig.shouldFetchServerConfig=false;
        var a=document.createElement("script");
        a.type="text/javascript";
        a.async=true;
        a.src="https://cdn.us.heap-api.com/config/"+e+"/heap_config.js";
        var r=document.getElementsByTagName("script")[0];
        r.parentNode.insertBefore(a,r);
        var n=["init","startTracking","stopTracking","track","resetIdentity","identify","getSessionId","getUserId","getIdentity","addUserProperties","addEventProperties","removeEventProperty","clearEventProperties","addAccountProperties","addAdapter","addTransformer","addTransformerFn","onReady","addPageviewProperties","removePageviewProperty","clearPageviewProperties","trackPageview"];
        var i=function(e){return function(){var t=Array.prototype.slice.call(arguments,0);window.heapReadyCb.push({name:e,fn:function(){heap[e]&&heap[e].apply(heap,t)}})}};
        for(var p=0;p<n.length;p++) heap[n[p]]=i(n[p]);
      };
      heap.load(envId);
    })(envId)
  `)
}

let identify: string => unit = %raw(`
  function(userId) {
    if (typeof window !== 'undefined' && window.heap && window.heap.identify) {
      window.heap.identify(userId);
    }
  }
`)

let addUserProperties: {..} => unit = %raw(`
  function(properties) {
    if (typeof window !== 'undefined' && window.heap && window.heap.addUserProperties) {
      window.heap.addUserProperties(properties);
    }
  }
`)
