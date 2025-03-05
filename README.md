# barbeloni
A little helper for your barbell

## Instructions for setting up dev environments

### Modeling

1. Install uv
2. Open modeling folder in vscode. It will ask you something like "A git repository was found in the parent folders of the workspace or the open file(s). Would you like to open the repository?". Click yes to open the parent git repository.
3. Install Pylance, Ruff, Jupyter, and Marimo extensions
4. Open a terminal in modeling folder
5. Run `uv sync --all-extras`
6. Run `uv pre-commit install`
7. In bottom right corner, select `.venv/bin/python` as python interpreter.