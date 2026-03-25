// Serializes arbitrary JS values into bounded JSON strings.
// Handles DOM nodes, NodeList, Map, Set, circular refs, and depth/breadth limits.
// Extracted into its own module so it can be tested independently.

// Recursive serializer that walks the value graph with cycle detection (WeakSet),
// depth cap (5), and breadth cap (50 keys/items per level). DOM elements are
// reduced to {__type, tag, id, className, textContent}. Returns a JSON string
// truncated to maxBytes.
let serialize: ('a, int) => string = %raw(`
  function smartSerialize(value, maxBytes) {
    var seen = typeof WeakSet !== 'undefined' ? new WeakSet() : { add: function(){}, has: function(){ return false } };
    var maxDepth = 5;
    var maxBreadth = 50;

    function isElement(val) {
      return val.nodeType === 1 && typeof val.tagName === 'string';
    }

    function isNodeList(val) {
      return typeof val.item === 'function' && typeof val.length === 'number' && !Array.isArray(val);
    }

    function isMap(val) {
      return typeof val.get === 'function' && typeof val.set === 'function'
        && typeof val.entries === 'function' && typeof val.size === 'number';
    }

    function isSet(val) {
      return typeof val.add === 'function' && typeof val.has === 'function'
        && typeof val.size === 'number' && typeof val.get !== 'function';
    }

    function serialize(val, depth) {
      if (val === undefined) return undefined;
      if (val === null) return null;
      if (typeof val === 'function') return '[Function: ' + (val.name || 'anonymous') + ']';
      if (typeof val === 'bigint') return val.toString() + 'n';
      if (typeof val !== 'object') return val;

      if (depth > maxDepth) return '[Object]';
      if (seen.has(val)) return '[Circular]';
      seen.add(val);

      if (isElement(val)) {
        return {
          __type: 'Element',
          tag: val.tagName,
          id: val.id || undefined,
          className: val.className || undefined,
          textContent: (val.textContent || '').slice(0, 80) || undefined
        };
      }

      if (isNodeList(val)) {
        var items = [];
        var nlLen = Math.min(val.length, maxBreadth);
        for (var i = 0; i < nlLen; i++) items.push(serialize(val[i], depth + 1));
        if (val.length > maxBreadth) items.push('...' + (val.length - maxBreadth) + ' more');
        return items;
      }

      if (isMap(val)) {
        var entries = [];
        var mapCount = 0;
        val.forEach(function(v, k) {
          if (mapCount < maxBreadth) entries.push([serialize(k, depth + 1), serialize(v, depth + 1)]);
          mapCount++;
        });
        var mapResult = { __type: 'Map', entries: entries };
        if (mapCount > maxBreadth) mapResult.truncated = mapCount - maxBreadth;
        return mapResult;
      }

      if (isSet(val)) {
        var values = [];
        var setCount = 0;
        val.forEach(function(v) {
          if (setCount < maxBreadth) values.push(serialize(v, depth + 1));
          setCount++;
        });
        var setResult = { __type: 'Set', values: values };
        if (setCount > maxBreadth) setResult.truncated = setCount - maxBreadth;
        return setResult;
      }

      if (Array.isArray(val)) {
        var arr = [];
        var arrLen = Math.min(val.length, maxBreadth);
        for (var j = 0; j < arrLen; j++) arr.push(serialize(val[j], depth + 1));
        if (val.length > maxBreadth) arr.push('...' + (val.length - maxBreadth) + ' more');
        return arr;
      }

      var obj = {};
      var keys = Object.keys(val);
      var keyLen = Math.min(keys.length, maxBreadth);
      for (var k = 0; k < keyLen; k++) {
        obj[keys[k]] = serialize(val[keys[k]], depth + 1);
      }
      if (keys.length > maxBreadth) obj.__truncated = keys.length - maxBreadth + ' more keys';
      return obj;
    }

    var json = JSON.stringify(serialize(value, 0));
    if (json && json.length > maxBytes) {
      return json.slice(0, maxBytes) + '...[truncated]';
    }
    return json || 'undefined';
  }
`)
