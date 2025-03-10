# APRS Decoder for Mobilinkd TNC

This repository contains tools for decoding APRS (Automatic Packet Reporting System) packets from a Mobilinkd TNC (Terminal Node Controller) on macOS. It provides both a Python implementation and a native macOS bash script implementation.

## Overview

APRS (Automatic Packet Reporting System) is a digital communications protocol used for transmitting small packets of data over amateur radio. These packets can contain GPS coordinates, weather data, short messages, and other information.

These tools allow you to:

- Connect to a Mobilinkd TNC via Bluetooth/serial port
- Decode incoming APRS packets in real-time
- Parse position information, messages, and other APRS data
- Log decoded packets to a file in various formats
- Display decoded packet information in the terminal

## Requirements

### Python Version
- Python 3.x
- pyserial library (`pip install pyserial`)

### Native macOS Version
- macOS with Bash
- No additional dependencies required

## Connecting Your Hardware

This software is designed to work with:
- Mobilinkd TNC (tested with TNC 4) connected via Bluetooth
- Any amateur radio transceiver configured for APRS (e.g., Baofeng BF-F8HP)
- APRS frequency set to your local APRS frequency (typically 144.390 MHz in North America)

## Installation

1. Clone this repository:
   ```
   git clone https://github.com/yourusername/aprs-decoder.git
   cd aprs-decoder
   ```

2. Make the scripts executable:
   ```
   chmod +x aprs_decoder.py
   chmod +x aprs-decoder-macos.sh
   ```

## Usage

### Python Version

```
python aprs_decoder.py --port /dev/tty.YourTNCSerialPort --baud 9600 --format human
```

Options:
- `--port`: Serial port for the TNC (required)
- `--baud`: Baud rate (default: 9600)
- `--output`: Output log file (default: aprs_packets.log)
- `--format`: Output format: human, csv, or json (default: human)

### Native macOS Version

```
./aprs-decoder-macos.sh --port /dev/tty.YourTNCSerialPort --baud 1200 --format human
```

Options:
- `--port`: Serial port for the TNC (required)
- `--baud`: Baud rate (default: 9600)
- `--output`: Output log file (default: aprs_packets.log)
- `--format`: Output format: human or csv (default: human)

## Finding Your TNC's Serial Port

To find the correct serial port for your Mobilinkd TNC on macOS:

```
ls /dev/tty.* | grep Mobilinkd
```

This should show something like `/dev/tty.TNC4Mobilinkd` or `/dev/tty.Mobilinkd-TNC4-xxxxx`.

## Output Formats

### Human-readable format
```
Timestamp: 2025-03-09 15:30:45
Source: K7CPR
Destination: APRS
Path: WIDE1-1,WIDE2-1
Type: Position
Position: 46.8834, -121.7211
Comment: Hello from Capitol Peak
Raw: K7CPR>APRS,WIDE1-1,WIDE2-1:!4653.00N/12143.26W#Hello from Capitol Peak
```

### CSV format
```
timestamp,source,destination,path,type,latitude,longitude,comment,raw
2025-03-09 15:30:45,K7CPR,APRS,WIDE1-1|WIDE2-1,Position,46.8834,-121.7211,Hello from Capitol Peak,K7CPR>APRS;WIDE1-1;WIDE2-1:!4653.00N/12143.26W#Hello from Capitol Peak
```

## Troubleshooting

### Resource Busy Error
If you see "Resource busy" errors when trying to access the serial port:

1. Check if another program is using the port:
   ```
   lsof | grep YourTNCSerialPort
   ```

2. Close any applications that might be using the port

3. Try disconnecting and reconnecting your TNC via Bluetooth

### No Packets Received
If you're not receiving any packets:

1. Verify your radio is on the correct APRS frequency
2. Check that your radio's squelch is set appropriately
3. Consider your location - APRS activity varies by location
4. Try moving to a location with better reception
5. Ensure your TNC is properly connected and powered

## License

This software is released under the MIT License. See the LICENSE file for details.

## Acknowledgments

- The APRS protocol was developed by Bob Bruninga (WB4APR)
- Thanks to the Mobilinkd team for their excellent TNC hardware
- This code was written by Claude (Anthropic's AI assistant)
