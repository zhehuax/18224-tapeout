TOPLEVEL_LANG = verilog
VERILOG_SOURCES = $(shell pwd)/top.sv input_16.sv output_16.sv fpu_16bit.sv
TOPLEVEL = top
MODULE = testbench
SIM = verilator
EXTRA_ARGS += --trace --trace-structs -Wno-fatal
include $(shell cocotb-config --makefiles)/Makefile.sim
