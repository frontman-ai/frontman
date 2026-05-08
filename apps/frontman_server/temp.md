1. Installed Expert through mise in repo mise.toml:
"github:expert-lsp/expert" = { version = "0.1.4", exe = "expert_darwin_arm64" }
2. Updated Helix ~/.config/helix/languages.toml:
[language-server.expert]
command = "mise"
args = ["exec", "-C", "/Users/danni/dev/frontman", "--", "expert", "--stdio"]
environment = { MIX_OS_DEPS_COMPILE_PARTITION_COUNT = "1" }
timeout = 120
Then for Elixir:
[[language]]
name = "elixir"
language-servers = [ "expert" ]
And for HEEx:
[[language]]
name = "heex"
language-servers = [ "expert", "tailwindcss-ls", "vscode-html-language-server" ]
