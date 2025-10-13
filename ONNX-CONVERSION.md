# Converting HuggingFace ONNX Models for kokoro-onnx

## The Problem

HuggingFace's ONNX Community exports Kokoro models with input/output names that don't match what the `kokoro-onnx` Python library expects:

| HuggingFace ONNX | kokoro-onnx Library |
|------------------|---------------------|
| `input_ids` | `tokens` |
| `waveform` | `audio` |
| `style` | `style` ✓ |
| `speed` | `speed` ✓ |

## The Solution

Use the provided conversion script to rename the inputs/outputs:

```bash
./script/convert-onnx-for-kokoro <input.onnx> <output.onnx>
```

## Examples

### Convert full precision model
```bash
./script/convert-onnx-for-kokoro \
    models/model.onnx \
    models/model-converted.onnx
```

### Convert quantized model (if segfault issues are resolved)
```bash
./script/convert-onnx-for-kokoro \
    models/model_q8f16.onnx \
    models/model_q8f16-converted.onnx
```

### Use with symlink for easy switching
```bash
# After conversion, create symlink
ln -sf model-converted.onnx models/kokoro-v1.0.onnx

# Run the server
./script/run-onnx
```

## How It Works

The script uses `sor4onnx` to rename ONNX model nodes:

1. **Step 1**: Renames input `input_ids` → `tokens`
2. **Step 2**: Renames output `waveform` → `audio`

This makes any HuggingFace Kokoro ONNX model compatible with the `kokoro-onnx` Python library.

## Why Two Different Formats?

- **HuggingFace ONNX**: Uses standard ONNX naming conventions (`input_ids`, `waveform`)
- **Nazdridoy's model**: Custom export specifically for the `kokoro-onnx` library (`tokens`, `audio`)

Both formats are functionally identical, just with different node names.

## Alternative: Use Pre-Converted Models

Instead of converting yourself, you can download pre-converted models:

```bash
# Nazdridoy's pre-converted model
wget https://github.com/nazdridoy/kokoro-tts/releases/download/v1.0.0/kokoro-v1.0.onnx
```

## Troubleshooting

### "unrecognized arguments" error
Make sure `sor4onnx` and `onnx-graphsurgeon` are installed:
```bash
pip install sor4onnx onnx-graphsurgeon
```

### Segmentation fault with quantized models
Currently, quantized models (`model_q8f16.onnx`, `model_q4.onnx`) cause segfaults with ONNX Runtime 1.23. Use the full precision `model.onnx` instead.

### Model already has correct names
If you downloaded from nazdridoy or already converted, no conversion is needed!
