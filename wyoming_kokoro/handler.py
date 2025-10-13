#!/usr/bin/env python3
"""Event handler for Kokoro TTS Wyoming server using kokoro-onnx package."""

import logging
import time
import warnings
from pathlib import Path
from typing import Optional

import numpy as np
from kokoro_onnx import Kokoro
from scipy import signal
from wyoming.audio import AudioChunk, AudioStart, AudioStop
from wyoming.event import Event
from wyoming.info import Describe, Info
from wyoming.server import AsyncEventHandler
from wyoming.tts import Synthesize, SynthesizeStop

from .config import ServerConfig

# Suppress warnings
warnings.filterwarnings("ignore", category=UserWarning)
warnings.filterwarnings("ignore", category=FutureWarning)

_LOGGER = logging.getLogger(__name__)

# Wyoming standard: 22050 Hz, 16-bit PCM, mono
TARGET_SAMPLE_RATE = 22050
KOKORO_SAMPLE_RATE = 24000


class KokoroONNXEventHandler(AsyncEventHandler):
    """Event handler for Kokoro ONNX TTS requests."""

    def __init__(
        self,
        server_info: Info,
        kokoro: Kokoro,
        config: ServerConfig,
        *args,
        **kwargs,
    ) -> None:
        """Initialize handler with pre-loaded Kokoro instance and configuration."""
        super().__init__(*args, **kwargs)
        self.server_info = server_info
        self.kokoro = kokoro
        self.config = config

    async def handle_event(self, event: Event) -> bool:
        """Handle Wyoming protocol events."""
        _LOGGER.debug(f"Received event: {event}")

        if Describe.is_type(event.type):
            await self.write_event(self.server_info.event())
            return True

        if Synthesize.is_type(event.type):
            synthesize = Synthesize.from_event(event)
            await self._handle_synthesize(synthesize)
            return True

        return True

    async def _handle_synthesize(self, synthesize: Synthesize) -> None:
        """Handle TTS synthesis request."""
        text = synthesize.text.strip()
        if not text:
            _LOGGER.warning("Empty text received, skipping")
            return

        _LOGGER.info(f"Synthesizing: '{text[:50]}...' ({len(text)} chars)")

        try:
            # Measure generation time
            gen_start = time.time()

            # Generate audio using kokoro-onnx with configured settings
            audio, sample_rate = self.kokoro.create(
                text=text,
                voice=self.config.voice,
                speed=self.config.speed,
                lang=self.config.language,
                trim=True
            )

            gen_elapsed = time.time() - gen_start

            # Check if audio was generated
            if len(audio) == 0:
                _LOGGER.error("Generated audio is empty - model produced no output")
                await self.write_event(SynthesizeStop().event())
                return

            _LOGGER.debug(f"Generated audio: {len(audio)} samples at {sample_rate}Hz")

            # Resample from 24kHz to 22.05kHz if needed (Wyoming standard)
            if sample_rate != TARGET_SAMPLE_RATE:
                audio_resampled = self._resample_audio(
                    audio, sample_rate, TARGET_SAMPLE_RATE
                )
            else:
                audio_resampled = audio

            _LOGGER.debug(f"Resampled audio: {len(audio_resampled)} samples at {TARGET_SAMPLE_RATE}Hz")

            # Convert to 16-bit PCM
            audio_int16 = self._convert_to_int16(audio_resampled)

            # Send audio start event
            await self.write_event(
                AudioStart(
                    rate=TARGET_SAMPLE_RATE,
                    width=2,  # 16-bit = 2 bytes
                    channels=1,  # mono
                ).event()
            )

            # Send audio in chunks
            chunk_size = 4096  # bytes
            audio_bytes = audio_int16.tobytes()

            # Calculate duration from actual audio bytes being sent
            duration = len(audio_bytes) / 2 / TARGET_SAMPLE_RATE  # divide by 2 for 16-bit samples
            rtf = gen_elapsed / duration if duration > 0 else 0
            _LOGGER.info(
                f"Generated {duration:.2f}s audio in {gen_elapsed:.3f}s (RTF: {rtf:.2f}x)"
            )

            for i in range(0, len(audio_bytes), chunk_size):
                chunk = audio_bytes[i : i + chunk_size]
                await self.write_event(
                    AudioChunk(
                        rate=TARGET_SAMPLE_RATE,
                        width=2,
                        channels=1,
                        audio=chunk,
                    ).event()
                )

            # Send audio stop event
            await self.write_event(AudioStop().event())

            # Send synthesize stopped event
            await self.write_event(SynthesizeStop().event())

            _LOGGER.info("Synthesis completed successfully")

        except Exception as e:
            _LOGGER.error(f"Error during synthesis: {e}", exc_info=True)
            await self.write_event(SynthesizeStop().event())

    @staticmethod
    def _resample_audio(audio: np.ndarray, orig_sr: int, target_sr: int) -> np.ndarray:
        """Resample audio to target sample rate."""
        if orig_sr == target_sr:
            return audio

        if len(audio) == 0:
            _LOGGER.warning("Cannot resample empty audio array")
            return audio

        # Use round() instead of int() to avoid truncating to 0 on small samples
        num_samples = round(len(audio) * target_sr / orig_sr)
        if num_samples == 0:
            _LOGGER.warning(f"Resampling would produce 0 samples (input: {len(audio)} samples)")
            return audio

        return signal.resample(audio, num_samples)

    @staticmethod
    def _convert_to_int16(audio_float: np.ndarray) -> np.ndarray:
        """Convert float audio [-1, 1] to 16-bit signed PCM."""
        audio_float = np.clip(audio_float, -1.0, 1.0)
        audio_int16 = (audio_float * 32767).astype(np.int16)
        return audio_int16
