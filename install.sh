#!/usr/bin/env bash
set -e

# Wyoming Kokoro TTS - System Installation Script (ONNX)
# This script installs Wyoming Kokoro to /opt/wyoming-kokoro as a system service

INSTALL_DIR="/opt/wyoming-kokoro"
SERVICE_NAME="wyoming-kokoro"
PYTHON_VERSION="3.11"
MODEL_URL="https://huggingface.co/onnx-community/Kokoro-82M-v1.0-ONNX/resolve/main/onnx/model.onnx"
VOICES_URL="https://github.com/nazdridoy/kokoro-tts/releases/download/v1.0.0/voices-v1.0.bin"
MODEL_SIZE="311MB"
VOICES_SIZE="25MB"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Wyoming Kokoro TTS System Installation (ONNX) ===${NC}"
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root (use sudo)${NC}"
    exit 1
fi

# Check if Python 3.11 is available
if ! command -v python3.11 &> /dev/null; then
    echo -e "${YELLOW}Warning: Python 3.11 not found. Attempting to use python3...${NC}"
    if ! command -v python3 &> /dev/null; then
        echo -e "${RED}Error: Python 3 not found. Please install Python 3.11+${NC}"
        exit 1
    fi
    PYTHON_CMD="python3"
else
    PYTHON_CMD="python3.11"
fi

# Verify Python version
PYTHON_VER=$($PYTHON_CMD --version | cut -d' ' -f2 | cut -d'.' -f1,2)
echo "Found Python version: $PYTHON_VER"

# Check if installation directory already exists
if [ -d "$INSTALL_DIR" ]; then
    echo -e "${YELLOW}Warning: $INSTALL_DIR already exists${NC}"
    read -p "Do you want to remove it and reinstall? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Stopping service if running..."
        systemctl stop $SERVICE_NAME 2>/dev/null || true
        systemctl disable $SERVICE_NAME 2>/dev/null || true
        echo "Removing existing installation..."
        rm -rf "$INSTALL_DIR"
    else
        echo "Installation cancelled."
        exit 1
    fi
fi

echo -e "${GREEN}Step 1: Creating installation directory${NC}"
mkdir -p "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR/models"

echo -e "${GREEN}Step 2: Copying application files${NC}"
cp -r wyoming_kokoro "$INSTALL_DIR/"
cp requirements.txt "$INSTALL_DIR/"
cp -r script "$INSTALL_DIR/"

# Copy default configuration file if it exists
if [ -f "config.json" ]; then
    cp config.json "$INSTALL_DIR/"
    echo "Copied default configuration file"
fi

# Check for existing model files
echo -e "${GREEN}Step 3: Checking for model files${NC}"

MODEL_NEEDED=false
VOICES_NEEDED=false

# Check if we have a usable model in source models/ directory
if [ -f "models/kokoro-v1.0.onnx" ] || [ -f "models/model-converted.onnx" ]; then
    echo -e "${BLUE}Found existing model file in source directory${NC}"
    cp -r models "$INSTALL_DIR/"
    echo "Copied existing model files to $INSTALL_DIR/models/"
elif [ -f "models/model.onnx" ]; then
    echo -e "${BLUE}Found unconverted model.onnx in source directory${NC}"
    cp models/model.onnx "$INSTALL_DIR/models/"
    cp models/voices-v1.0.bin "$INSTALL_DIR/models/" 2>/dev/null || VOICES_NEEDED=true
    echo "Will convert model.onnx after installation"
else
    echo -e "${YELLOW}No model files found in source directory${NC}"
    MODEL_NEEDED=true
fi

# Check for voices file
if [ ! -f "$INSTALL_DIR/models/voices-v1.0.bin" ]; then
    if [ -f "models/voices-v1.0.bin" ]; then
        cp models/voices-v1.0.bin "$INSTALL_DIR/models/"
        echo "Copied voices file from source directory"
    else
        VOICES_NEEDED=true
    fi
fi

# Download model if needed
if [ "$MODEL_NEEDED" = true ]; then
    echo
    echo -e "${BLUE}=== Model Download Required ===${NC}"
    echo "The Kokoro TTS model needs to be downloaded from HuggingFace."
    echo
    echo "Download size: ${MODEL_SIZE} (model) + ${VOICES_SIZE} (voices) = ~336MB"
    echo "Source: ${MODEL_URL}"
    echo
    read -p "Do you want to download the model now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}Downloading model file (${MODEL_SIZE})...${NC}"
        if command -v wget &> /dev/null; then
            wget -O "$INSTALL_DIR/models/model.onnx" "$MODEL_URL" || {
                echo -e "${RED}Failed to download model${NC}"
                exit 1
            }
        elif command -v curl &> /dev/null; then
            curl -L -o "$INSTALL_DIR/models/model.onnx" "$MODEL_URL" || {
                echo -e "${RED}Failed to download model${NC}"
                exit 1
            }
        else
            echo -e "${RED}Error: Neither wget nor curl found. Cannot download model.${NC}"
            echo "Please install wget or curl and try again."
            exit 1
        fi
        echo -e "${GREEN}Model downloaded successfully${NC}"
    else
        echo -e "${RED}Installation cancelled. Model is required to run the service.${NC}"
        echo "You can manually download the model later:"
        echo "  wget -P $INSTALL_DIR/models $MODEL_URL"
        echo "  wget -P $INSTALL_DIR/models $VOICES_URL"
        exit 1
    fi
fi

# Download voices file if needed
if [ "$VOICES_NEEDED" = true ]; then
    echo -e "${GREEN}Downloading voices file (${VOICES_SIZE})...${NC}"
    if command -v wget &> /dev/null; then
        wget -O "$INSTALL_DIR/models/voices-v1.0.bin" "$VOICES_URL" || {
            echo -e "${RED}Failed to download voices file${NC}"
            exit 1
        }
    elif command -v curl &> /dev/null; then
        curl -L -o "$INSTALL_DIR/models/voices-v1.0.bin" "$VOICES_URL" || {
            echo -e "${RED}Failed to download voices file${NC}"
            exit 1
        }
    else
        echo -e "${RED}Error: Neither wget nor curl found. Cannot download voices.${NC}"
        exit 1
    fi
    echo -e "${GREEN}Voices file downloaded successfully${NC}"
fi

echo -e "${GREEN}Step 4: Creating Python virtual environment${NC}"
$PYTHON_CMD -m venv "$INSTALL_DIR/venv"

echo -e "${GREEN}Step 5: Upgrading pip${NC}"
"$INSTALL_DIR/venv/bin/pip" install --upgrade pip

echo -e "${GREEN}Step 6: Installing Python dependencies (ONNX Runtime)${NC}"
echo "This may take a few minutes..."
"$INSTALL_DIR/venv/bin/pip" install -r "$INSTALL_DIR/requirements.txt"

echo -e "${GREEN}Step 7: Installing system dependencies${NC}"
if command -v apt-get &> /dev/null; then
    if ! command -v espeak-ng &> /dev/null; then
        echo "Installing espeak-ng..."
        apt-get update
        apt-get install -y espeak-ng
    else
        echo "espeak-ng already installed"
    fi
else
    echo -e "${YELLOW}Warning: apt-get not found. Please ensure espeak-ng is installed manually.${NC}"
fi

# Convert model if needed
if [ -f "$INSTALL_DIR/models/model.onnx" ] && [ ! -f "$INSTALL_DIR/models/kokoro-v1.0.onnx" ]; then
    echo -e "${GREEN}Step 8: Converting model to kokoro-onnx format${NC}"
    echo "This will rename ONNX node names for compatibility..."

    # Run conversion using the virtual environment
    cd "$INSTALL_DIR"
    ./script/convert-model models/model.onnx models/kokoro-v1.0.onnx

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Model conversion successful${NC}"
        # Optionally remove the original to save space
        echo "Original model.onnx kept for reference (you can delete it to save ${MODEL_SIZE})"
    else
        echo -e "${RED}Model conversion failed${NC}"
        echo "You may need to convert manually:"
        echo "  cd $INSTALL_DIR && ./script/convert-model models/model.onnx models/kokoro-v1.0.onnx"
        exit 1
    fi
    cd - > /dev/null
else
    echo -e "${GREEN}Step 8: Model already in correct format${NC}"
fi

echo -e "${GREEN}Step 9: Setting ownership${NC}"
chown -R ubuntu:ubuntu "$INSTALL_DIR"

echo -e "${GREEN}Step 10: Installing systemd service${NC}"
if [ -f "wyoming-kokoro-system.service" ]; then
    cp wyoming-kokoro-system.service /etc/systemd/system/$SERVICE_NAME.service
elif [ -f "wyoming-kokoro.service" ]; then
    cp wyoming-kokoro.service /etc/systemd/system/$SERVICE_NAME.service
else
    echo -e "${YELLOW}Warning: No systemd service file found. Service will need to be configured manually.${NC}"
fi
systemctl daemon-reload

echo -e "${GREEN}Step 11: Enabling and starting service${NC}"
systemctl enable $SERVICE_NAME
systemctl start $SERVICE_NAME

echo
echo -e "${GREEN}=== Installation Complete ===${NC}"
echo
echo "Installation directory: $INSTALL_DIR"
echo "Service name: $SERVICE_NAME"
echo "Model format: ONNX Runtime (CPU/GPU compatible)"
echo
echo "Useful commands:"
echo "  Check status:  sudo systemctl status $SERVICE_NAME"
echo "  View logs:     sudo journalctl -u $SERVICE_NAME -f"
echo "  Restart:       sudo systemctl restart $SERVICE_NAME"
echo "  Stop:          sudo systemctl stop $SERVICE_NAME"
echo
echo "Testing connection..."
sleep 2
if systemctl is-active --quiet $SERVICE_NAME; then
    echo -e "${GREEN}✓ Service is running${NC}"
    if netstat -tuln 2>/dev/null | grep -q ":10200 "; then
        echo -e "${GREEN}✓ Server is listening on port 10200${NC}"
    else
        echo -e "${YELLOW}⚠ Service is running but port 10200 may not be open yet${NC}"
        echo "  Check logs: sudo journalctl -u $SERVICE_NAME -n 20"
    fi
else
    echo -e "${RED}✗ Service failed to start${NC}"
    echo "  Check logs: sudo journalctl -u $SERVICE_NAME -n 20"
    exit 1
fi

echo
echo -e "${GREEN}Next steps:${NC}"
echo "1. Add Wyoming integration in Home Assistant"
echo "   - Settings → Devices & Services → Add Integration"
echo "   - Search for 'Wyoming Protocol'"
echo "   - Host: localhost (or this machine's IP)"
echo "   - Port: 10200"
echo "2. Select Wyoming Kokoro as your TTS engine in Voice Assistant settings"
echo
echo -e "${BLUE}Note: This installation uses ONNX Runtime (works on CPU or GPU)${NC}"
echo "No CUDA installation required. Works on Raspberry Pi, NUC, or server."
echo
