# FROM ghcr.io/astral-sh/uv:python3.12-alpine
FROM astral/uv:python3.12-bookworm-slim

# Get git
RUN apt-get update && apt-get install -y --no-install-recommends \
  git \
  wget

# Clone the repo
RUN git clone https://github.com/hxii/wyoming-kokoro /app

WORKDIR /app

# COPY requirements.txt .
# COPY config.json .
# COPY wyoming_kokoro/ .

# Create venv and install requirements
RUN uv venv && uv pip install -r requirements.txt

# Get the models
# RUN mkdir models && \
#   wget https://github.com/nazdridoy/kokoro-tts/releases/download/v1.0.0/kokoro-v1.0.onnx -o models/kokoro-v1.0.onnx && \
#   wget https://github.com/nazdridoy/kokoro-tts/releases/download/v1.0.0/voices-v1.0.bin -o models/voices-v1.0.bin

COPY models/kokoro-v1.0.onnx /app/models/
COPY models/voices-v1.0.bin /app/models/

EXPOSE 10200

CMD ["uv", "run", "python", "-m", "wyoming_kokoro.server", "--model", "./models/kokoro-v1.0.onnx", "--voices", "./models/voices-v1.0.bin", "$@"]

