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

import argparse

def process_vmem_file(input_file, place_zero):
    with open(input_file, 'r') as file:
        lines = file.readlines()

    filtered_lines = []
    previous_address = None
    previous_data_length = 0

    for line in lines:
        if line.startswith('@'):
            current_address = int(line[1:], 16)
            if previous_address is not None and place_zero:
                gap = current_address - (previous_address + previous_data_length)
                if gap > 0:
                    zero_bytes = '00 ' * gap
                    filtered_lines.append(zero_bytes.strip() + '\n')
            previous_address = current_address
            previous_data_length = 0
        else:
            filtered_lines.append(line)
            previous_data_length += len(line.split())

    # Add @00000000 at the top
    filtered_lines.insert(0, '@00000000\n')

    for line in filtered_lines:
        print(line, end='')

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Process a vmem file.')
    parser.add_argument('--file', '-f', type=str, help='The input vmem file')
    parser.add_argument('--place_zero', '-pz', action='store_true', help='Place zero bytes for gaps between addresses')

    args = parser.parse_args()
    process_vmem_file(args.file, args.place_zero)
