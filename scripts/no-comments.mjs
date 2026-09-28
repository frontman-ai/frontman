#!/usr/bin/env node

import {execFileSync} from "node:child_process"
import {readFileSync, writeFileSync} from "node:fs"
import {basename, extname, resolve} from "node:path"
import {pathToFileURL} from "node:url"

const cLikeExtensions = new Set([
  ".c",
  ".cc",
  ".cjs",
  ".cpp",
  ".cs",
  ".cts",
  ".h",
  ".hpp",
  ".java",
  ".js",
  ".jsx",
  ".mjs",
  ".mts",
  ".res",
  ".resi",
  ".swift",
  ".ts",
  ".tsx",
])
const hashExtensions = new Set([".env", ".ini", ".service", ".sh", ".toml", ".yaml", ".yml"])
const htmlExtensions = new Set([".astro", ".heex", ".html", ".htm", ".svelte", ".svg", ".vue", ".xml"])
const ignoredBasenames = new Set(["LICENSE", "LICENCE"])
const ignoredExtensions = new Set([
  ".avif",
  ".gif",
  ".ico",
  ".jpeg",
  ".jpg",
  ".json",
  ".lock",
  ".md",
  ".mdx",
  ".mp4",
  ".pdf",
  ".png",
  ".po",
  ".pot",
  ".ttf",
  ".vtt",
  ".webmanifest",
  ".webp",
  ".woff",
  ".woff2",
])
const hashBasenames = new Set([
  ".dockerignore",
  ".env",
  ".gitattributes",
  ".gitignore",
  ".zshrc",
  "CODEOWNERS",
  "Caddyfile",
  "Dockerfile",
  "Makefile",
  "_headers",
  "_redirects",
])
const cLikeBasenames = new Set([".prettierrc"])
const generatedTemplateBindings = new Map([
  ["libs/frontman-nextjs/src/cli/FrontmanNextjs__Cli__Templates.res", ["middlewareTemplate", "proxyTemplate", "instrumentationTemplate"]],
  ["libs/frontman-vite/src/cli/FrontmanVite__Cli__Templates.res", ["importLine", "pluginCall"]],
])
const vendoredPaths = ["apps/frontman_server/assets/vendor/", "libs/experimental-rescript-webapi/"]

function span(start, end, kind) {
  return {start, end, kind}
}

function consumeQuoted(source, start, quote) {
  let i = start + quote.length
  while (i < source.length) {
    if (source.startsWith("\\", i)) {
      i += 2
    } else if (source.startsWith(quote, i)) {
      return i + quote.length
    } else {
      i++
    }
  }
  return source.length
}

function consumeRegex(source, start) {
  let i = start + 1
  let inClass = false
  while (i < source.length) {
    const char = source[i]
    if (char === "\\") {
      i += 2
    } else if (char === "[") {
      inClass = true
      i++
    } else if (char === "]") {
      inClass = false
      i++
    } else if (char === "/" && !inClass) {
      i++
      while (/[a-z]/i.test(source[i] ?? "")) i++
      return i
    } else if (char === "\n" || char === "\r") {
      return start + 1
    } else {
      i++
    }
  }
  return start + 1
}

function regexCanStart(source, index) {
  const before = source.slice(0, index).match(/(?:^|\s)(return|throw|case|delete|typeof|void|yield|await|new|in|of)\s*$/)
  if (before) return true
  let i = index - 1
  while (i >= 0 && /\s/.test(source[i])) i--
  return i < 0 || /[({[,:;=!?&|+\-*%^~<>]/.test(source[i])
}

function consumeRescriptQuoted(source, start) {
  const match = source.slice(start).match(/^\{([a-zA-Z0-9_]*)\|/)
  if (!match) return start
  const close = `|${match[1]}}`
  const end = source.indexOf(close, start + match[0].length)
  return end < 0 ? source.length : end + close.length
}

function consumeTemplateLiteral(source, start, options, results) {
  let i = start + 1
  while (i < source.length) {
    if (source[i] === "\\") {
      i += 2
    } else if (source[i] === "`") {
      return i + 1
    } else if (source.startsWith("${", i)) {
      const expression = scanCLikeInternal(source, options, i + 2, 1)
      results.push(...expression.results)
      i = expression.end
    } else {
      i++
    }
  }
  return source.length
}

function isRescriptRawTemplate(source, index) {
  return /%raw\(\s*$/.test(source.slice(0, index))
}

function typescriptReferenceEnd(source, index) {
  const lineStart = source.lastIndexOf("\n", index - 1) + 1
  if (!/^[ \t]*$/.test(source.slice(lineStart, index))) return index
  const newline = source.indexOf("\n", index)
  const end = newline < 0 ? source.length : newline
  const line = source.slice(index, end).replace(/\r$/, "")
  const attribute = "(?:path|types|lib|no-default-lib|resolution-mode|preserve)=(?:\"[^\"\\r\\n]+\"|'[^'\\r\\n]+')"
  return new RegExp(`^/// <reference (?:${attribute}[ \\t]*)+/>[ \\t]*$`).test(line) ? end : index
}

function documentationLineEnd(source, index) {
  const lineStart = source.lastIndexOf("\n", index - 1) + 1
  if (!/^[ \t]*$/.test(source.slice(lineStart, index))) return index
  const end = source.indexOf("\n", index)
  return end < 0 ? source.length : end
}

function scanCLikeInternal(source, options, start = 0, braceDepth = 0) {
  const results = []
  const nested = options.nested === true
  const lineComments = options.lineComments !== false
  const regex = options.regex === true
  const rescript = options.rescript === true
  const hash = options.hash === true
  const typescriptDirectives = options.typescriptDirectives === true
  let i = start
  while (i < source.length) {
    const char = source[i]
    if (rescript && char === "'" && /[a-zA-Z_]/.test(source[i + 1] ?? "") && source[i + 2] !== "'") {
      i++
    } else if (char === '"' || char === "'") {
      i = consumeQuoted(source, i, char)
    } else if (rescript && char === "`" && isRescriptRawTemplate(source, i)) {
      const end = consumeTemplateLiteral(source, i, options, [])
      const bodyEnd = end > i + 1 ? end - 1 : end
      results.push(...offsetSpans(scanCLike(source.slice(i + 1, bodyEnd), {regex: true}), i + 1))
      i = end
    } else if (char === "`") {
      i = consumeTemplateLiteral(source, i, options, results)
    } else if (rescript && char === "{" && consumeRescriptQuoted(source, i) !== i) {
      i = consumeRescriptQuoted(source, i)
    } else if (source.startsWith("/**", i)) {
      const end = source.indexOf("*/", i + 3)
      i = end < 0 ? source.length : end + 2
    } else if (source.startsWith("/*", i)) {
      const start = i
      i += 2
      let depth = 1
      while (i < source.length && depth > 0) {
        if (nested && source.startsWith("/*", i)) {
          depth++
          i += 2
        } else if (source.startsWith("*/", i)) {
          depth--
          i += 2
        } else {
          i++
        }
      }
      results.push(span(start, i, "block"))
    } else if (lineComments && source.startsWith("///", i)) {
      const end = documentationLineEnd(source, i)
      if (end === i) {
        const lineEnd = source.indexOf("\n", i)
        results.push(span(i, lineEnd < 0 ? source.length : lineEnd, "line"))
        i = lineEnd < 0 ? source.length : lineEnd
      } else {
        i = end
      }
    } else if (lineComments && source.startsWith("//", i)) {
      const directiveEnd = typescriptDirectives ? typescriptReferenceEnd(source, i) : i
      if (directiveEnd !== i) {
        i = directiveEnd
      } else {
        const end = source.indexOf("\n", i)
        results.push(span(i, end < 0 ? source.length : end, "line"))
        i = end < 0 ? source.length : end
      }
    } else if (hash && char === "#" && source[i + 1] !== "[") {
      const end = source.indexOf("\n", i)
      results.push(span(i, end < 0 ? source.length : end, "line"))
      i = end < 0 ? source.length : end
    } else if (regex && char === "/" && regexCanStart(source, i)) {
      i = consumeRegex(source, i)
    } else if (braceDepth > 0 && char === "{") {
      braceDepth++
      i++
    } else if (braceDepth > 0 && char === "}") {
      braceDepth--
      i++
      if (braceDepth === 0) return {results, end: i}
    } else {
      i++
    }
  }
  return {results, end: i}
}

function scanCLike(source, options = {}) {
  return scanCLikeInternal(source, options).results
}

function indentation(line) {
  return line.match(/^[ \t]*/)[0].replaceAll("\t", "        ").length
}

function hashMarker(line, allowSemicolon) {
  let quote = ""
  for (let i = 0; i < line.length; i++) {
    const char = line[i]
    if (quote) {
      if (char === "\\") i++
      else if (char === quote) quote = ""
    } else if (char === '"' || char === "'") {
      quote = char
    } else if ((char === "#" || (allowSemicolon && char === ";")) && (i === 0 || /\s/.test(line[i - 1]))) {
      return i
    }
  }
  return -1
}

function scanHash(source, options = {}) {
  const results = []
  const lines = source.match(/.*(?:\r\n|\n|\r|$)/g).filter(Boolean)
  let offset = 0
  let yamlBlock = null
  let heredoc = null
  for (let index = 0; index < lines.length; index++) {
    const raw = lines[index]
    const line = raw.replace(/[\r\n]+$/, "")
    const trimmed = line.trim()
    if (heredoc) {
      if (trimmed === heredoc.delimiter) {
        const body = source.slice(heredoc.start, offset)
        const spans = heredoc.language === "sql"
          ? scanSql(body)
          : heredoc.language === "python"
            ? scanPython(body)
            : heredoc.language === "javascript"
              ? scanCLike(body, {regex: true})
              : heredoc.language === "hash" ? scanHash(body, {shell: true}) : []
        results.push(...offsetSpans(spans, heredoc.start))
        heredoc = null
      }
      offset += raw.length
      continue
    }
    if (yamlBlock) {
      if (trimmed === "" || indentation(line) > yamlBlock.indent) {
        offset += raw.length
        continue
      }
      if (yamlBlock.shell) {
        const body = source.slice(yamlBlock.start, offset)
        results.push(...offsetSpans(scanHash(body, {shell: true}), yamlBlock.start))
      }
      yamlBlock = null
    }
    if (index === 0 && line.startsWith("#!")) {
      offset += raw.length
      continue
    }
    const dockerDirective = options.dockerfile && /^#\s*(?:syntax|escape|check)\s*=/i.test(line)
    const marker = dockerDirective ? -1 : hashMarker(line, options.semicolon === true)
    if (marker >= 0) results.push(span(offset + marker, offset + line.length, "line"))
    const code = marker >= 0 ? line.slice(0, marker) : line
    if (options.yaml && /:\s*[>|][-+0-9]*\s*$/.test(code)) {
      yamlBlock = {
        indent: indentation(line),
        shell: /^\s*(?:-\s*)?run\s*:/.test(code),
        start: offset + raw.length,
      }
    }
    if (options.shell) {
      const match = code.match(/<<-?\s*['"]?([A-Za-z_][A-Za-z0-9_]*)['"]?/)
      if (match) {
        const delimiter = match[1]
        const language = /^SQL/.test(delimiter)
          ? "sql"
          : /^PY/.test(delimiter) || /\bpython[0-9.]*\b/.test(code)
            ? "python"
            : /^(?:JS|JAVASCRIPT|NODE|TS|TYPESCRIPT)$/.test(delimiter) || /\bnode\b/.test(code) || /\.(?:[cm]?[jt]sx?)\b/.test(code)
              ? "javascript"
              : /^(?:CADDYFILE|ENV|EOF|HEADER|LOGROTATE|PGCONF|SCRIPT|SUDOERS)$/.test(delimiter) ? "hash" : "data"
        heredoc = {delimiter, language, start: offset + raw.length}
      }
    }
    offset += raw.length
  }
  if (yamlBlock?.shell) {
    const body = source.slice(yamlBlock.start, offset)
    results.push(...offsetSpans(scanHash(body, {shell: true}), yamlBlock.start))
  }
  return results
}

function scanPython(source) {
  const results = []
  let i = 0
  while (i < source.length) {
    const triple = source.slice(i).match(/^[rRuU]?("""|''')/)
    if (triple) {
      const quote = triple[1]
      const quoteStart = i + triple[0].length - quote.length
      const end = consumeQuoted(source, quoteStart, quote)
      i = end
    } else if (source[i] === '"' || source[i] === "'") {
      i = consumeQuoted(source, i, source[i])
    } else if (source[i] === "#") {
      if (i === 0 && source.startsWith("#!")) {
        const end = source.indexOf("\n", i)
        i = end < 0 ? source.length : end
      } else {
        const end = source.indexOf("\n", i)
        results.push(span(i, end < 0 ? source.length : end, "line"))
        i = end < 0 ? source.length : end
      }
    } else {
      i++
    }
  }
  return results
}

function elixirSigil(source, start) {
  const match = source.slice(start).match(/^~([a-zA-Z])("""|'''|[\/|({[<"])/)
  if (!match) return null
  const opener = match[2]
  const closers = {"(": ")", "[": "]", "{": "}", "<": ">"}
  const closer = closers[opener] ?? opener
  const openerStart = start + match[0].length - opener.length
  return {name: match[1], opener, closer, openerStart, bodyStart: openerStart + opener.length}
}

function consumeElixirQuoted(source, start, opener, closer, interpolate, results, paired = false) {
  let depth = 1
  let i = start + opener.length
  while (i < source.length) {
    if (source[i] === "\\") {
      i += 2
    } else if (interpolate && source.startsWith("#{", i)) {
      const expression = scanElixirInternal(source, i + 2, 1)
      results.push(...expression.results)
      i = expression.end
    } else if (paired && source.startsWith(opener, i)) {
      depth++
      i += opener.length
    } else if (source.startsWith(closer, i)) {
      depth--
      i += closer.length
      if (depth === 0) return i
    } else {
      i++
    }
  }
  return source.length
}

function consumeElixirSigil(source, sigil, results) {
  const paired = sigil.opener !== sigil.closer
  const interpolate = sigil.name === sigil.name.toLowerCase()
  const end = consumeElixirQuoted(source, sigil.openerStart, sigil.opener, sigil.closer, interpolate, results, paired)
  return {...sigil, bodyEnd: end - sigil.closer.length, end}
}

function elixirDocAttribute(source, start) {
  const match = source.slice(start).match(/^@(moduledoc|typedoc|doc)\b[ \t]+/)
  if (!match) return null
  const valueStart = start + match[0].length
  if (/^false\b/.test(source.slice(valueStart))) return {end: valueStart + 5}
  let end
  if (source.startsWith('"""', valueStart) || source.startsWith("'''", valueStart)) {
    const quote = source.slice(valueStart, valueStart + 3)
    end = consumeElixirQuoted(source, valueStart, quote, quote, true, [])
  } else if (source[valueStart] === '"' || source[valueStart] === "'") {
    end = consumeElixirQuoted(source, valueStart, source[valueStart], source[valueStart], true, [])
  } else if (source[valueStart] === "~") {
    const parsed = elixirSigil(source, valueStart)
    end = parsed ? consumeElixirSigil(source, parsed, []).end : valueStart
  }
  if (!end || end === valueStart) {
    const newline = source.indexOf("\n", valueStart)
    end = newline < 0 ? source.length : newline
  }
  return {end}
}

function scanElixirInternal(source, start = 0, braceDepth = 0) {
  const results = []
  let i = start
  while (i < source.length) {
    const doc = source[i] === "@" ? elixirDocAttribute(source, i) : null
    if (doc) {
      i = doc.end
    } else if (source.startsWith('"""', i) || source.startsWith("'''", i)) {
      const quote = source.slice(i, i + 3)
      i = consumeElixirQuoted(source, i, quote, quote, true, results)
    } else if (source[i] === '"' || source[i] === "'" || source[i] === "`") {
      i = consumeElixirQuoted(source, i, source[i], source[i], true, results)
    } else if (source[i] === "~") {
      const parsed = elixirSigil(source, i)
      if (!parsed) {
        i++
        continue
      }
      const sigil = consumeElixirSigil(source, parsed, results)
      if (sigil.name === "H" || sigil.name === "F") {
        results.push(...offsetSpans(scanHeexSigil(source.slice(sigil.bodyStart, sigil.bodyEnd)), sigil.bodyStart))
      }
      i = sigil.end
    } else if (source[i] === "#") {
      const end = source.indexOf("\n", i)
      results.push(span(i, end < 0 ? source.length : end, "line"))
      i = end < 0 ? source.length : end
    } else if (braceDepth > 0 && source[i] === "{") {
      braceDepth++
      i++
    } else if (braceDepth > 0 && source[i] === "}") {
      braceDepth--
      i++
      if (braceDepth === 0) return {results, end: i}
    } else {
      i++
    }
  }
  return {results, end: i}
}

function scanHeexExpressions(source) {
  const results = []
  const occupied = []
  const eex = /<%(?!!--|#)=?([\s\S]*?)%>/g
  for (const match of source.matchAll(eex)) {
    const bodyOffset = match.index + match[0].indexOf(match[1])
    occupied.push({start: match.index, end: match.index + match[0].length})
    results.push(...offsetSpans(scanElixir(match[1]), bodyOffset))
  }
  let i = 0
  let inTag = false
  let quote = ""
  while (i < source.length) {
    const region = occupied.find(item => i >= item.start && i < item.end)
    if (region) {
      i = region.end
    } else if (quote) {
      if (source[i] === quote) quote = ""
      i++
    } else if (inTag && (source[i] === '"' || source[i] === "'")) {
      quote = source[i]
      i++
    } else if (source[i] === "<") {
      inTag = true
      i++
    } else if (source[i] === ">") {
      inTag = false
      i++
    } else if (source[i] === "{") {
      const expression = scanElixirInternal(source, i + 1, 1)
      results.push(...expression.results)
      i = expression.end
    } else {
      i++
    }
  }
  return results
}

function scanHeexSigil(source) {
  return [...scanTemplate(source, ".heex"), ...scanHeexExpressions(source)].sort((a, b) => a.start - b.start)
}

function scanElixir(source) {
  return scanElixirInternal(source).results
}

function scanSql(source) {
  const results = []
  let i = 0
  while (i < source.length) {
    if (source[i] === "'" || source[i] === '"') {
      i = consumeQuoted(source, i, source[i])
    } else if (source[i] === "$" && source.slice(i).match(/^\$[A-Za-z0-9_]*\$/)) {
      const tag = source.slice(i).match(/^\$[A-Za-z0-9_]*\$/)[0]
      const end = source.indexOf(tag, i + tag.length)
      i = end < 0 ? source.length : end + tag.length
    } else if (source.startsWith("--", i)) {
      const end = source.indexOf("\n", i)
      results.push(span(i, end < 0 ? source.length : end, "line"))
      i = end < 0 ? source.length : end
    } else if (source.startsWith("/*", i)) {
      const end = source.indexOf("*/", i + 2)
      const finish = end < 0 ? source.length : end + 2
      results.push(span(i, finish, "block"))
      i = finish
    } else {
      i++
    }
  }
  return results
}

function scanBatch(source) {
  const results = []
  const lines = source.match(/.*(?:\r\n|\n|\r|$)/g).filter(Boolean)
  let offset = 0
  for (const raw of lines) {
    const line = raw.replace(/[\r\n]+$/, "")
    const match = line.match(/^\s*@?(?:rem\b|::)/i)
    if (match) results.push(span(offset + match[0].search(/\S/), offset + line.length, "line"))
    offset += raw.length
  }
  return results
}

function scanHtmlMarkers(source, ignoredRanges = []) {
  const results = []
  const patterns = [["<!--", "-->"], ["<%!--", "--%>"], ["<%#", "%>"]]
  let i = 0
  let inTag = false
  let quote = ""
  while (i < source.length) {
    const ignored = ignoredRanges.find(range => i >= range.start && i < range.end)
    if (ignored) {
      i = ignored.end
      continue
    }
    if (source.startsWith("<![CDATA[", i)) {
      const end = source.indexOf("]]>", i + 9)
      i = end < 0 ? source.length : end + 3
      continue
    }
    if (quote) {
      if (source[i] === quote) quote = ""
      i++
      continue
    }
    const pattern = patterns.find(([open]) => source.startsWith(open, i))
    if (pattern) {
      const end = source.indexOf(pattern[1], i + pattern[0].length)
      const finish = end < 0 ? source.length : end + pattern[1].length
      results.push(span(i, finish, "block"))
      i = finish
      continue
    }
    if (inTag && (source[i] === '"' || source[i] === "'")) quote = source[i]
    else if (source[i] === "<") inTag = true
    else if (source[i] === ">") inTag = false
    i++
  }
  return results
}

function offsetSpans(spans, offset) {
  return spans.map(item => span(item.start + offset, item.end + offset, item.kind))
}

function scriptIsExecutable(attributes) {
  const match = attributes.match(/\btype\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))/i)
  if (!match) return true
  const type = (match[1] ?? match[2] ?? match[3]).trim().toLowerCase()
  return ["module", "text/javascript", "application/javascript", "text/ecmascript", "application/ecmascript"].includes(type)
}

function scanTemplate(source, extension) {
  const results = []
  const ignoredRanges = []
  if (extension === ".astro" && source.startsWith("---")) {
    const start = source.indexOf("\n") + 1
    const end = source.indexOf("\n---", start)
    if (end >= 0) {
      results.push(...offsetSpans(scanCLike(source.slice(start, end), {regex: true}), start))
      ignoredRanges.push({start: 0, end: end + 4})
    }
  }
  const opening = /<(script|style)\b([^>]*)>/gi
  let match
  while ((match = opening.exec(source))) {
    if (match[2].trimEnd().endsWith("/")) continue
    const closing = new RegExp(`<\\/${match[1]}\\s*>`, "gi")
    closing.lastIndex = opening.lastIndex
    const close = closing.exec(source)
    if (!close) continue
    const bodyOffset = opening.lastIndex
    const body = source.slice(bodyOffset, close.index)
    ignoredRanges.push({start: bodyOffset, end: close.index})
    const tag = match[1].toLowerCase()
    const spans = tag === "style"
      ? scanCLike(body, {lineComments: false})
      : scriptIsExecutable(match[2]) ? scanCLike(body, {regex: true}) : []
    results.push(...offsetSpans(spans, bodyOffset))
    opening.lastIndex = closing.lastIndex
  }
  if (extension === ".astro") {
    let start = source.indexOf("{/*")
    while (start >= 0) {
      const ignored = ignoredRanges.some(range => start >= range.start && start < range.end)
      const close = source.indexOf("*/}", start + 3)
      if (!ignored && close >= 0) results.push(span(start, close + 3, "block"))
      start = source.indexOf("{/*", start + 3)
    }
  }
  results.push(...scanHtmlMarkers(source, ignoredRanges))
  return results.sort((a, b) => a.start - b.start)
}

function scanPhp(source) {
  const results = []
  const ignoredRanges = []
  const region = /<\?(?:php|=)?([\s\S]*?)(?:\?>|$)/gi
  for (const match of source.matchAll(region)) {
    const bodyOffset = match.index + match[0].indexOf(match[1])
    ignoredRanges.push({start: match.index, end: match.index + match[0].length})
    results.push(...offsetSpans(scanCLike(maskPhpHeredocs(match[1]), {hash: true}), bodyOffset))
  }
  results.push(...scanHtmlMarkers(source, ignoredRanges))
  return results.sort((a, b) => a.start - b.start)
}

function maskPhpHeredocs(source) {
  const characters = source.split("")
  const opening = /<<<[ \t]*(?:'([^'\r\n]+)'|"([^"\r\n]+)"|([A-Za-z_][A-Za-z0-9_]*))[^\r\n]*(?:\r\n|\n|\r|$)/g
  for (const match of source.matchAll(opening)) {
    const label = match[1] ?? match[2] ?? match[3]
    const escaped = label.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
    const closing = new RegExp(`^[ \\t]*${escaped};?[ \\t]*(?:\\r?$)`, "gm")
    closing.lastIndex = match.index + match[0].length
    const terminator = closing.exec(source)
    const end = terminator ? terminator.index + terminator[0].length : source.length
    for (let i = match.index; i < end; i++) {
      if (source[i] !== "\n" && source[i] !== "\r") characters[i] = " "
    }
  }
  return characters.join("")
}

function uniqueSpans(spans) {
  const seen = new Set()
  return spans.filter(item => {
    const key = `${item.start}:${item.end}:${item.kind}`
    if (seen.has(key)) return false
    seen.add(key)
    return true
  })
}

function excludeLegalNotice(source, spans) {
  let cursor = 0
  if (source.startsWith("#!")) {
    const newline = source.indexOf("\n")
    cursor = newline < 0 ? source.length : newline + 1
  }
  const phpOpening = source.slice(cursor).match(/^[ \t]*<\?php\b/)
  if (phpOpening) cursor += phpOpening[0].length
  const leading = []
  for (const item of spans) {
    if (source.slice(cursor, item.start).trim() !== "") break
    leading.push(item)
    cursor = item.end
  }
  const header = leading.map(item => source.slice(item.start, item.end)).join("\n")
  const legal = /copyright|spdx-license-identifier|licensed under|third_party_licenses|ai-supplementary-terms/i.test(header)
  if (!legal) return spans
  const exempt = new Set(leading)
  return spans.filter(item => !exempt.has(item))
}

function scanGeneratedTemplates(file, source) {
  const bindings = generatedTemplateBindings.get(file.replaceAll("\\", "/"))
  if (!bindings) return []
  const results = []
  for (const binding of bindings) {
    const declaration = new RegExp(`\\blet\\s+${binding}\\b[\\s\\S]*?\``).exec(source)
    if (!declaration) continue
    const start = declaration.index + declaration[0].length - 1
    const end = consumeTemplateLiteral(source, start, {regex: true}, [])
    if (end <= start + 1) continue
    results.push(...offsetSpans(scanCLike(source.slice(start + 1, end - 1), {regex: true}), start + 1))
  }
  return results
}

export function classifyFile(file, source = "") {
  const base = basename(file)
  const extension = extname(base).toLowerCase()
  if (ignoredBasenames.has(base) || ignoredExtensions.has(extension)) return null
  if (base.endsWith(".html.heex")) return "template"
  if (htmlExtensions.has(extension)) return "template"
  if (extension === ".ex" || extension === ".exs") return "elixir"
  if (extension === ".py") return "python"
  if (extension === ".css" || extension === ".scss" || extension === ".less") return "css"
  if (extension === ".php") return "php"
  if (extension === ".bat" || extension === ".cmd") return "batch"
  if (extension === ".sql") return "sql"
  if (extension === ".mk" || hashBasenames.has(base) || /^Dockerfile(?:\..+)?$/.test(base) || /^Makefile(?:\..+)?$/.test(base) || /^Caddyfile(?:\..+)?$/.test(base)) return "hash"
  if (hashExtensions.has(extension) || base.endsWith(".env.example") || /(?:^|\/)env\.template$/.test(file)) return "hash"
  if (cLikeExtensions.has(extension) || cLikeBasenames.has(base)) return "clike"
  if (source.startsWith("#!") && /^#!.*\bpython[0-9.]*\b/.test(source.split(/\r?\n/, 1)[0])) return "python"
  if (source.startsWith("#!")) return "hash"
  return null
}

export function scanSource(file, source) {
  const kind = classifyFile(file, source)
  const extension = extname(file).toLowerCase()
  const normalized = file.replaceAll("\\", "/")
  if (kind === "clike") {
    const spans = scanCLike(source, {nested: extension === ".res" || extension === ".resi", regex: true, rescript: extension === ".res" || extension === ".resi"})
    return excludeLegalNotice(source, uniqueSpans([...spans, ...scanGeneratedTemplates(file, source)]).sort((a, b) => a.start - b.start))
  }
  if (kind === "css") return excludeLegalNotice(source, scanCLike(source, {lineComments: false}))
  if (kind === "elixir") return excludeLegalNotice(source, scanElixir(source))
  if (kind === "python") return excludeLegalNotice(source, scanPython(source))
  if (kind === "hash") return excludeLegalNotice(source, scanHash(source, {dockerfile: /^Dockerfile(?:\..+)?$/.test(basename(file)), semicolon: extension === ".ini" || extension === ".service", shell: extension === ".sh" || source.startsWith("#!"), yaml: extension === ".yaml" || extension === ".yml"}))
  if (kind === "php") return excludeLegalNotice(source, scanPhp(source))
  if (kind === "batch") return excludeLegalNotice(source, scanBatch(source))
  if (kind === "sql") return excludeLegalNotice(source, scanSql(source))
  if (kind === "template" && normalized.endsWith(".html.heex")) {
    const spans = uniqueSpans([...scanTemplate(source, extension), ...scanHeexExpressions(source)]).sort((a, b) => a.start - b.start)
    return excludeLegalNotice(source, spans)
  }
  if (kind === "template") return excludeLegalNotice(source, scanTemplate(source, extension))
  return []
}

export function fixSource(source, spans) {
  const covered = new Uint8Array(source.length)
  for (const item of spans) covered.fill(1, item.start, item.end)
  const characters = source.split("")
  for (let i = 0; i < source.length; i++) {
    if (covered[i] && source[i] !== "\n" && source[i] !== "\r") characters[i] = " "
  }
  for (const item of spans) {
    if (!item.replacement) continue
    for (let i = 0; i < item.replacement.length; i++) characters[item.start + i] = item.replacement[i]
  }
  let lineStart = 0
  while (lineStart < source.length) {
    let lineEnd = lineStart
    while (lineEnd < source.length && source[lineEnd] !== "\n" && source[lineEnd] !== "\r") lineEnd++
    let terminatorEnd = lineEnd
    if (source[terminatorEnd] === "\r") terminatorEnd++
    if (source[terminatorEnd] === "\n") terminatorEnd++
    const hasCovered = covered.slice(lineStart, lineEnd).some(Boolean)
    let hasContent = false
    for (let i = lineStart; i < lineEnd; i++) {
      if (characters[i] && characters[i] !== " " && characters[i] !== "\t") hasContent = true
    }
    if (hasCovered && !hasContent) {
      characters.fill("", lineStart, terminatorEnd)
    } else {
      let end = lineEnd
      while (end > lineStart && (characters[end - 1] === " " || characters[end - 1] === "\t")) end--
      if (covered.slice(end, lineEnd).some(Boolean)) characters.fill("", end, lineEnd)
    }
    lineStart = terminatorEnd
  }
  let fixed = characters.join("")
  let lastContent = source.length - 1
  while (lastContent >= 0 && (covered[lastContent] || /\s/.test(source[lastContent]))) lastContent--
  if (covered.slice(lastContent + 1).some(Boolean)) {
    const newline = source.endsWith("\r\n") ? "\r\n" : source.endsWith("\n") ? "\n" : ""
    fixed = fixed.replace(/\s+$/, "") + newline
  }
  return fixed
}

function location(source, index) {
  const before = source.slice(0, index)
  const line = before.split("\n").length
  const lastNewline = before.lastIndexOf("\n")
  return {line, column: index - lastNewline}
}

export function trackedFiles(root) {
  const output = execFileSync("git", ["ls-files", "-z"], {cwd: root})
  return output.toString().split("\0").filter(Boolean)
}

export function repositoryFiles(root) {
  return trackedFiles(root).filter(file => {
    const normalized = file.replaceAll("\\", "/")
    return !vendoredPaths.some(path => normalized.startsWith(path)) &&
      !normalized.startsWith("test/no-comments/fixtures/")
  })
}

function scanFiles(root, files, options = {}) {
  const violations = []
  let fixedFiles = 0
  for (const file of files) {
    const absolute = resolve(root, file)
    let source
    try {
      source = readFileSync(absolute, "utf8")
    } catch (error) {
      if (error.code === "ENOENT") continue
      throw error
    }
    if (!classifyFile(file, source)) continue
    const spans = scanSource(file, source)
    for (const item of spans) violations.push({file, ...location(source, item.start), kind: item.kind})
    if (options.fix && spans.length > 0) {
      const fixed = fixSource(source, spans)
      if (fixed !== source) {
        writeFileSync(absolute, fixed)
        fixedFiles++
      }
    }
  }
  return {violations, fixedFiles}
}

export function scanRepository(root, options = {}) {
  return scanFiles(root, repositoryFiles(root), options)
}

export function runCli(args, root = process.cwd()) {
  const invalid = args.filter(arg => arg !== "--check" && arg !== "--fix")
  if (invalid.length > 0 || (args.includes("--check") && args.includes("--fix"))) {
    process.stderr.write("Usage: no-comments.mjs [--check|--fix]\n")
    return 2
  }
  const fixing = args.includes("--fix")
  const result = scanRepository(root, {fix: fixing})
  if (fixing) {
    process.stdout.write(`Fixed ${result.violations.length} comment(s) in ${result.fixedFiles} file(s).\n`)
    return 0
  }
  for (const item of result.violations) process.stderr.write(`${item.file}:${item.line}:${item.column}: ${item.kind} comment\n`)
  if (result.violations.length > 0) process.stderr.write(`Found ${result.violations.length} comment(s).\n`)
  return result.violations.length > 0 ? 1 : 0
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) process.exitCode = runCli(process.argv.slice(2))
