WEBPACK_BUNDLE_ATTRS = {
    "srcs": attr.label_list(allow_files = True),
    "config_file": attr.label(
        allow_single_file = True,
        default = ":webpack.config.js",
    ),
    "entry_point": attr.label(
        allow_single_file = True,
        mandatory = True,
    ),
    "webpack_bin": attr.label(
        default = "@npm//webpack/bin:webpack",
        executable = True,
        cfg = "host",
    ),
    "deps": attr.label_list(
        aspects = [module_mappings_aspect, node_modules_aspect],
        doc = """Other libraries that are required by the code, or by the rollup.config.js""",
    ),
}

WEBPACK_BUNDLE_OUTS = {
    "bundle": "%{name}.js",
    "sourcemap": "%{name}.map",
}

def _webpack_bundle(ctx):
    args = ctx.actions.args()
    args.use_param_file("%s", use_always = True)
    args.add(ctx.outputs.bundle.path)
    args.add(ctx.outputs.sourcemap.path)
    args.add(ctx.file.entry_point.path)
    ctx.actions.run(
        inputs = ctx.files.srcs,
        executable = ctx.executable.webpack,
        outputs = [ctx.outputs.bundle, ctx.outputs.sourcemap],
        arguments = [args],
        progress_message = "Bundling JavaScript %s [webpack]" % ctx.outputs.bundle.path,
    )
    return [DefaultInfo()]

webpack_bundle = rule(
    attrs = WEBPACK_BUNDLE_ATTRS,
    outputs = WEBPACK_BUNDLE_OUTS,
    implementation = _webpack_bundle,
)
