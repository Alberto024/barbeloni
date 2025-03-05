import marimo

__generated_with = "0.11.14"
app = marimo.App(width="medium")


@app.cell
def _():
    import marimo as mo
    from aquarel import load_theme

    from barbeloni.utils import setup_logger
    return load_theme, mo, setup_logger


@app.cell
def _():
    return


if __name__ == "__main__":
    app.run()
