# =============================================================================
# Build stage — prebuilt Erlang+Elixir, no compilation from source
# =============================================================================
FROM hexpm/elixir:1.19.3-erlang-28.1-debian-bookworm-20260202-slim AS builder

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends build-essential git curl xz-utils ca-certificates \
    libssl-dev libncurses-dev && \
    apt-get clean && rm -f /var/lib/apt/lists/*_*

# Install Node.js (for ReScript/JS build steps)
ARG NODE_VERSION=24.4.1
RUN curl -fsSL https://deb.nodesource.com/setup_24.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    apt-get clean && rm -f /var/lib/apt/lists/*_*

# Install Yarn via corepack
RUN corepack enable

WORKDIR /app

# ---------- JS dependencies (monorepo root) ----------
COPY package.json yarn.lock .yarnrc.yml ./
# Copy workspace package.json files so Yarn can resolve the workspace graph
COPY apps/frontman_server/assets/package.json apps/frontman_server/assets/package.json
COPY libs/bindings/package.json libs/bindings/
COPY libs/client/package.json libs/client/
COPY libs/context-loader/package.json libs/context-loader/
COPY libs/experimental-rescript-webapi/package.json libs/experimental-rescript-webapi/
COPY libs/frontman-client/package.json libs/frontman-client/
COPY libs/frontman-protocol/package.json libs/frontman-protocol/
COPY libs/frontman-core/package.json libs/frontman-core/
COPY libs/frontman-astro/package.json libs/frontman-astro/
COPY libs/frontman-nextjs/package.json libs/frontman-nextjs/
COPY libs/react-statestore/package.json libs/react-statestore/
COPY libs/logs/package.json libs/logs/
COPY libs/vite-plugin/package.json libs/vite-plugin/
COPY apps/chrome-extension/package.json apps/chrome-extension/
COPY apps/marketing/package.json apps/marketing/
COPY test/sites/blog-starter/package.json test/sites/blog-starter/

RUN yarn install --immutable

# ---------- ReScript build ----------
COPY rescript.json rescript.json
COPY libs/ libs/
COPY apps/chrome-extension/ apps/chrome-extension/

RUN yarn rescript clean && yarn rescript build

# ---------- Elixir dependencies ----------
ENV MIX_ENV="prod"

COPY apps/frontman_server/mix.exs apps/frontman_server/mix.lock apps/frontman_server/

WORKDIR /app/apps/frontman_server

RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get --only $MIX_ENV

# Copy compile-time config before compiling deps to ensure config
# changes trigger recompilation
RUN mkdir -p config
COPY apps/frontman_server/config/config.exs apps/frontman_server/config/${MIX_ENV}.exs config/
RUN mix deps.compile

RUN mix tailwind.install --if-missing && mix esbuild.install --if-missing

# ---------- Compile application ----------
COPY apps/frontman_server/priv priv
COPY apps/frontman_server/lib lib
RUN mix compile

COPY apps/frontman_server/assets assets
RUN mix tailwind frontman_server --minify && \
    mix esbuild frontman_server --minify && \
    mix esbuild browser_test --minify && \
    mix phx.digest

# runtime.exs doesn't require recompiling the code
COPY apps/frontman_server/config/runtime.exs config/

COPY apps/frontman_server/rel rel
RUN mix release

# =============================================================================
# Runtime stage — slim, no build tools
# =============================================================================
FROM debian:bookworm-slim

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends libstdc++6 openssl libncurses6 locales ca-certificates && \
    apt-get clean && rm -f /var/lib/apt/lists/*_*

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8
ENV PHX_SERVER=true
ENV MIX_ENV="prod"

WORKDIR /app
RUN chown nobody /app

COPY --from=builder --chown=nobody:root /app/apps/frontman_server/_build/${MIX_ENV}/rel/frontman_server ./

USER nobody

EXPOSE 4000

CMD ["/app/bin/server"]
