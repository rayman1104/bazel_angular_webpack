load("@build_bazel_rules_nodejs//:providers.bzl", "JSEcmaScriptModuleInfo", "NpmPackageInfo", "node_modules_aspect", "run_node")
load("@build_bazel_rules_nodejs//internal/linker:link_node_modules.bzl", "module_mappings_aspect")

WEBPACK_BUNDLE_ATTRS = {
    "srcs": attr.label_list(allow_files = True),
    "config_file": attr.label(
        allow_single_file = True,
        default = ":webpack.config.js",
    ),
    "entry_points": attr.label_keyed_string_dict(
        allow_files = True,
    ),
    "entry_point": attr.label(
        allow_single_file = True,
    ),
    "output_dir": attr.bool(),
    "webpack_bin": attr.label(
        default = "@npm//webpack/bin:webpack",
        executable = True,
        cfg = "host",
    ),
    "sourcemap": attr.string(
        default = "inline",
        values = ["inline", "hidden", "true", "false"],
    ),
    "deps": attr.label_list(
        aspects = [module_mappings_aspect, node_modules_aspect],
    ),
}

def _webpack_outs(sourcemap, name, entry_point, entry_points, output_dir):
    """Supply some labelled outputs in the common case of a single entry point"""
    result = {}
    entry_point_outs = _desugar_entry_point_names(name, entry_point, entry_points)
    if output_dir:
        # We can't declare a directory output here, because RBE will be confused, like
        # com.google.devtools.build.lib.remote.ExecutionStatusException:
        # INTERNAL: failed to upload outputs: failed to construct CAS files:
        # failed to calculate file hash:
        # read /b/f/w/bazel-out/k8-fastbuild/bin/packages/rollup/test/multiple_entry_points/chunks: is a directory
        #result["chunks"] = output_dir
        return {}
    else:
        if len(entry_point_outs) > 1:
            fail("Multiple entry points require that output_dir be set")
        out = entry_point_outs[0]
        result[out] = out + ".js"

        if sourcemap == "true":
            result[out + "_map"] = "%s.map" % result[out]
    return result

def _no_ext(f):
    return f.short_path[:-len(f.extension) - 1]

def _resolve_js_input(f, inputs):
    if f.extension == "js" or f.extension == "mjs":
        return f

    # look for corresponding js file in inputs
    no_ext = _no_ext(f)
    for i in inputs:
        if i.extension == "js" or i.extension == "mjs":
            if _no_ext(i) == no_ext:
                return i
    fail("Could not find corresponding javascript entry point for %s. Add the %s.js to your deps." % (f.path, no_ext))

def _desugar_entry_point_names(name, entry_point, entry_points):
    """Users can specify entry_point (sugar) or entry_points (long form).
    This function allows our code to treat it like they always used the long form.
    It also performs validation:
    - exactly one of these attributes should be specified
    """
    if entry_point and entry_points:
        fail("Cannot specify both entry_point and entry_points")
    if not entry_point and not entry_points:
        fail("One of entry_point or entry_points must be specified")
    if entry_point:
        return [name]
    return entry_points.values()

def _desugar_entry_points(name, entry_point, entry_points, inputs):
    """Like above, but used by the implementation function, where the types differ.
    It also performs validation:
    - attr.label_keyed_string_dict doesn't accept allow_single_file
      so we have to do validation now to be sure each key is a label resulting in one file
    It converts from dict[target: string] to dict[file: string]
    """
    names = _desugar_entry_point_names(name, entry_point.label if entry_point else None, entry_points)

    if entry_point:
        return {_resolve_js_input(entry_point.files.to_list()[0], inputs): names[0]}

    result = {}
    for ep in entry_points.items():
        entry_point = ep[0]
        name = ep[1]
        f = entry_point.files.to_list()
        if len(f) != 1:
            fail("keys in webpack_bundle#entry_points must provide one file, but %s has %s" % (entry_point.label, len(f)))
        result[_resolve_js_input(f[0], inputs)] = name
    return result

def _filter_js(files):
    return [f for f in files if f.extension == "js" or f.extension == "mjs"]

def _webpack_bundle(ctx):
    # webpack_bundle supports deps with JS providers. For each dep,
    # JSEcmaScriptModuleInfo is used if found, then JSModuleInfo and finally
    # the DefaultInfo files are used if the former providers are not found.
    deps_depsets = []
    for dep in ctx.attr.deps:
        if JSEcmaScriptModuleInfo in dep:
            deps_depsets.append(dep[JSEcmaScriptModuleInfo].sources)
        elif hasattr(dep, "files"):
            deps_depsets.append(dep.files)

        # Also include files from npm deps as inputs.
        # These deps are identified by the NpmPackageInfo provider.
        if NpmPackageInfo in dep:
            deps_depsets.append(dep[NpmPackageInfo].sources)
    deps_inputs = depset(transitive = deps_depsets).to_list()

    inputs = _filter_js(ctx.files.entry_point) + _filter_js(ctx.files.entry_points) + ctx.files.srcs + deps_inputs
    outputs = [getattr(ctx.outputs, o) for o in dir(ctx.outputs)]

    # See CLI documentation at https://webpack.js.org/api/cli/
    args = ctx.actions.args()

    # List entry point argument first to save some argv space
    # They should be provided as the first options
    entry_points = _desugar_entry_points(ctx.label.name, ctx.attr.entry_point, ctx.attr.entry_points, inputs).items()

    # If user requests an output_dir, then use output.dir rather than output.file
    if ctx.attr.output_dir:
        outputs.append(ctx.actions.declare_directory(ctx.label.name))
        for entry_point in entry_points:
            args.add_joined([entry_point[1], entry_point[0]], join_with = "=")

        args.add_all(["--output-path", outputs[0].path])
    else:
        args.add(entry_points[0][0])
        args.add_all(["-o", outputs[0].path])

    config = ctx.actions.declare_file("_%s.webpack_config.js" % ctx.label.name)
    ctx.actions.expand_template(
        template = ctx.file.config_file,
        output = config,
        substitutions = {
            "bazel_stamp_file": "\"%s\"" % ctx.version_file.path if ctx.version_file else "undefined",
        },
    )

    args.add_all(["--config", config.path])
    inputs.append(config)

    if ctx.version_file:
        inputs.append(ctx.version_file)

    run_node(
        ctx,
        progress_message = "Bundling JavaScript %s [webpack]" % outputs[0].short_path,
        executable = "webpack_bin",
        inputs = inputs,
        outputs = outputs,
        arguments = [args],
    )

    return [
        DefaultInfo(files = depset(outputs)),
    ]

webpack_bundle = rule(
    attrs = WEBPACK_BUNDLE_ATTRS,
    outputs = _webpack_outs,
    implementation = _webpack_bundle,
)
