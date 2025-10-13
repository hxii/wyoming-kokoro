#!/usr/bin/env python3
"""Wyoming protocol server for Kokoro TTS using kokoro-onnx package."""

import argparse
import asyncio
import logging
import time
from functools import partial
from pathlib import Path

from kokoro_onnx import Kokoro
from wyoming.info import Attribution, Info, TtsProgram, TtsVoice
from wyoming.server import AsyncServer

from .config import ServerConfig
from .handler import KokoroONNXEventHandler

_LOGGER = logging.getLogger(__name__)


async def main() -> None:
    """Main entry point for Wyoming Kokoro ONNX server."""
    parser = argparse.ArgumentParser(description="Wyoming Kokoro TTS Server (ONNX)")
    parser.add_argument(
        "--config",
        default="config.json",
        help="Path to config.json file (default: config.json)",
    )
    parser.add_argument(
        "--uri",
        default=None,
        help="URI to bind server (overrides config file)",
    )
    parser.add_argument(
        "--model",
        default=None,
        help="Path to ONNX model file (overrides config file)",
    )
    parser.add_argument(
        "--voices",
        default=None,
        help="Path to voices .bin file (overrides config file)",
    )
    parser.add_argument(
        "--debug",
        action="store_true",
        help="Enable debug logging",
    )

    args = parser.parse_args()

    logging.basicConfig(
        level=logging.DEBUG if args.debug else logging.INFO,
        format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    )

    _LOGGER.info("Starting Wyoming Kokoro TTS server (ONNX Runtime)")

    # Load configuration
    config = ServerConfig.from_file(Path(args.config))

    # Determine host and port (command line overrides config file)
    if args.uri:
        # Parse URI from command line
        uri_parts = args.uri.split("://")
        if len(uri_parts) != 2:
            raise ValueError(f"Invalid URI format: {args.uri}")

        protocol, address = uri_parts
        if protocol != "tcp":
            raise ValueError(f"Unsupported protocol: {protocol}")

        host, port = address.rsplit(":", 1)
        port = int(port)
        uri = args.uri
    else:
        # Use config file values
        host = config.host
        port = config.port
        uri = f"tcp://{host}:{port}"

    # Determine model and voice paths (command line overrides config file)
    model_path = Path(args.model) if args.model else Path(config.model_path)
    voices_path = Path(args.voices) if args.voices else Path(config.voices_path)

    if not model_path.exists():
        raise FileNotFoundError(f"Model file not found: {model_path}")
    if not voices_path.exists():
        raise FileNotFoundError(f"Voice file not found: {voices_path}")

    # Define voice information for Home Assistant
    voices = [
        TtsVoice(
            name="bm_lewis",
            description="British Male - Lewis",
            attribution=Attribution(
                name="Kokoro TTS (ONNX)",
                url="https://huggingface.co/hexgrad/Kokoro-82M",
            ),
            installed=True,
            version="1.0",
            languages=["en-GB", "en"],
        )
    ]

    # Create server info
    server_info = Info(
        tts=[
            TtsProgram(
                name="kokoro-onnx",
                description="Kokoro TTS - Fast neural text-to-speech (ONNX Runtime)",
                attribution=Attribution(
                    name="Kokoro TTS",
                    url="https://huggingface.co/hexgrad/Kokoro-82M",
                ),
                installed=True,
                version="1.0-onnx",
                voices=voices,
            )
        ]
    )

    _LOGGER.info(f"Server listening on {host}:{port}")
    _LOGGER.info(f"Model: {model_path}")
    _LOGGER.info(f"Voices: {voices_path}")
    _LOGGER.info("Available voice: bm_lewis (British Male)")

    # Pre-load the Kokoro ONNX model at startup
    _LOGGER.info("Loading Kokoro ONNX model...")
    start = time.time()

    try:
        kokoro = Kokoro(
            model_path=str(model_path),
            voices_path=str(voices_path)
        )

        elapsed = time.time() - start
        _LOGGER.info(f"Model loaded in {elapsed:.2f}s")
        _LOGGER.info(f"Using voice: {config.voice} at speed {config.speed} (language: {config.language})")

        # Report available voices
        available_voices = kokoro.get_voices()
        _LOGGER.info(f"Available voices: {', '.join(available_voices)}")

    except Exception as e:
        _LOGGER.error(f"Failed to load model: {e}")
        raise

    # Create server with handler factory
    server = AsyncServer.from_uri(uri)

    await server.run(
        partial(
            KokoroONNXEventHandler,
            server_info,
            kokoro,
            config,
        )
    )


if __name__ == "__main__":
    asyncio.run(main())
