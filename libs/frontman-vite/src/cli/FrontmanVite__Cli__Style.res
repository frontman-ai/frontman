let esc = "\x1b"

let purple = text => `${esc}[38;2;152;93;247m${text}${esc}[0m`
let purpleBold = text => `${esc}[1;38;2;152;93;247m${text}${esc}[0m`
let purpleDim = text => `${esc}[38;2;128;81;205m${text}${esc}[0m`
let green = text => `${esc}[32m${text}${esc}[0m`
let yellow = text => `${esc}[33m${text}${esc}[0m`
let yellowBold = text => `${esc}[1;33m${text}${esc}[0m`
let bold = text => `${esc}[1m${text}${esc}[0m`
let dim = text => `${esc}[2m${text}${esc}[0m`

let check = green("✔")
let warn = yellow("⚠")
let bullet = purple("▸")

let divider = purple(
  "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
)
