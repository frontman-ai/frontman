// Case-insensitive filename matching used by search/listing guardrail helpers.
// Supports a minimal glob-style wildcard `*` syntax.

let matchesPattern = (~pattern: string, ~text: string): bool => {
  let patternLower = pattern->String.toLowerCase
  let textLower = text->String.toLowerCase

  switch patternLower {
  | "" => true
  | p if p->String.includes("*") => {
      let parts = p->String.split("*")
      let partsLength = Array.length(parts)

      parts->Array.reduceWithIndex(true, (matches, part, idx) =>
        switch (matches, part) {
        | (false, _) => false
        | (_, "") => true
        | _ if idx === 0 => textLower->String.startsWith(part)
        | _ if idx === partsLength - 1 => textLower->String.endsWith(part)
        | _ => textLower->String.includes(part)
        }
      )
    }
  | p => textLower->String.includes(p)
  }
}
