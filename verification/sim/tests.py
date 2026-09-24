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

from pathlib import Path
import os

SCRIPT_DIR = Path(os.path.realpath(__file__)).parent.absolute()

coremark = {
    "coremark": {
        "TEST_FILE": f"{SCRIPT_DIR}/../../tests/coremark/coremark_baremetal.hex",
        "fail_adr": 0x40F00060,
        "pass_adr": 0x40F00078,
        "instructions": [],
    }
}
