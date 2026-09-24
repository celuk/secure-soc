// This file is part of https://github.com/celuk/secure-soc
// Copyright (C) 2025  Seyyid Hikmet Celik
//                     seyyid4091@gmail.com
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
// 
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

int main()
{
    unsigned int address = 0x80000000;
    unsigned int offset = 0x12345128;
    unsigned int value = 0xDEADBEEF;
    //unsigned int address = 0x80000000;
    //unsigned int offset = 0x2F456234;
    //unsigned int value = 0xABCD1234;
    *((volatile unsigned int*)(address + offset)) = value;
    
    return 0;
}
