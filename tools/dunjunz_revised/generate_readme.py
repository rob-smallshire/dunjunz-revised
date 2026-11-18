"""README.md, rendered from README.md.j2.

The README is written in README.md.j2, a Jinja2 template; the parts that
come from the game itself, such as the keyboard layouts
(tools/dunjunz_revised/key_layouts.py), are filled in from there, so the
README cannot drift from the game. dr-build renders it whenever it builds,
and tests/test_readme.py fails if README.md is not the template rendered,
for instance after an edit made to README.md instead of the template.

    uv run dr-readme              # render README.md without building
"""

from __future__ import annotations

from pathlib import Path

from jinja2 import Environment, FileSystemLoader, StrictUndefined

from dunjunz_revised.key_layouts import markdown_name, named_layouts

PROJECT_DIRPATH = Path(__file__).resolve().parents[2]
TEMPLATE_FILENAME = "README.md.j2"
README_FILEPATH = PROJECT_DIRPATH / "README.md"


def readme_markdown() -> str:
    environment = Environment(
        loader=FileSystemLoader(PROJECT_DIRPATH),
        undefined=StrictUndefined,          # a misspelt name is an error, not a blank
        keep_trailing_newline=True,
        trim_blocks=True,
        lstrip_blocks=True,
    )
    template = environment.get_template(TEMPLATE_FILENAME)
    return template.render(layouts=named_layouts(markdown_name), template_filename=TEMPLATE_FILENAME)


def write_readme() -> bool:
    """Render README.md if it has changed; True if it was written."""
    text = readme_markdown()
    if README_FILEPATH.exists() and README_FILEPATH.read_text() == text:
        return False
    README_FILEPATH.write_text(text)
    return True


def main() -> None:
    print("Wrote README.md" if write_readme() else "README.md is up to date")


if __name__ == "__main__":
    main()
