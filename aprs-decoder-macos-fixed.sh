#!/bin/bash
# macOS Native APRS Decoder for Mobilinkd TNC
# Uses built-in macOS tools to decode APRS packets from a TNC

# Default settings
PORT=""
BAUD=9600
OUTPUT_FILE="aprs_packets.log"
FORMAT="human"

# Function to display usage
show_usage() {
  echo "Usage: $0 --port PORT [--baud BAUD] [--output FILE] [--format FORMAT]"
  echo
  echo "Options:"
  echo "  --port PORT      Serial port for the TNC (required)"
  echo "  --baud BAUD      Baud rate (default: 9600)"
  echo "  --output FILE    Output log file (default: aprs_packets.log)"
  echo "  --format FORMAT  Output format: human, csv (default: human)"
  echo
  echo "Example: $0 --port /dev/tty.Mobilinkd-TNC4-SerialPort"
  exit 1
}

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --port) PORT="$2"; shift ;;
    --baud) BAUD="$2"; shift ;;
    --output) OUTPUT_FILE="$2"; shift ;;
    --format) FORMAT="$2"; shift ;;
    --help) show_usage ;;
    *) echo "Unknown parameter: $1"; show_usage ;;
  esac
  shift
done

# Check for required arguments
if [ -z "$PORT" ]; then
  echo "Error: Serial port is required"
  show_usage
fi

# Check if port exists
if [ ! -e "$PORT" ]; then
  echo "Error: Serial port $PORT does not exist"
  echo "Available ports:"
  ls -l /dev/tty.*
  exit 1
fi

# Function to parse APRS packet
parse_packet() {
  local packet="$1"
  local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
  
  # Extract source and destination
  local source=$(echo "$packet" | sed -E 's/^([A-Z0-9-]+)\s*>.*/\1/')
  local dest=$(echo "$packet" | sed -E 's/^[A-Z0-9-]+\s*>\s*([A-Z0-9-]+).*/\1/')
  
  # Extract path
  local path=$(echo "$packet" | sed -E 's/^[A-Z0-9-]+\s*>\s*[A-Z0-9-]+\s*(,[A-Z0-9-*]+)*:.*/\1/')
  
  # Extract content
  local content=$(echo "$packet" | sed -E 's/^[A-Z0-9-]+\s*>\s*[A-Z0-9-]+(,[A-Z0-9-*]+)*:(.*)/\2/')
  
  # Determine message type
  local msg_type="Other"
  local lat=""
  local lon=""
  local comment=""
  
  # First character of content determines type
  local first_char=$(echo "$content" | cut -c1)
  
  case "$first_char" in
    "!" | "=")
      msg_type="Position"
      # Try to extract lat/lon for uncompressed format
      if echo "$content" | grep -qE '[!=][0-9]{2}[0-9]{2}\.[0-9]{2}[NS]/[0-9]{3}[0-9]{2}\.[0-9]{2}[EW]'; then
        # Extract latitude components
        local lat_deg=$(echo "$content" | sed -E 's/^[!=]([0-9]{2}).*/\1/')
        local lat_min=$(echo "$content" | sed -E 's/^[!=][0-9]{2}([0-9]{2}\.[0-9]{2}).*/\1/')
        local lat_dir=$(echo "$content" | sed -E 's/^[!=][0-9]{2}[0-9]{2}\.[0-9]{2}([NS]).*/\1/')
        
        # Extract longitude components
        local lon_deg=$(echo "$content" | sed -E 's/^[!=][0-9]{2}[0-9]{2}\.[0-9]{2}[NS]/([0-9]{3}).*/\1/')
        local lon_min=$(echo "$content" | sed -E 's/^[!=][0-9]{2}[0-9]{2}\.[0-9]{2}[NS]/[0-9]{3}([0-9]{2}\.[0-9]{2}).*/\1/')
        local lon_dir=$(echo "$content" | sed -E 's/^[!=][0-9]{2}[0-9]{2}\.[0-9]{2}[NS]/[0-9]{3}[0-9]{2}\.[0-9]{2}([EW]).*/\1/')
        
        # Convert to decimal degrees (approximate calculation)
        # For exact calculation, would need to use bc or similar
        lat_min_dec=$(echo "$lat_min" | awk '{print $1/60}')
        lat=$(echo "$lat_deg $lat_min_dec" | awk '{print $1 + $2}')
        if [ "$lat_dir" = "S" ]; then
          lat=$(echo "$lat" | awk '{print -$1}')
        fi
        
        lon_min_dec=$(echo "$lon_min" | awk '{print $1/60}')
        lon=$(echo "$lon_deg $lon_min_dec" | awk '{print $1 + $2}')
        if [ "$lon_dir" = "W" ]; then
          lon=$(echo "$lon" | awk '{print -$1}')
        fi
        
        # Extract comment (everything after the position)
        comment=$(echo "$content" | sed -E 's/^[!=][0-9]{2}[0-9]{2}\.[0-9]{2}[NS]/[0-9]{3}[0-9]{2}\.[0-9]{2}[EW](.*)/\1/')
      fi
      ;;
    ">")
      msg_type="Status"
      comment=$(echo "$content" | cut -c2-)
      ;;
    ":")
      msg_type="Message"
      comment=$(echo "$content" | cut -c2-)
      ;;
    "T")
      msg_type="Telemetry"
      comment="$content"
      ;;
    *)
      comment="$content"
      ;;
  esac
  
  # Output based on format
  if [ "$FORMAT" = "human" ]; then
    echo "Timestamp: $timestamp"
    echo "Source: $source"
    echo "Destination: $dest"
    [ ! -z "$path" ] && echo "Path: $path"
    echo "Type: $msg_type"
    [ ! -z "$lat" ] && echo "Position: $lat, $lon"
    [ ! -z "$comment" ] && echo "Comment: $comment"
    echo "Raw: $packet"
    echo ""
  elif [ "$FORMAT" = "csv" ]; then
    # Escape commas in comment and raw packet
    comment=$(echo "$comment" | sed 's/,/;/g')
    packet_esc=$(echo "$packet" | sed 's/,/;/g')
    echo "$timestamp,$source,$dest,$path,$msg_type,$lat,$lon,$comment,$packet_esc"
  fi
}

# Create CSV header if needed
if [ "$FORMAT" = "csv" ] && [ ! -s "$OUTPUT_FILE" ]; then
  echo "timestamp,source,destination,path,type,latitude,longitude,comment,raw" > "$OUTPUT_FILE"
fi

echo "Connected to $PORT at $BAUD baud"
echo "Logging to $OUTPUT_FILE"
echo "Press Ctrl+C to stop"

# Configure the serial port using stty (built into macOS)
stty -f "$PORT" $BAUD cs8 -cstopb -parenb

# Use cat to read from serial port and process line by line
# This avoids the need for timeout in read
(cat "$PORT" & CAT_PID=$!) | while IFS= read -r line; do
  if [ ! -z "$line" ]; then
    # Parse and display the packet
    parse_output=$(parse_packet "$line")
    echo "$parse_output"
    
    # Log to file
    if [ "$FORMAT" = "human" ]; then
      echo "$parse_output" >> "$OUTPUT_FILE"
    elif [ "$FORMAT" = "csv" ]; then
      # Last line only for CSV
      echo "$parse_output" | tail -n 1 >> "$OUTPUT_FILE"
    fi
  fi
done

# Trap Ctrl+C to clean up
trap 'echo -e "\nExiting..."; kill $CAT_PID 2>/dev/null; exit 0' INT TERM
