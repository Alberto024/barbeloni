import logging

from rich.logging import RichHandler


def setup_logger(
    name: str,
    level: int = logging.DEBUG,
) -> logging.Logger:
    """Create logger for general use."""
    logging.basicConfig(
        level=level,
        format="%(message)s",
        datefmt="[%X]",
        handlers=[RichHandler(rich_tracebacks=True)],
    )
    return logging.getLogger(name)


if __name__ == "__main__":
    setup_logger(name=10)
