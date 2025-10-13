#!/usr/bin/env python3
"""Configuration loader for Wyoming Kokoro server."""

import json
import logging
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

_LOGGER = logging.getLogger(__name__)


@dataclass
class ServerConfig:
    """Server configuration settings."""

    language: str = "en-gb"
    voice: str = "bm_lewis"
    speed: float = 1.2
    host: str = "0.0.0.0"
    port: int = 10200
    model_path: str = "./models/kokoro-v1.0.onnx"
    voices_path: str = "./models/voices-v1.0.bin"

    @classmethod
    def from_file(cls, config_path: Optional[Path] = None) -> "ServerConfig":
        """
        Load configuration from JSON file.

        Args:
            config_path: Path to config.json file. If None, looks for config.json
                        in current directory.

        Returns:
            ServerConfig with values from file, or defaults if file doesn't exist.
        """
        if config_path is None:
            config_path = Path("config.json")

        if not config_path.exists():
            _LOGGER.info(
                f"Config file {config_path} not found, using defaults: "
                f"voice={cls.voice}, speed={cls.speed}, "
                f"host={cls.host}, port={cls.port}, language={cls.language}, "
                f"model={cls.model_path}, voices={cls.voices_path}"
            )
            return cls()

        try:
            with open(config_path, "r") as f:
                data = json.load(f)

            config = cls(
                language=data.get("language", cls.language),
                voice=data.get("voice", cls.voice),
                speed=float(data.get("speed", cls.speed)),
                host=data.get("host", cls.host),
                port=int(data.get("port", cls.port)),
                model_path=data.get("model_path", cls.model_path),
                voices_path=data.get("voices_path", cls.voices_path),
            )

            _LOGGER.info(
                f"Loaded config from {config_path}: "
                f"voice={config.voice}, speed={config.speed}, "
                f"host={config.host}, port={config.port}, language={config.language}, "
                f"model={config.model_path}, voices={config.voices_path}"
            )

            return config

        except json.JSONDecodeError as e:
            _LOGGER.error(f"Failed to parse {config_path}: {e}")
            _LOGGER.info("Using default configuration")
            return cls()
        except Exception as e:
            _LOGGER.error(f"Error reading config file {config_path}: {e}")
            _LOGGER.info("Using default configuration")
            return cls()
