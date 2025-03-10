#!/usr/bin/env python3
"""
APRS Packet Decoder for Mobilinkd TNC 4
Connects to the TNC via serial/Bluetooth and decodes incoming APRS packets
"""

import serial
import time
import datetime
import re
import argparse
import os

class APRSPacket:
    """Class to represent and parse an APRS packet"""
    
    def __init__(self, raw_packet):
        self.raw = raw_packet
        self.source = ""
        self.destination = ""
        self.path = []
        self.message_type = ""
        self.latitude = None
        self.longitude = None
        self.comment = ""
        self.timestamp = datetime.datetime.now()
        
        # Parse the packet
        self.parse()
    
    def parse(self):
        """Parse the raw packet into components"""
        try:
            # Basic pattern for source, destination, and content
            parts = re.search(r'([A-Z0-9-]+)\s*>\s*([A-Z0-9-]+)((?:,[A-Z0-9-*]+)*):(.*)', self.raw)
            
            if parts:
                self.source = parts.group(1)
                self.destination = parts.group(2)
                
                # Parse path
                if parts.group(3):
                    self.path = parts.group(3)[1:].split(',')  # Remove leading comma
                
                # Get content
                content = parts.group(4).strip()
                
                # Determine message type
                if content.startswith('!') or content.startswith('='):
                    self.message_type = "Position"
                    self._parse_position(content)
                elif content.startswith('>'):
                    self.message_type = "Status"
                    self.comment = content[1:].strip()
                elif content.startswith(':'):
                    self.message_type = "Message"
                    self.comment = content[1:].strip()
                elif content.startswith('T'):
                    self.message_type = "Telemetry"
                    self.comment = content.strip()
                else:
                    self.message_type = "Other"
                    self.comment = content.strip()
        except Exception as e:
            print(f"Error parsing packet: {e}")
    
    def _parse_position(self, content):
        """Parse position information from content"""
        try:
            # Position formats can vary, this handles common formats
            # Look for latitude/longitude patterns
            # Basic pattern for uncompressed format: !DDMM.hhN/DDDMM.hhW
            pos_match = re.search(r'[!=](\d{2})(\d{2}\.\d{2})([NS])/(\d{3})(\d{2}\.\d{2})([EW])', content)
            
            if pos_match:
                lat_deg = int(pos_match.group(1))
                lat_min = float(pos_match.group(2))
                lat_dir = pos_match.group(3)
                
                lon_deg = int(pos_match.group(4))
                lon_min = float(pos_match.group(5))
                lon_dir = pos_match.group(6)
                
                # Convert to decimal degrees
                self.latitude = lat_deg + lat_min/60
                if lat_dir == 'S':
                    self.latitude = -self.latitude
                
                self.longitude = lon_deg + lon_min/60
                if lon_dir == 'W':
                    self.longitude = -self.longitude
                
                # Extract comment - everything after the position
                after_pos = re.search(r'[NS]/\d{3}\d{2}\.\d{2}[EW](.*)', content)
                if after_pos:
                    self.comment = after_pos.group(1).strip()
        except Exception as e:
            print(f"Error parsing position: {e}")
    
    def __str__(self):
        """Return a string representation of the packet"""
        result = []
        result.append(f"Timestamp: {self.timestamp.strftime('%Y-%m-%d %H:%M:%S')}")
        result.append(f"Source: {self.source}")
        result.append(f"Destination: {self.destination}")
        
        if self.path:
            result.append(f"Path: {','.join(self.path)}")
        
        result.append(f"Type: {self.message_type}")
        
        if self.latitude is not None and self.longitude is not None:
            result.append(f"Position: {self.latitude:.6f}, {self.longitude:.6f}")
        
        if self.comment:
            result.append(f"Comment: {self.comment}")
            
        result.append(f"Raw: {self.raw}")
        
        return "\n".join(result)


def main():
    parser = argparse.ArgumentParser(description='APRS Packet Decoder for Mobilinkd TNC')
    parser.add_argument('--port', type=str, required=True, help='Serial port for the TNC')
    parser.add_argument('--baud', type=int, default=9600, help='Baud rate (default: 9600)')
    parser.add_argument('--output', type=str, default='aprs_packets.log', help='Output log file')
    parser.add_argument('--format', choices=['human', 'csv', 'json'], default='human', 
                        help='Output format (default: human)')
    
    args = parser.parse_args()
    
    # Set up logging
    log_file = open(args.output, 'a')
    
    # Write CSV header if needed and file is new
    if args.format == 'csv' and os.path.getsize(args.output) == 0:
        log_file.write("timestamp,source,destination,path,type,latitude,longitude,comment,raw\n")
    
    # Open serial connection
    try:
        ser = serial.Serial(args.port, args.baud, timeout=1)
        print(f"Connected to {args.port} at {args.baud} baud")
        print(f"Logging to {args.output}")
        print("Press Ctrl+C to stop")
        
        # Buffer for incomplete packets
        buffer = ""
        
        while True:
            try:
                if ser.in_waiting > 0:
                    # Read data
                    data = ser.read(ser.in_waiting).decode('utf-8', errors='replace')
                    buffer += data
                    
                    # Process complete lines
                    if '\n' in buffer:
                        lines = buffer.split('\n')
                        # Keep the last incomplete line in the buffer
                        buffer = lines.pop()
                        
                        for line in lines:
                            line = line.strip()
                            if line:
                                # Process valid packet
                                packet = APRSPacket(line)
                                
                                # Output to console
                                print("\n" + str(packet) + "\n")
                                
                                # Log to file based on format
                                if args.format == 'human':
                                    log_file.write(str(packet) + "\n\n")
                                elif args.format == 'csv':
                                    # Create CSV line
                                    csv_line = [
                                        packet.timestamp.strftime('%Y-%m-%d %H:%M:%S'),
                                        packet.source,
                                        packet.destination,
                                        "|".join(packet.path),
                                        packet.message_type,
                                        str(packet.latitude) if packet.latitude else "",
                                        str(packet.longitude) if packet.longitude else "",
                                        packet.comment.replace(',', ';'),  # Escape commas
                                        packet.raw.replace(',', ';')  # Escape commas
                                    ]
                                    log_file.write(",".join(csv_line) + "\n")
                                elif args.format == 'json':
                                    import json
                                    json_data = {
                                        "timestamp": packet.timestamp.strftime('%Y-%m-%d %H:%M:%S'),
                                        "source": packet.source,
                                        "destination": packet.destination,
                                        "path": packet.path,
                                        "type": packet.message_type,
                                        "latitude": packet.latitude,
                                        "longitude": packet.longitude,
                                        "comment": packet.comment,
                                        "raw": packet.raw
                                    }
                                    log_file.write(json.dumps(json_data) + "\n")
                                
                                # Flush to ensure data is written
                                log_file.flush()
                
                # Short sleep to prevent high CPU usage
                time.sleep(0.01)
                
            except KeyboardInterrupt:
                print("\nExiting...")
                break
            except Exception as e:
                print(f"Error: {e}")
                time.sleep(1)  # Pause on error
    
    except serial.SerialException as e:
        print(f"Error opening serial port: {e}")
    finally:
        if 'ser' in locals() and ser.is_open:
            ser.close()
        log_file.close()
        print("Connection closed")


if __name__ == "__main__":
    main()
