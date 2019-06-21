# Load the relevant upstream methods.
load(
    "@intellij_aspect//:intellij_info_impl.bzl",
    "intellij_info_aspect_impl",
    "make_intellij_info_aspect",
)
load(
    "@intellij_aspect//:intellij_info_bundled.bzl",
    "tool_label",
)

# Directory depth to files under bazel-out
BAZEL_OUT_PREFIX_DEPTH = 3

def _struct_assoc(struct_, **extra_key_values):
    """ Associate extra_key_values onto a copy of struct_ """
    copy = {attr: getattr(struct_, attr)
            for attr in dir(struct_)
            if attr not in ["to_json", "to_proto"]}
    copy.update(extra_key_values)
    return struct(**copy)

def _uniq(l):
    return {k:1 for k in l}.keys()

def _extra_include_info(target, ctx, ide_info, ide_info_file, output_groups):
    c_info = ide_info.get("c_ide_info", None)
    if c_info == None:
        # Not a C / C++ target.
        return False

    c_include_info = struct(
        header = c_info.header,
        source = c_info.source,
        target_copt = c_info.target_copt,
        textual_header = c_info.textual_header,
        transitive_define = c_info.transitive_define,
        transitive_include_directory = _replace_virtual_includes(c_info.transitive_include_directory, ctx),
        transitive_quote_include_directory = c_info.transitive_quote_include_directory,
        transitive_system_include_directory = c_info.transitive_system_include_directory,
    )
    ide_info["c_ide_info"] = c_include_info
    return False

def _replace_virtual_includes(transitive_include_directories, ctx):
    results = []
    include_info = _calculate_include_dirs(ctx)

    for t in transitive_include_directories:
        if t.find("/_virtual_includes/") >= 0:
            parts = t.replace("/_virtual_includes/", "/", 1).split("/")
            if parts[BAZEL_OUT_PREFIX_DEPTH] == "external":
                results.append(t)
                continue

            package_name = "/".join(parts[BAZEL_OUT_PREFIX_DEPTH:])

            if package_name in include_info.keys():
                results.extend(include_info[package_name])
            else:
                fail("no include info for package " + package_name)
        else:
            fail("invalid transitive include directory" + t)

    return _uniq(results)

def _extract_include_directories(ctx):
    headers = []
    if hasattr(ctx.rule.attr, "hdrs"):
        headers += ctx.rule.attr.hdrs
    return _uniq([file.dirname for hdr in headers for file in hdr.files.to_list()])

def _strip_bazel_out_directory(package, include_dir, strip_include_prefix):
    return "/".join(include_dir.split("/")[:BAZEL_OUT_PREFIX_DEPTH]) + "/" + package + strip_include_prefix

def _calculate_include_dirs(ctx):
    package = ctx.label.package + "/" if ctx.label.package else ctx.label.package
    strip_include_prefix = getattr(ctx.rule.attr, "strip_include_prefix", None)
    include_prefix = getattr(ctx.rule.attr, "include_prefix", None)

    include_info = dict()
    for d in getattr(ctx.rule.attr, "deps", []):
        include_info.update(d.include_info)

    updated_include_dirs = []
    if strip_include_prefix != None or include_prefix != None:
        strip_include_prefix = strip_include_prefix or ""
        include_dirs = _extract_include_directories(ctx)
        for i in include_dirs:
            if i.startswith(package):
                updated_include_dirs.append(package + strip_include_prefix)
            else:
                updated_include_dirs.append(_strip_bazel_out_directory(package, i, strip_include_prefix))

    include_info.update({package + ctx.rule.attr.name: _uniq(updated_include_dirs)})

    return include_info

def _extra_ide_info(target, ctx, ide_info, ide_info_file, output_groups):
    _extra_include_info(target, ctx, ide_info, ide_info_file, output_groups)
    return False

def _aspect_impl(target, ctx):
    intellij_info = intellij_info_aspect_impl(target, ctx, semantics)
    include_info = _calculate_include_dirs(ctx)
    return _struct_assoc(intellij_info, include_info = include_info)

# Define the relevant semantics (see intellij_info_bundled.bzl).
semantics = struct(
    extra_ide_info = _extra_ide_info,
    tool_label = tool_label,
    flag_hack_label = "//:flag_hack",
)

intellij_info_aspect = make_intellij_info_aspect(_aspect_impl, semantics)
