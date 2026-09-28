let levenshtein = (a: string, b: string): int => {
  switch (a->String.length, b->String.length) {
  | (0, _) => b->String.length
  | (_, 0) => a->String.length
  | (lenA, lenB) =>
    let matrix = Array.fromInitializer(~length=lenA + 1, i =>
      Array.fromInitializer(~length=lenB + 1, j =>
        switch (i, j) {
        | (0, j) => j
        | (i, 0) => i
        | _ => 0
        }
      )
    )

    for i in 1 to lenA {
      for j in 1 to lenB {
        let cost = switch a->String.charAt(i - 1) == b->String.charAt(j - 1) {
        | true => 0
        | false => 1
        }
        let del = matrix[i - 1]->Option.getOrThrow->Array.getUnsafe(j) + 1
        let ins = matrix[i]->Option.getOrThrow->Array.getUnsafe(j - 1) + 1
        let sub = matrix[i - 1]->Option.getOrThrow->Array.getUnsafe(j - 1) + cost
        matrix[i]->Option.getOrThrow->Array.setUnsafe(j, min(del, min(ins, sub)))
      }
    }

    matrix[lenA]->Option.getOrThrow->Array.getUnsafe(lenB)
  }
}

let lineOffset = (lines: array<string>, lineIndex: int): int => {
  let offset = ref(0)
  for k in 0 to lineIndex - 1 {
    offset := offset.contents + lines[k]->Option.getOrThrow->String.length + 1
  }
  offset.contents
}

let extractBlock = (
  content: string,
  lines: array<string>,
  startLine: int,
  endLine: int,
): string => {
  let startIdx = lineOffset(lines, startLine)
  let endIdx = lineOffset(lines, endLine) + lines[endLine]->Option.getOrThrow->String.length
  content->String.slice(~start=startIdx, ~end=endIdx)
}

let escapeRegex = (str: string): string => {
  str->String.replaceRegExp(/[.*+?^${}()|[\\]\\\\]/g, "\\$&")
}

let exactMatch = (content: string, find: string): array<string> => {
  switch content->String.includes(find) {
  | true => [find]
  | false => []
  }
}

let lineTrimMatch = (content: string, find: string): array<string> => {
  let contentLines = content->String.split("\n")
  let searchLines = find->String.split("\n")

  let searchLines = switch searchLines[searchLines->Array.length - 1] {
  | Some(last) if last == "" =>
    searchLines->Array.slice(~start=0, ~end=searchLines->Array.length - 1)
  | _ => searchLines
  }

  let searchLen = searchLines->Array.length
  let results = []

  for i in 0 to contentLines->Array.length - searchLen {
    let matches = ref(true)
    let j = ref(0)

    while j.contents < searchLen && matches.contents {
      let origTrimmed = contentLines[i + j.contents]->Option.getOrThrow->String.trim
      let searchTrimmed = searchLines[j.contents]->Option.getOrThrow->String.trim

      switch origTrimmed == searchTrimmed {
      | true => j := j.contents + 1
      | false => matches := false
      }
    }

    switch matches.contents {
    | true => results->Array.push(extractBlock(content, contentLines, i, i + searchLen - 1))
    | false => ()
    }
  }

  results
}

let singleCandidateThreshold = 0.0
let multipleCandidateThreshold = 0.3

type candidate = {startLine: int, endLine: int}

let anchoredBlockMatch = (content: string, find: string): array<string> => {
  let contentLines = content->String.split("\n")
  let searchLines = find->String.split("\n")

  let searchLines = switch searchLines[searchLines->Array.length - 1] {
  | Some(last) if last == "" =>
    searchLines->Array.slice(~start=0, ~end=searchLines->Array.length - 1)
  | _ => searchLines
  }

  switch searchLines->Array.length < 3 {
  | true => []
  | false =>
    let firstLineSearch = searchLines[0]->Option.getOrThrow->String.trim
    let lastLineSearch = searchLines[searchLines->Array.length - 1]->Option.getOrThrow->String.trim
    let searchBlockSize = searchLines->Array.length

    let candidates = []
    for i in 0 to contentLines->Array.length - 1 {
      switch contentLines[i]->Option.getOrThrow->String.trim == firstLineSearch {
      | false => ()
      | true =>
        let j = ref(i + 2)
        while j.contents < contentLines->Array.length {
          switch contentLines[j.contents]->Option.getOrThrow->String.trim == lastLineSearch {
          | true =>
            candidates->Array.push({startLine: i, endLine: j.contents})
            j := j.contents + 1
          | false => j := j.contents + 1
          }
        }
      }
    }

    switch candidates->Array.length {
    | 0 => []
    | 1 =>
      let {startLine, endLine} = candidates[0]->Option.getOrThrow
      let actualBlockSize = endLine - startLine + 1
      let linesToCheck = min(searchBlockSize - 2, actualBlockSize - 2)

      let similarity = switch linesToCheck > 0 {
      | false => 1.0
      | true =>
        let sim = ref(0.0)
        let j = ref(1)
        while j.contents < searchBlockSize - 1 && j.contents < actualBlockSize - 1 {
          let origLine = contentLines[startLine + j.contents]->Option.getOrThrow->String.trim
          let searchLine = searchLines[j.contents]->Option.getOrThrow->String.trim
          let maxLen = max(origLine->String.length, searchLine->String.length)->Int.toFloat
          switch maxLen > 0.0 {
          | false => ()
          | true =>
            let distance = levenshtein(origLine, searchLine)->Int.toFloat
            sim := sim.contents +. (1.0 -. distance /. maxLen) /. linesToCheck->Int.toFloat
          }
          switch sim.contents >= singleCandidateThreshold {
          | true => j := searchBlockSize
          | false => j := j.contents + 1
          }
        }
        sim.contents
      }

      switch similarity >= singleCandidateThreshold {
      | true => [extractBlock(content, contentLines, startLine, endLine)]
      | false => []
      }
    | _ =>
      let bestMatch = ref(None)
      let maxSim = ref(-1.0)

      candidates->Array.forEach(cand => {
        let {startLine, endLine} = cand
        let actualBlockSize = endLine - startLine + 1
        let linesToCheck = min(searchBlockSize - 2, actualBlockSize - 2)

        let similarity = switch linesToCheck > 0 {
        | false => 1.0
        | true =>
          let sim = ref(0.0)
          for j in 1 to min(searchBlockSize - 2, actualBlockSize - 2) {
            let origLine = contentLines[startLine + j]->Option.getOrThrow->String.trim
            let searchLine = searchLines[j]->Option.getOrThrow->String.trim
            let maxLen = max(origLine->String.length, searchLine->String.length)->Int.toFloat
            switch maxLen > 0.0 {
            | false => ()
            | true =>
              let distance = levenshtein(origLine, searchLine)->Int.toFloat
              sim := sim.contents +. (1.0 -. distance /. maxLen)
            }
          }
          sim.contents /. linesToCheck->Int.toFloat
        }

        switch similarity > maxSim.contents {
        | true =>
          maxSim := similarity
          bestMatch := Some(cand)
        | false => ()
        }
      })

      switch (maxSim.contents >= multipleCandidateThreshold, bestMatch.contents) {
      | (true, Some({startLine, endLine})) => [
          extractBlock(content, contentLines, startLine, endLine),
        ]
      | _ => []
      }
    }
  }
}

let normalizedWhitespaceMatch = (content: string, find: string): array<string> => {
  let normalize = (text: string): string => text->String.replaceRegExp(/\s+/g, " ")->String.trim

  let normalizedFind = normalize(find)
  let contentLines = content->String.split("\n")
  let results = []

  contentLines->Array.forEach(line => {
    switch normalize(line) == normalizedFind {
    | true => results->Array.push(line)
    | false =>
      let normalizedLine = normalize(line)
      switch normalizedLine->String.includes(normalizedFind) {
      | false => ()
      | true =>
        let words =
          find
          ->String.trim
          ->String.splitByRegExp(/\s+/)
          ->Array.filterMap(x => x)
        switch words->Array.length > 0 {
        | false => ()
        | true =>
          let pattern = words->Array.map(escapeRegex)->Array.join("\\s+")
          try {
            let regex = RegExp.fromString(pattern)
            switch line->String.match(regex) {
            | Some(result) =>
              switch result->RegExp.Result.fullMatch {
              | m if m->String.length > 0 => results->Array.push(m)
              | _ => ()
              }
            | None => ()
            }
          } catch {
          | _ => ()
          }
        }
      }
    }
  })

  let findLines = find->String.split("\n")
  switch findLines->Array.length > 1 {
  | false => ()
  | true =>
    for i in 0 to contentLines->Array.length - findLines->Array.length {
      let block =
        contentLines
        ->Array.slice(~start=i, ~end=i + findLines->Array.length)
        ->Array.join("\n")
      switch normalize(block) == normalizedFind {
      | true => results->Array.push(block)
      | false => ()
      }
    }
  }

  results
}

let flexibleIndentMatch = (content: string, find: string): array<string> => {
  let removeIndent = (text: string): string => {
    let lines = text->String.split("\n")
    let nonEmptyLines = lines->Array.filter(line => line->String.trim->String.length > 0)

    switch nonEmptyLines->Array.length {
    | 0 => text
    | _ =>
      let minIndent = nonEmptyLines->Array.reduce(999999, (acc, line) => {
        let m = line->String.match(/^(\s*)/)
        let indent = switch m {
        | Some(result) => result->RegExp.Result.fullMatch->String.length
        | None => 0
        }
        min(acc, indent)
      })

      lines
      ->Array.map(line =>
        switch line->String.trim->String.length {
        | 0 => line
        | _ => line->String.slice(~start=minIndent, ~end=line->String.length)
        }
      )
      ->Array.join("\n")
    }
  }

  let normalizedFind = removeIndent(find)
  let contentLines = content->String.split("\n")
  let findLines = find->String.split("\n")
  let results = []

  for i in 0 to contentLines->Array.length - findLines->Array.length {
    let block =
      contentLines
      ->Array.slice(~start=i, ~end=i + findLines->Array.length)
      ->Array.join("\n")
    switch removeIndent(block) == normalizedFind {
    | true => results->Array.push(block)
    | false => ()
    }
  }

  results
}

let escapeNormalizedMatch = (content: string, find: string): array<string> => {
  let unescape: string => string = %raw(`
    function(str) {
      return str.replace(/\\([ntr'"\\/$])/g, function(_m, c) {
        if (c === 'n') return String.fromCharCode(10);
        if (c === 't') return String.fromCharCode(9);
        if (c === 'r') return String.fromCharCode(13);
        return c;
      });
    }
  `)

  let unescapedFind = unescape(find)
  let results = []

  switch content->String.includes(unescapedFind) {
  | true => results->Array.push(unescapedFind)
  | false => ()
  }

  let contentLines = content->String.split("\n")
  let findLines = unescapedFind->String.split("\n")

  for i in 0 to contentLines->Array.length - findLines->Array.length {
    let block =
      contentLines
      ->Array.slice(~start=i, ~end=i + findLines->Array.length)
      ->Array.join("\n")
    let unescapedBlock = unescape(block)
    switch unescapedBlock == unescapedFind && !(results->Array.includes(block)) {
    | true => results->Array.push(block)
    | false => ()
    }
  }

  results
}

let trimmedBoundaryMatch = (content: string, find: string): array<string> => {
  let trimmedFind = find->String.trim

  switch trimmedFind == find {
  | true => []
  | false =>
    let results = []

    switch content->String.includes(trimmedFind) {
    | true => results->Array.push(trimmedFind)
    | false => ()
    }

    let contentLines = content->String.split("\n")
    let findLines = find->String.split("\n")

    for i in 0 to contentLines->Array.length - findLines->Array.length {
      let block =
        contentLines
        ->Array.slice(~start=i, ~end=i + findLines->Array.length)
        ->Array.join("\n")
      switch block->String.trim == trimmedFind && !(results->Array.includes(block)) {
      | true => results->Array.push(block)
      | false => ()
      }
    }

    results
  }
}

let contextAnchorMatch = (content: string, find: string): array<string> => {
  let findLines = find->String.split("\n")

  let findLines = switch findLines[findLines->Array.length - 1] {
  | Some(last) if last == "" => findLines->Array.slice(~start=0, ~end=findLines->Array.length - 1)
  | _ => findLines
  }

  switch findLines->Array.length < 3 {
  | true => []
  | false =>
    let contentLines = content->String.split("\n")
    let firstLine = findLines[0]->Option.getOrThrow->String.trim
    let lastLine = findLines[findLines->Array.length - 1]->Option.getOrThrow->String.trim
    let results = []

    for i in 0 to contentLines->Array.length - 1 {
      switch contentLines[i]->Option.getOrThrow->String.trim == firstLine {
      | false => ()
      | true =>
        let j = ref(i + 2)
        while j.contents < contentLines->Array.length {
          switch contentLines[j.contents]->Option.getOrThrow->String.trim == lastLine {
          | false => j := j.contents + 1
          | true =>
            let blockLines = contentLines->Array.slice(~start=i, ~end=j.contents + 1)

            switch blockLines->Array.length == findLines->Array.length {
            | false => ()
            | true =>
              let matchingLines = ref(0)
              let totalNonEmpty = ref(0)

              for k in 1 to blockLines->Array.length - 2 {
                let blockLine = blockLines[k]->Option.getOrThrow->String.trim
                let findLine = findLines[k]->Option.getOrThrow->String.trim

                switch (blockLine->String.length > 0, findLine->String.length > 0) {
                | (false, false) => ()
                | _ =>
                  totalNonEmpty := totalNonEmpty.contents + 1
                  switch blockLine == findLine {
                  | true => matchingLines := matchingLines.contents + 1
                  | false => ()
                  }
                }
              }

              let passes = switch totalNonEmpty.contents {
              | 0 => true
              | total => matchingLines.contents->Int.toFloat /. total->Int.toFloat >= 0.5
              }

              switch passes {
              | true => results->Array.push(extractBlock(content, contentLines, i, j.contents))
              | false => ()
              }
            }
            j := j.contents + 1
          }
        }
      }
    }

    results
  }
}

let multiOccurrenceMatch = (content: string, find: string): array<string> => {
  let results = []
  let startIndex = ref(0)

  let continue_ = ref(true)
  while continue_.contents {
    let searchContent =
      content->String.slice(~start=startIndex.contents, ~end=content->String.length)
    let idx = searchContent->String.indexOfOpt(find)->Option.map(i => i + startIndex.contents)
    switch idx {
    | None => continue_ := false
    | Some(i) =>
      results->Array.push(find)
      startIndex := i + find->String.length
    }
  }

  results
}

type editResult =
  | Applied(string)
  | NotFound
  | Ambiguous

let strategies = [
  exactMatch,
  lineTrimMatch,
  anchoredBlockMatch,
  normalizedWhitespaceMatch,
  flexibleIndentMatch,
  escapeNormalizedMatch,
  trimmedBoundaryMatch,
  contextAnchorMatch,
  multiOccurrenceMatch,
]

let applyEdit = (
  ~content: string,
  ~oldText: string,
  ~newText: string,
  ~replaceAll: bool=false,
): editResult => {
  let notFound = ref(true)

  let result = ref(None)
  let strategyIdx = ref(0)

  while result.contents->Option.isNone && strategyIdx.contents < strategies->Array.length {
    let strategy = strategies[strategyIdx.contents]->Option.getOrThrow
    let candidates = strategy(content, oldText)

    switch (!replaceAll && candidates->Array.length > 1, replaceAll) {
    | (true, _) => notFound := false
    | (_, true) =>
      candidates->Array.forEach(candidate => {
        switch result.contents {
        | Some(_) => ()
        | None =>
          let idx = content->String.indexOf(candidate)
          switch idx >= 0 {
          | false => ()
          | true =>
            notFound := false
            result := Some(Applied(content->String.split(candidate)->Array.join(newText)))
          }
        }
      })
    | (false, false) =>
      switch candidates[0] {
      | None => ()
      | Some(candidate) =>
        let idx = content->String.indexOf(candidate)
        switch idx >= 0 {
        | false => ()
        | true =>
          notFound := false
          let lastIdx = content->String.lastIndexOf(candidate)
          switch idx == lastIdx {
          | false => ()
          | true =>
            let before = content->String.slice(~start=0, ~end=idx)
            let after =
              content->String.slice(
                ~start=idx + candidate->String.length,
                ~end=content->String.length,
              )
            result := Some(Applied(before ++ newText ++ after))
          }
        }
      }
    }

    strategyIdx := strategyIdx.contents + 1
  }

  switch result.contents {
  | Some(r) => r
  | None =>
    switch notFound.contents {
    | true => NotFound
    | false => Ambiguous
    }
  }
}
