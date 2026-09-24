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

parser = argparse.ArgumentParser(description='Get static hex code from riscv binary file.')

parser.add_argument('--binfile' , '-bf', default='coremark_baremetal.bin', help='specify riscv binary file that is obtained by gcc objcopy')

args = parser.parse_args()
binFile = args.binfile

with open(binFile, "rb") as f:
	binData = f.read()
	
	maxlimit = 1000000

	assert len(binData) < 4*maxlimit
	assert len(binData) % 4 == 0

	hexFileName = binFile[:-4] + ".hex"
	hexFile = open(hexFileName, 'w')

	for i in range(maxlimit):
		if i < len(binData) // 4:
			w = binData[4*i : 4*i+4]
			hexFile.write("%02x%02x%02x%02x" % (w[0], w[1], w[2], w[3]))
			hexFile.write("\n")
	
	f.close()
	hexFile.close()
