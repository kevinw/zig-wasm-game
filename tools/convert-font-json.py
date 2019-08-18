import os
import sys
import json
import io

SCRIPT_DIR = os.path.dirname(os.path.realpath(__file__))

def zig_repr(o):
    if type(o) == str:
        return f"\"{o}\""

    return f"{o}"

def main():
    filename = sys.argv[1]
    output_filename = sys.argv[2]

    json_contents = io.open(filename, mode='r', encoding="utf-8").read()
    output_file = io.open(output_filename, mode='w', encoding='utf-8', newline='\n')
    font_data = json.loads(json_contents)

    consts = [(key, font_data[key]) for key in 'family style buffer size'.split()]
    consts_text = "\n".join(f"pub const {a} = {zig_repr(b)};" for (a, b) in consts)

    characters_lines = []
    for ch, values in font_data['chars'].items():
        vals_comma_separated = ", ".join(str(c) for c in [0 if i >= len(values) else values[i] for i in range(7)])
        if ch == "\"":
            ch = "\\\""
        if ch == "\\":
            ch = "\\\\"
        characters_lines.append(f"        _metrics.putNoClobber(std.unicode.utf8Decode(\"{ch}\") catch unreachable, MetricsEntry{{.values=[7]i16 {{ {vals_comma_separated} }} }}) catch unreachable;")
    characters_text = "\n".join(characters_lines)

    template_args = dict(
        consts_text=consts_text,
        characters=characters_text,
    )

    output_text_template = io.open(os.path.join(SCRIPT_DIR, "convert-font-json.template.zig")).read()
    output_text = output_text_template.format(**template_args)

    print(output_text, file=output_file)
    print(output_text)


if __name__ == "__main__":
    main()

