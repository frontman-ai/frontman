RescriptPackageInfo = provider(
    fields = {
        "package_name": "npm package name exported by this target",
        "output": "compiled package directory",
        "direct_deps": "direct ReScript package deps used by this build mode",
    },
)

RESCRIPT_OUTPUT_EXCLUDES = [
    "**/*.gen.tsx",
    "**/*.res.d.ts",
    "**/*.res.js",
    "**/*.res.js.map",
    "**/*.res.mjs",
    "**/*.res.mjs.map",
]

_MIGRATED_PACKAGES = [
    "@rescript/webapi",
    "@frontman/bindings",
    "@frontman-ai/react-statestore",
    "@frontman/logs",
    "@frontman-ai/frontman-protocol",
    "@frontman-ai/frontman-client",
    "@frontman-ai/frontman-core",
    "@frontman-ai/astro-browser",
    "@frontman-ai/client",
]

def _copy_manifest_lines(files, package_path):
    lines = []
    prefix = package_path + "/" if package_path else ""

    for src in files:
        rel = src.short_path
        if prefix and rel.startswith(prefix):
            rel = rel[len(prefix):]
        lines.append("%s\t%s" % (src.path, rel))

    return "\n".join(lines) + "\n"

def _setup_node_modules_script():
    migrated = " ".join(["'%s'" % package for package in _MIGRATED_PACKAGES])

    return """
setup_node_modules() {
  local pkg_dir="$1"
  local root_nm="$2"

  if [ ! -d "$root_nm" ]; then
    echo "missing node_modules at $root_nm" >&2
    exit 1
  fi

  mkdir -p "$pkg_dir/node_modules"

  for entry in "$root_nm"/*; do
    [ -e "$entry" ] || continue
    local base
    base="$(basename "$entry")"

    if [ "$base" = ".bin" ]; then
      ln -s "$entry" "$pkg_dir/node_modules/.bin"
    elif [ "${base#@}" != "$base" ]; then
      mkdir -p "$pkg_dir/node_modules/$base"
      for scoped in "$entry"/*; do
        [ -e "$scoped" ] || continue
        ln -s "$scoped" "$pkg_dir/node_modules/$base/$(basename "$scoped")"
      done
    else
      ln -s "$entry" "$pkg_dir/node_modules/$base"
    fi
  done

  for package in __MIGRATED_PACKAGES__; do
    rm -rf "$pkg_dir/node_modules/$package"
  done
}

link_package_dep() {
  local pkg_dir="$1"
  local package_name="$2"
  local package_path="$3"
  local dest="$pkg_dir/node_modules/$package_name"
  mkdir -p "$(dirname "$dest")"
  rm -rf "$dest"
  ln -s "$package_path" "$dest"
}

copy_package_dep() {
  local pkg_dir="$1"
  local package_name="$2"
  local package_path="$3"
  local dest="$pkg_dir/node_modules/$package_name"
  mkdir -p "$(dirname "$dest")"
  rm -rf "$dest"
  cp -a "$package_path" "$dest"
  chmod -R u+w "$dest"
}
""".replace("__MIGRATED_PACKAGES__", migrated)

def _ensure_node_script():
    return """
ensure_node() {
  if command -v node >/dev/null 2>&1; then
    return
  fi

  for node_bin in "${HOME:-}/.local/share/mise/installs/node"/*/bin /home/*/.local/share/mise/installs/node/*/bin /usr/local/bin /usr/bin; do
    if [ -x "$node_bin/node" ]; then
      export PATH="$node_bin:$PATH"
      return
    fi
  done

  echo "missing node executable on PATH" >&2
  exit 1
}
"""

def _build_command(manifest, out, dep_infos, dev):
    dep_links = []
    for dep in dep_infos:
        dep_links.append("copy_package_dep \"$pkg\" %s \"$execroot/%s\"" % (
            _shell_quote(dep.package_name),
            dep.output.path,
        ))

    build_args = "build"

    return """
set -euo pipefail

execroot="$PWD"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/rescript-bazel.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

pkg="$tmp/package"
mkdir -p "$pkg"

while IFS=$'\t' read -r src rel; do
  [ -n "$src" ] || continue
  mkdir -p "$pkg/$(dirname "$rel")"
  cp "$src" "$pkg/$rel"
done < "$execroot/__MANIFEST__"

mkdir -p "$pkg/src" "$pkg/test" "$pkg/tests" "$pkg/scripts"

__SETUP_NODE_MODULES__
__ENSURE_NODE__

ensure_node
setup_node_modules "$pkg" "$execroot/node_modules"
__DEP_LINKS__

cd "$pkg"
"$execroot/node_modules/.bin/rescript" __BUILD_ARGS__

rm -rf "$pkg/node_modules"
rm -rf "$execroot/__OUT__"
mkdir -p "$execroot/__OUT__"
cp -a "$pkg/." "$execroot/__OUT__/"
""".replace("__MANIFEST__", manifest.path).replace(
        "__SETUP_NODE_MODULES__",
        _setup_node_modules_script(),
    ).replace(
        "__ENSURE_NODE__",
        _ensure_node_script(),
    ).replace(
        "__DEP_LINKS__",
        "\n".join(dep_links),
    ).replace(
        "__BUILD_ARGS__",
        build_args,
    ).replace(
        "__OUT__",
        out.path,
    )

def _shell_quote(value):
    return "'" + value.replace("'", "'\\''") + "'"

def _rescript_package_impl(ctx):
    out = ctx.actions.declare_directory(ctx.label.name + "_pkg")
    manifest = ctx.actions.declare_file(ctx.label.name + "_sources.txt")
    srcs = ctx.files.srcs
    dep_infos = [dep[RescriptPackageInfo] for dep in ctx.attr.deps]

    ctx.actions.write(
        output = manifest,
        content = _copy_manifest_lines(srcs, ctx.label.package),
    )

    ctx.actions.run_shell(
        inputs = depset(srcs + [manifest] + [dep.output for dep in dep_infos]),
        outputs = [out],
        command = _build_command(manifest, out, dep_infos, ctx.attr.dev),
        execution_requirements = {
            "local": "1",
            "no-remote": "1",
            "no-sandbox": "1",
        },
        use_default_shell_env = True,
        mnemonic = "ReScriptBuild",
        progress_message = "Building ReScript package %s" % ctx.attr.package_name,
    )

    return [
        DefaultInfo(files = depset([out])),
        RescriptPackageInfo(
            package_name = ctx.attr.package_name,
            output = out,
            direct_deps = dep_infos,
        ),
    ]

_rescript_package = rule(
    implementation = _rescript_package_impl,
    attrs = {
        "package_name": attr.string(mandatory = True),
        "srcs": attr.label_list(allow_files = True),
        "deps": attr.label_list(providers = [RescriptPackageInfo]),
        "dev": attr.bool(default = False),
    },
)

def _test_script(package, runner):
    dep_links = []
    for dep in package.direct_deps:
        dep_links.append("link_package_dep \"$pkg\" %s \"$dep_root/%s\"" % (
            _shell_quote(dep.package_name),
            dep.output.short_path,
        ))

    if runner == "vitest":
        run = """
cd "$pkg"
export NODE_OPTIONS="${NODE_OPTIONS:-} --preserve-symlinks"
"$root_nm/.bin/vitest" run
"""
    elif runner == "compile":
        run = """
test -d "$pkg/lib"
"""
    else:
        fail("unknown ReScript test runner: %s" % runner)

    return """#!/usr/bin/env bash
set -euo pipefail

runfiles="${RUNFILES_DIR:-$0.runfiles}"
workspace="${TEST_WORKSPACE:-frontman}"
test_cwd="$PWD"
execroot="$PWD"
root_nm="$test_cwd/node_modules"

if [ ! -d "$root_nm" ] && [[ "$test_cwd" == */bazel-out/* ]]; then
  execroot="${test_cwd%%/bazel-out/*}"
  root_nm="$execroot/node_modules"
fi

if [ ! -d "$root_nm" ] && [ -n "${BUILD_WORKSPACE_DIRECTORY:-}" ]; then
  root_nm="$BUILD_WORKSPACE_DIRECTORY/node_modules"
fi

pkg_src="$runfiles/$workspace/__PACKAGE_SHORT_PATH__"
dep_root="$runfiles/$workspace"

if [ ! -d "$pkg_src" ]; then
  pkg_src="$execroot/__PACKAGE_PATH__"
  dep_root="$execroot"
fi

tmp="$(mktemp -d "${TMPDIR:-/tmp}/rescript-bazel-test.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

pkg="$tmp/package"
mkdir -p "$pkg"
cp -a "$pkg_src/." "$pkg/"
chmod -R u+w "$pkg"

__SETUP_NODE_MODULES__
__ENSURE_NODE__

ensure_node
setup_node_modules "$pkg" "$root_nm"
__DEP_LINKS__

__RUN__
""".replace("__PACKAGE_SHORT_PATH__", package.output.short_path).replace(
        "__PACKAGE_PATH__",
        package.output.path,
    ).replace(
        "__SETUP_NODE_MODULES__",
        _setup_node_modules_script(),
    ).replace(
        "__ENSURE_NODE__",
        _ensure_node_script(),
    ).replace(
        "__DEP_LINKS__",
        "\n".join(dep_links),
    ).replace(
        "__RUN__",
        run,
    )

def _rescript_package_test_impl(ctx):
    package = ctx.attr.package[RescriptPackageInfo]
    executable = ctx.actions.declare_file(ctx.label.name + ".sh")

    ctx.actions.write(
        output = executable,
        content = _test_script(package, ctx.attr.runner),
        is_executable = True,
    )

    runfiles = ctx.runfiles(files = [package.output] + [dep.output for dep in package.direct_deps])

    return [
        DefaultInfo(
            executable = executable,
            runfiles = runfiles,
        ),
    ]

_rescript_package_test = rule(
    implementation = _rescript_package_test_impl,
    attrs = {
        "package": attr.label(mandatory = True, providers = [RescriptPackageInfo]),
        "runner": attr.string(default = "vitest", values = ["compile", "vitest"]),
    },
    test = True,
)

def _schema_export_command(package, script, schemas_dir, static_manifest, out):
    dep_links = []
    for dep in package.direct_deps:
        dep_links.append("copy_package_dep \"$pkg\" %s \"$execroot/%s\"" % (
            _shell_quote(dep.package_name),
            dep.output.path,
        ))

    return """
set -euo pipefail

execroot="$PWD"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/rescript-bazel-schemas.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

pkg="$tmp/package"
mkdir -p "$pkg"
cp -a "$execroot/__PACKAGE_PATH__/." "$pkg/"
chmod -R u+w "$pkg"

__SETUP_NODE_MODULES__
__ENSURE_NODE__

ensure_node
setup_node_modules "$pkg" "$execroot/node_modules"
__DEP_LINKS__

rm -rf "$pkg/__SCHEMAS_DIR__"
mkdir -p "$pkg/__SCHEMAS_DIR__"

while IFS=$'\t' read -r src rel; do
  [ -n "$src" ] || continue
  mkdir -p "$pkg/$(dirname "$rel")"
  cp "$src" "$pkg/$rel"
done < "$execroot/__STATIC_MANIFEST__"

cd "$pkg"
node "__SCRIPT__"

rm -rf "$execroot/__OUT__"
mkdir -p "$execroot/__OUT__"
cp -a "$pkg/__SCHEMAS_DIR__/." "$execroot/__OUT__/"
""".replace("__PACKAGE_PATH__", package.output.path).replace(
        "__SETUP_NODE_MODULES__",
        _setup_node_modules_script(),
    ).replace(
        "__ENSURE_NODE__",
        _ensure_node_script(),
    ).replace(
        "__DEP_LINKS__",
        "\n".join(dep_links),
    ).replace(
        "__STATIC_MANIFEST__",
        static_manifest.path,
    ).replace(
        "__SCHEMAS_DIR__",
        schemas_dir,
    ).replace(
        "__SCRIPT__",
        script,
    ).replace(
        "__OUT__",
        out.path,
    )

def _rescript_schema_export_impl(ctx):
    package = ctx.attr.package[RescriptPackageInfo]
    out = ctx.actions.declare_directory(ctx.label.name + "_out")
    static_manifest = ctx.actions.declare_file(ctx.label.name + "_static_schemas.txt")

    ctx.actions.write(
        output = static_manifest,
        content = _copy_manifest_lines(ctx.files.static_schema_files, ctx.label.package),
    )

    ctx.actions.run_shell(
        inputs = depset(
            [package.output, static_manifest] +
            ctx.files.static_schema_files +
            [dep.output for dep in package.direct_deps],
        ),
        outputs = [out],
        command = _schema_export_command(package, ctx.attr.script, ctx.attr.schemas_dir, static_manifest, out),
        execution_requirements = {
            "local": "1",
            "no-remote": "1",
            "no-sandbox": "1",
        },
        use_default_shell_env = True,
        mnemonic = "ReScriptSchemaExport",
        progress_message = "Exporting ReScript schemas %s" % ctx.label,
    )

    return [DefaultInfo(files = depset([out]))]

rescript_schema_export = rule(
    implementation = _rescript_schema_export_impl,
    attrs = {
        "package": attr.label(mandatory = True, providers = [RescriptPackageInfo]),
        "script": attr.string(mandatory = True),
        "schemas_dir": attr.string(default = "schemas"),
        "static_schema_files": attr.label_list(allow_files = True),
    },
)

def _schema_manifest_lines(files, package_path, schemas_dir):
    lines = []
    prefix = package_path + "/" + schemas_dir + "/" if package_path else schemas_dir + "/"

    for src in files:
        rel = src.short_path
        if rel.startswith(prefix):
            rel = rel[len(prefix):]
        lines.append("%s\t%s" % (src.short_path, rel))

    return "\n".join(lines) + "\n"

def _schema_check_script(generated, manifest):
    return """#!/usr/bin/env bash
set -euo pipefail

runfiles="${RUNFILES_DIR:-$0.runfiles}"
workspace="${TEST_WORKSPACE:-}"
execroot="$PWD"

generated=""
manifest=""
runfiles_workspace=""

for candidate_workspace in "$workspace" _main frontman; do
  [ -n "$candidate_workspace" ] || continue
  candidate_generated="$runfiles/$candidate_workspace/__GENERATED_SHORT_PATH__"
  candidate_manifest="$runfiles/$candidate_workspace/__MANIFEST_SHORT_PATH__"
  if [ -d "$candidate_generated" ] && [ -f "$candidate_manifest" ]; then
    generated="$candidate_generated"
    manifest="$candidate_manifest"
    runfiles_workspace="$candidate_workspace"
    break
  fi
done

if [ -z "$generated" ]; then
  generated="$execroot/__GENERATED_PATH__"
fi

if [ -z "$manifest" ]; then
  manifest="$execroot/__MANIFEST_PATH__"
fi

tmp="$(mktemp -d "${TMPDIR:-/tmp}/rescript-bazel-check-schemas.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

expected="$tmp/expected.txt"
actual="$tmp/actual.txt"
: > "$expected"

while IFS=$'\t' read -r src rel; do
  [ -n "$src" ] || continue
  printf '%s\n' "$rel" >> "$expected"
done < "$manifest"

sort -o "$expected" "$expected"
(cd "$generated" && find . -type f -name '*.json' -print | while read -r file; do printf '%s\n' "${file#./}"; done | sort) > "$actual"

failed=0
if ! diff -u "$expected" "$actual"; then
  echo "Generated schema file list differs from committed schemas" >&2
  failed=1
fi

while IFS=$'\t' read -r src rel; do
  [ -n "$src" ] || continue
  committed="$runfiles/$runfiles_workspace/$src"
  if [ ! -f "$committed" ]; then
    committed="$execroot/$src"
  fi

  generated_file="$generated/$rel"
  if [ ! -f "$generated_file" ]; then
    echo "Missing generated schema: $rel" >&2
    failed=1
    continue
  fi

  if ! cmp -s "$committed" "$generated_file"; then
    echo "Schema mismatch: $rel" >&2
    diff -u "$committed" "$generated_file" || true
    failed=1
  fi
done < "$manifest"

exit "$failed"
""".replace("__GENERATED_SHORT_PATH__", generated.short_path).replace(
        "__GENERATED_PATH__",
        generated.path,
    ).replace(
        "__MANIFEST_SHORT_PATH__",
        manifest.short_path,
    ).replace(
        "__MANIFEST_PATH__",
        manifest.path,
    )

def _schema_check_test_impl(ctx):
    generated = ctx.files.generated
    if len(generated) != 1:
        fail("schema_check_test generated attr must have exactly one output")

    manifest = ctx.actions.declare_file(ctx.label.name + "_schemas.txt")
    executable = ctx.actions.declare_file(ctx.label.name + ".sh")

    ctx.actions.write(
        output = manifest,
        content = _schema_manifest_lines(ctx.files.schema_files, ctx.label.package, ctx.attr.schemas_dir),
    )

    ctx.actions.write(
        output = executable,
        content = _schema_check_script(generated[0], manifest),
        is_executable = True,
    )

    runfiles = ctx.runfiles(files = ctx.files.schema_files + generated + [manifest])

    return [
        DefaultInfo(
            executable = executable,
            runfiles = runfiles,
        ),
    ]

schema_check_test = rule(
    implementation = _schema_check_test_impl,
    attrs = {
        "generated": attr.label(mandatory = True),
        "schema_files": attr.label_list(allow_files = True, mandatory = True),
        "schemas_dir": attr.string(default = "schemas"),
    },
    test = True,
)

def rescript_package(name, package_name, srcs, dev_srcs = [], deps = [], dev_deps = [], test_runner = None, visibility = None):
    kwargs = {}
    if visibility != None:
        kwargs["visibility"] = visibility

    _rescript_package(
        name = name,
        package_name = package_name,
        srcs = srcs,
        deps = deps,
        **kwargs
    )

    if test_runner != None:
        _rescript_package(
            name = name + "_dev",
            package_name = package_name,
            srcs = srcs + dev_srcs,
            deps = deps + dev_deps,
            dev = True,
            visibility = ["//visibility:private"],
        )

        _rescript_package_test(
            name = "test",
            package = ":" + name + "_dev",
            runner = test_runner,
            tags = ["local", "no-remote", "no-sandbox"],
            **kwargs
        )
