# This file is part of https://github.com/celuk/secure-soc
# Copyright (C) 2025  Seyyid Hikmet Celik
#                     seyyid4091@gmail.com
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

import serial
import argparse

parser = argparse.ArgumentParser(description="Send sram reset over UART")
parser.add_argument("--port", '-p', type=str, default="/dev/ttyUSB1", required=False, help="Serial port to use")
parser.add_argument("--baud_rate", '-b', type=int, default=115200, help="Baud rate to use")
parser.add_argument("--program_sequence", '-ps', type=str, default="RESETTTTT", help="Program sequence to send")
args = parser.parse_args()
port = args.port
baud_rate = args.baud_rate
program_sequence = args.program_sequence

ser = serial.Serial(port, baud_rate)
ser.timeout = 1

ser.write(program_sequence.encode('utf-8'))
print(program_sequence)
