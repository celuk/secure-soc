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

.PHONY: all
all: 
	@echo "What are you expecting? (￣ー￣)";
	@echo "Read the makefile.";

.PHONY: air
air:
	@export XILINX_VIVADO=/tools/Xilinx/Vivado/2022.2; \
	python3 ./main.py --sim xcelium --test tb_air --top  secure_soc --waves true --cfile=$(CFILE)

.PHONY: air_icarus
air_icarus:
	python3 ./main.py --sim icarus --test tb_air --top  secure_soc --waves true --cfile=$(CFILE)

.PHONY: air_program
air_program:
	@export XILINX_VIVADO=/tools/Xilinx/Vivado/2022.2; \
	python3 ./main.py --sim xcelium --test tb_air_program --top  secure_soc --waves true --cfile=$(CFILE)

.PHONY: clean
clean:
	@echo "Cleaning sim outputs";
	-rm -rf ./sim_build ./__pycache__/
