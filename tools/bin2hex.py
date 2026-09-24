#!/usr/bin/env python3
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


import sys

with open(sys.argv[1], "rb") as f:
    cnt = 3
    s = ["00"]*4
    while True:
        data = f.read(1)
        if not data:
            print(''.join(s))
            exit(0)
        s[cnt] = "{:02X}".format(data[0])
        if cnt == 0:
            print(''.join(s))
            s = ["00"]*4
            cnt = 4
        cnt -= 1

#import sys
#
#with open(sys.argv[1], "rb") as f:
#    binData = f.read()
#
#maxlimit = 1000000
#
#assert len(binData) < 4 * maxlimit
#
#for i in range(maxlimit):
#    if i < len(binData) // 4:
#        w = binData[4 * i : 4 * i + 4]
#        print("%02x%02x%02x%02x" % (w[3], w[2], w[1], w[0]))
