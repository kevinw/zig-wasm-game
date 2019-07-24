import os.path
import io
import re

path_to_components = "src/components/"
generated_file = "src/components_auto.zig"
generated_session_file = "src/session.zig"

component_name_re = re.compile(r"pub const\s+(\w+)\s+=\s+struct")
think_re = re.compile(r"(\w+)?\s*fn update\(\w+: \*GameSession, (.*)\)\s+(\w+)\s*")

def to_module_name(kls):
    return f"components/{kls.lower()}.zig"

def gen_game_session(output, structs):
    components = "\n".join(
        f"    {name}: gbe.ComponentList({name}),"
        for name in structs)

    output.write(f"""// AUTO-GENERATED
const gbe = @import("gbe");

usingnamespace @import("components.zig");
usingnamespace @import("globals.zig");

pub const EntityId = gbe.EntityId;

pub const GameSession = gbe.Session(struct {{
{components}
}});
    """)

def process_component_file(output, filename, to_import):
    component_name = None

    reqs = []
    for line in (l.strip() for l in open(filename, "r").readlines()):
        if component_name is None:
            match = component_name_re.search(line.strip())
            if match is not None:
                component_name = match.group(1)
        if "fn update(" in line:
            m = think_re.search(line)
            if m is None:
                raise Exception("expected line to look like an update function: " + line)

            think = m.groups()
            visibility, args, return_type = think
            if visibility != "pub":
                raise Exception("update fn must be pub")
            if return_type != "bool":
                raise Exception("return type of update fn must be 'bool'")
            for arg in args.split(","):
                var, typename = arg.split(":")
                var = var.strip()
                typename = typename.strip()
                reqs.append((var, typename))

    lines = []
    if component_name is not None:
        lines.append("""usingnamespace @import("session.zig");""")
        to_import.add(component_name)
        for typename in set(t for v, t in reqs):
            if typename.startswith("*"): typename = typename[1:]
            to_import.add(typename)
        lines.append(f"""
const {component_name}_SystemData = struct {{
    id: EntityId,""")
        lines.extend(f"    {var_name}: {type_name}," for var_name, type_name in reqs)
        args_str = ", ".join("self.{}".format(r[0]) for r in reqs)
        lines.append(f"""}};

pub const run_{component_name} = GameSession.buildSystem({component_name}_SystemData, {component_name}_think);

inline fn {component_name}_think(gs: *GameSession, self: {component_name}_SystemData) bool {{
    const mod = @import("{to_module_name(component_name)}");
    return @inlineCall(mod.update, gs, {args_str});
}}
        """)

    return lines

def write_contents_if_different(filename, contents):
    if not os.path.isfile(filename) or open(filename, 'r', newline='\n').read().replace("\r","") != contents.replace("\r", ""):
        print("writing", filename)
        open(filename, "w", newline="\n").write(contents)

def main():
    output = io.StringIO()

    to_import = set()
    all_lines = []
    for filename in os.listdir(path_to_components):
        all_lines.extend(process_component_file(output, os.path.join(path_to_components, filename), to_import))

    to_import = sorted(list(to_import))

    output.writelines(["pub const {} = @import(\"{}\").{};\n".format(
        t, to_module_name(t), t) for t in to_import])

    for line in all_lines:
        output.write(line)
        output.write("\n")

    # run all
    output.write("pub fn run_ALL(gs: *GameSession) void {\n")
    for t in to_import:
        output.write(f"    run_{t}(gs);\n");
    output.write("}\n")

    write_contents_if_different(generated_file, output.getvalue())

    session_output = io.StringIO()
    gen_game_session(session_output, to_import)
    write_contents_if_different(generated_session_file, session_output.getvalue())


if __name__ == "__main__":
    main()
