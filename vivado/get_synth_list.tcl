set outfile [lindex $argv 0]
if {$outfile eq ""} {
    set outfile soc_list.f
}
set project [lindex $argv 1]
if {$project eq ""} {
    set project vivado/cva_soc_zc706/cva_soc_zc706.xpr
}
open_project [file normalize $project]
update_compile_order -fileset sources_1
set fp [open $outfile w]
foreach dir [get_property include_dirs [get_filesets sources_1]] {
    puts $fp "+incdir+$dir"
}
foreach f [get_files -compile_order sources -used_in synthesis] {
    if {[get_property file_type [get_files $f]] eq "Verilog Header"} {
        continue
    }
    puts $fp $f
}
close $fp
close_project
