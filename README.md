# GeoNet Earthquake Monitor

A Bash script that monitors New Zealand earthquakes using the GeoNet API and sends notifications via ntfy.

## Features

- Monitors earthquakes in New Zealand based on MMI (Modified Mercalli Intensity) level.
- Sends notifications via ntfy with customizable priority.
- Prevents duplicate notifications.
- Sorts earthquakes chronologically (oldest to newest).
- Includes error checking and dependency validation.

## Prerequisites

The script requires the following dependencies:
- curl
- jq

## Installation

1. Download the script:
```bash
sudo curl -o '/usr/local/bin/geonet-earthquake-monitor' 'https://raw.githubusercontent.com/clove3am/geonet-earthquake-monitor/main/geonet-earthquake-monitor.sh'
```

3. Make it executable:
```bash
chmod +x '/usr/local/bin/geonet-earthquake-monitor'
```

3. Set up the required environment variables:
```bash
# Add these to your ~/.bashrc or equivalent
export NTFY_TOKEN_DEVICES="your-ntfy-token"
export NTFY_GEONET_URL="https://ntfy.sh/your-topic"
```

## Usage

```bash
geonet-earthquake-monitor -m MMI -p PRIORITY
```

### Required Arguments

- `-m, --mmi`: Minimum MMI intensity (0-8)
- `-p, --priority`: Notification priority (1-5)

### Optional Arguments

- `-h, --help`: Show help message
- `-v, --version`: Show version information

### Examples

Monitor earthquakes with MMI ≥ 4 with high priority notifications:
```bash
geonet-earthquake-monitor -m 4 -p 4
```

Monitor all earthquakes with low priority notifications:
```bash
geonet-earthquake-monitor -m 0 -p 1
```

## Automated Monitoring

### Using Cron

To run the script every 5 minutes using cron:

1. Edit your crontab:
```bash
crontab -e
```

2. Add the following line:
```bash
HOME=/home/your-use-name
NTFY_TOKEN_DEVICES=your-token-here
NTFY_GEONET_URL=https://ntfy.sh/your-topic
*/5 * * * * /usr/local/bin/geonet-earthquake-monitor -m 4 -p 4
```

### Using Systemd

1. Create a service file:
```bash
cat <<'EOF' | sudo tee '/etc/systemd/system/geonet-earthquake-monitor.service' >/dev/null
[Unit]
Description=GeoNet Earthquake Monitor
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/geonet-earthquake-monitor -m 4 -p 4
__HOME__
Environment=NTFY_TOKEN_DEVICES=your-token-here
Environment=NTFY_GEONET_URL=https://ntfy.sh/your-topic
Restart=always
RestartSec=60

[Install]
WantedBy=multi-user.target
EOF
sudo sed -i "s|__HOME__|Environment=HOME=$(echo ${HOME})|" '/etc/systemd/system/geonet-earthquake-monitor.service'
```

2. Create a timer file:
```bash
cat <<'EOF' | sudo tee '/etc/systemd/system/geonet-earthquake-monitor.timer' >/dev/null
[Unit]
Description=Run GeoNet Earthquake Monitor every 5 minutes

[Timer]
OnBootSec=1min
OnUnitActiveSec=5min
Unit=geonet-earthquake-monitor.service

[Install]
WantedBy=timers.target
EOF
```

3. Enable and start the timer:
```bash
sudo systemctl enable --now geonet-earthquake-monitor.timer
```

4. Check status:
```bash
sudo systemctl status geonet-earthquake-monitor.timer
sudo systemctl list-timers --all
```

## Environment Variables

| Variable | Description |
|----------|-------------|
| `NTFY_TOKEN_DEVICES` | Authentication token for [ntfy](https://docs.ntfy.sh/) |
| `NTFY_GEONET_URL` | The ntfy URL to publish to *(e.g., `https://ntfy.sh/earthquakes`)* |

## Notification Format

Notifications include:
- **Title:** Magnitude and location *(e.g., "4.9M earthquake 15 km east of Picton")*
- **Body:** Depth and time *(e.g., "Depth: 35km at Mon Nov 4 2024 15:58")*
- **Click action:** Links to the GeoNet earthquake page

## Cache File

The script maintains a cache of sent notifications at:
```
~/.local/state/geonet-earthquake-monitor/notified.cache
```

## GeoNet API

The script uses the [GeoNet API](https://api.geonet.org.nz/#quakes) endpoint:
```
https://api.geonet.org.nz/quake?MMI=[level]
```

**API Features:**

- Returns earthquakes from the last 365 days
- Maximum of 100 earthquakes per response
- MMI values range from -1 to 8

## Contributing

Contributions to improve the script are welcome! Please feel free to submit issues or pull requests on the project's repository.

## License

This script is released under the MIT License. See the [LICENSE](LICENSE) file for details.
