# Wyoming Kokoro TTS

A Wyoming protocol server for Kokoro TTS using ONNX Runtime, enabling integration with Home Assistant voice assistants.

## Features

- **Fast TTS** using Kokoro-82M model with ONNX Runtime
- **CPU and GPU support** - No CUDA required (but works with GPU if available)
- **Wyoming protocol** compatible with Home Assistant
- **Low latency** synthesis with 0.4s model loading
- **High quality** British English voice (bm_lewis)
- **Small footprint** - ~300MB installation
- **52 voices** available in multiple languages

## Requirements

- Python 3.9-3.12
- CPU (ARM64 or x86_64) or optional GPU
- espeak-ng for phonemization
- ~300MB disk space

## Installation

### Quick Start

```bash
# 1. Install system dependencies
sudo apt-get install espeak-ng python3-pip

# 2. Install Python dependencies
pip install -r requirements.txt

# 3. Download model files (one-time)
cd models
wget https://github.com/nazdridoy/kokoro-tts/releases/download/v1.0.0/kokoro-v1.0.onnx
wget https://github.com/nazdridoy/kokoro-tts/releases/download/v1.0.0/voices-v1.0.bin
cd ..

# 4. Run the server
./script/run
```

### Using HuggingFace Models

If you prefer to use models from HuggingFace instead of pre-converted ones:

```bash
# 1. Download from HuggingFace
cd models
wget https://huggingface.co/onnx-community/Kokoro-82M-v1.0-ONNX/resolve/main/onnx/model.onnx
wget https://github.com/nazdridoy/kokoro-tts/releases/download/v1.0.0/voices-v1.0.bin

# 2. Convert to kokoro-onnx format
cd ..
./script/convert-model models/model.onnx models/kokoro-v1.0.onnx

# 3. Run the server
./script/run
```

See [CONVERSION.md](ONNX-CONVERSION.md) for details on why conversion is needed.

## Usage

### Start the Server

```bash
./script/run
```

The server will:
- Load the model in ~0.4 seconds
- Listen on `tcp://0.0.0.0:10200`
- Support all 52 available voices
- Work on CPU or GPU (auto-detected)

### Command-line Options

```bash
./script/run --help
```

- `--uri`: Server URI (default: `tcp://0.0.0.0:10200`)
- `--model`: Path to ONNX model (default: `./models/kokoro-v1.0.onnx`)
- `--voices`: Path to voices file (default: `./models/voices-v1.0.bin`)
- `--debug`: Enable debug logging

### Test the Server

```bash
echo '{"type":"describe"}' | nc localhost 10200
```

## Home Assistant Integration

### 1. Add Wyoming Integration

In Home Assistant:
- **Settings** → **Devices & Services** → **Add Integration**
- Search for "Wyoming Protocol"
- Enter server details:
  - Host: `localhost` (or IP of server)
  - Port: `10200`

### 2. Configure Voice Assistant

- **Settings** → **Voice Assistants**
- Select your assistant
- Choose **Wyoming Kokoro** as the TTS engine
- Voice: `bm_lewis` (British Male - Lewis)

### 3. Test

Say "Hey, Home Assistant, what time is it?" and hear the response.

## Configuration

### Current Settings

- **Voice**: `bm_lewis` (British Male - Lewis)
- **Speed**: `1.2` (20% faster than normal)
- **Language**: British English
- **Sample Rate**: 22050 Hz (Wyoming standard)
- **Audio Format**: 16-bit PCM, mono

### Available Voices (52 total)

English: `af_alloy`, `af_bella`, `af_heart`, `af_jessica`, `af_nicole`, `af_nova`, `af_river`, `af_sarah`, `af_sky`, `am_adam`, `am_echo`, `am_eric`, `am_liam`, `am_michael`, `am_onyx`, `bm_lewis`, `bm_daniel`, `bm_george`, and more.

See server logs for complete list.

## Performance

### ONNX Runtime Benefits

- **Fast startup**: 0.4s model loading (6x faster than PyTorch)
- **CPU optimized**: Good performance without GPU
- **Small install**: 300MB vs 3-4GB for PyTorch
- **Flexible**: Works on Raspberry Pi, NUC, or server

### Expected Performance

| Hardware | Model Load | Synthesis |
|----------|-----------|-----------|
| Raspberry Pi 4 | 0.4s | ~1.5x realtime |
| Intel NUC (CPU) | 0.4s | ~0.8x realtime |
| NVIDIA GPU | 0.4s | ~0.2x realtime |

## Model Files

### Required Files

1. **Model file** (choose one):
   - `kokoro-v1.0.onnx` - Pre-converted (recommended)
   - `model-converted.onnx` - Converted from HuggingFace

2. **Voice file**:
   - `voices-v1.0.bin` - Voice embeddings (required)

### Model Sources

| Source | Size | Conversion Needed? |
|--------|------|--------------------|
| Nazdridoy GitHub | 311MB | ❌ No - ready to use |
| HuggingFace ONNX | 311MB | ✅ Yes - use `./script/convert-model` |

### Model Conversion

HuggingFace ONNX models need conversion to work with `kokoro-onnx`:

```bash
./script/convert-model <input.onnx> <output.onnx>
```

This renames node names:
- `input_ids` → `tokens`
- `waveform` → `audio`

See [ONNX-CONVERSION.md](ONNX-CONVERSION.md) for details.

## Troubleshooting

### espeak-ng Not Found

```bash
sudo apt-get install espeak-ng
```

### Model File Not Found

Download model files to `models/` directory:
```bash
cd models
wget https://github.com/nazdridoy/kokoro-tts/releases/download/v1.0.0/kokoro-v1.0.onnx
wget https://github.com/nazdridoy/kokoro-tts/releases/download/v1.0.0/voices-v1.0.bin
```

### "No module named 'kokoro_onnx'"

```bash
pip install -r requirements.txt
```

### Import Errors After Update

Make sure you have the correct version:
```bash
pip install kokoro-onnx==0.3.9
```

(Version 0.4.9 has bugs - avoid it)

### Slow Performance

If running on CPU and performance is slow:
- Consider using smaller sentences
- Reduce speed setting in code
- Consider GPU if available

## Architecture

```
Home Assistant
    ↓ (Wyoming Protocol)
Wyoming Server (server.py)
    ↓ (Event Handler)
Kokoro Handler (handler.py)
    ↓ (kokoro-onnx)
ONNX Runtime
    ↓ (CPU or GPU)
Audio Output (22050 Hz, 16-bit PCM)
```

## Project Structure

```
wyoming-kokoro/
├── wyoming_kokoro/
│   ├── __init__.py          # Package info
│   ├── __main__.py          # Entry point
│   ├── server.py            # Wyoming server (ONNX)
│   └── handler.py           # TTS event handler (ONNX)
├── models/
│   ├── kokoro-v1.0.onnx    # Model file (311MB)
│   └── voices-v1.0.bin     # Voice embeddings (25MB)
├── script/
│   ├── run                  # Launch script
│   └── convert-model        # Model conversion tool
├── requirements.txt         # Python dependencies
├── README.md               # This file
├── ONNX-CONVERSION.md      # Conversion guide
└── QUICK-START.md          # Quick reference
```

## Why ONNX Runtime?

### Advantages Over PyTorch

1. **Broader Hardware Support**
   - ✅ Works on CPU (Raspberry Pi, NUC, etc.)
   - ✅ Works on GPU (NVIDIA, AMD via providers)
   - ✅ No CUDA installation required

2. **Better Performance**
   - ✅ 6x faster model loading (0.4s vs 2.5s)
   - ✅ Optimized CPU inference
   - ✅ Smaller memory footprint

3. **Easier Installation**
   - ✅ 300MB install vs 3-4GB for PyTorch+CUDA
   - ✅ Fewer dependency conflicts
   - ✅ Works in restricted environments

4. **Same Quality**
   - ✅ Identical audio output
   - ✅ Same voice options
   - ✅ Same model weights

## Development

### Running from Source

```bash
python3 -m wyoming_kokoro.server --debug
```

### Testing

```bash
# Check if server is running
netstat -tuln | grep 10200

# Test synthesis
echo '{"type":"describe"}' | nc localhost 10200
```

## Migration from PyTorch Version

If you were using the PyTorch version:

```bash
# 1. Uninstall PyTorch dependencies
pip uninstall torch kokoro

# 2. Install ONNX dependencies
pip install -r requirements.txt

# 3. Download/convert model (one-time)
cd models
wget https://github.com/nazdridoy/kokoro-tts/releases/download/v1.0.0/kokoro-v1.0.onnx
wget https://github.com/nazdridoy/kokoro-tts/releases/download/v1.0.0/voices-v1.0.bin

# 4. Run (same command)
./script/run
```

**Benefits**: 3GB+ space saved, faster startup, CPU support, no CUDA needed.

## Documentation

- **README.md** (this file) - Main documentation
- **ONNX-CONVERSION.md** - Model conversion details
- **QUICK-START.md** - Quick reference guide
- **SUMMARY.md** - Implementation comparison
- **IMPLEMENTATION-COMPARISON.md** - Detailed analysis

## License

This project uses:
- **Kokoro TTS**: Apache 2.0 License
- **Wyoming Protocol**: MIT License

## Credits

- [Kokoro-82M](https://huggingface.co/hexgrad/Kokoro-82M) - Fast, high-quality TTS model
- [kokoro-onnx](https://pypi.org/project/kokoro-onnx/) - ONNX Runtime wrapper
- [Wyoming Protocol](https://github.com/rhasspy/wyoming) - Voice assistant protocol
- [Home Assistant](https://www.home-assistant.io/) - Smart home platform
- [nazdridoy](https://github.com/nazdridoy/kokoro-tts) - Pre-converted ONNX models

## Support

For issues or questions:
1. Check [TROUBLESHOOTING](ONNX-CONVERSION.md#troubleshooting) section
2. Review documentation files
3. Check server logs with `--debug` flag
