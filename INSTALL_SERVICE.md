# Installing Wyoming Kokoro as a System Service

This guide shows how to set up Wyoming Kokoro TTS to start automatically at boot.

## Installation Steps

### 1. Copy the service file to systemd

```bash
sudo cp wyoming-kokoro.service /etc/systemd/system/
```

### 2. Reload systemd to recognize the new service

```bash
sudo systemctl daemon-reload
```

### 3. Enable the service to start at boot

```bash
sudo systemctl enable wyoming-kokoro
```

### 4. Start the service now

```bash
sudo systemctl start wyoming-kokoro
```

## Managing the Service

### Check service status
```bash
sudo systemctl status wyoming-kokoro
```

### View logs
```bash
sudo journalctl -u wyoming-kokoro -f
```

### Stop the service
```bash
sudo systemctl stop wyoming-kokoro
```

### Restart the service
```bash
sudo systemctl restart wyoming-kokoro
```

### Disable auto-start at boot
```bash
sudo systemctl disable wyoming-kokoro
```

## Troubleshooting

### Service won't start

Check the logs:
```bash
sudo journalctl -u wyoming-kokoro -n 50
```

### Check if port is in use
```bash
sudo netstat -tuln | grep 10200
```

### Verify conda environment
```bash
/home/ubuntu/miniconda3/envs/wyoming-kokoro/bin/python --version
```

### Test manually first
Before installing as a service, always test manually:
```bash
cd /home/ubuntu/work/wyoming-kokoro
conda activate wyoming-kokoro
./script/run
```

## Updating the Service

If you modify the service file:

1. Copy the updated file:
   ```bash
   sudo cp wyoming-kokoro.service /etc/systemd/system/
   ```

2. Reload systemd:
   ```bash
   sudo systemctl daemon-reload
   ```

3. Restart the service:
   ```bash
   sudo systemctl restart wyoming-kokoro
   ```

## Uninstalling

To completely remove the service:

```bash
# Stop and disable the service
sudo systemctl stop wyoming-kokoro
sudo systemctl disable wyoming-kokoro

# Remove the service file
sudo rm /etc/systemd/system/wyoming-kokoro.service

# Reload systemd
sudo systemctl daemon-reload
```
