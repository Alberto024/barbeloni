import logging
from pathlib import Path

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict
from rich.logging import RichHandler


def setup_logger(
    name: str,
    level: int = logging.DEBUG,
) -> logging.Logger:
    """Create logger for general use."""
    logging.basicConfig(
        level=level,
        format='%(message)s',
        datefmt='[%X]',
        handlers=[RichHandler(rich_tracebacks=True)],
    )
    return logging.getLogger(name)


class Settings(BaseSettings):
    """Configuration settings loaded from environment variables."""

    google_application_credentials: Path = Field(
        default=None,
        description='Path to the Google service account credentials JSON file',
    )

    model_config = SettingsConfigDict(
        env_file='.env', env_file_encoding='utf-8', extra='ignore'
    )


settings = Settings()
