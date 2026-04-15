// ANSI terminal styling for CLI output
// Brand purple: #985DF7 (primary), #8051CD (secondary)

let esc = "\x1b"

// Color functions — wrap text with ANSI codes
let purple = text => `${esc}[38;2;152;93;247m${text}${esc}[0m`
let purpleBold = text => `${esc}[1;38;2;152;93;247m${text}${esc}[0m`
let purpleDim = text => `${esc}[38;2;128;81;205m${text}${esc}[0m`
let green = text => `${esc}[32m${text}${esc}[0m`
let yellow = text => `${esc}[33m${text}${esc}[0m`
let yellowBold = text => `${esc}[1;33m${text}${esc}[0m`
let bold = text => `${esc}[1m${text}${esc}[0m`
let dim = text => `${esc}[2m${text}${esc}[0m`

// Symbols
let check = green("✔")
let warn = yellow("⚠")
let bullet = purple("▸")

// Decorative
let divider = purple(
  "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
)
