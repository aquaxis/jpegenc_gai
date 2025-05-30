# Makefile for RTL Simulation with Vivado xsim

# Vivado settings
VIVADO_DIR = /tools/Xilinx/Vivado/2024.2
XSIM = $(VIVADO_DIR)/bin/xvlog
XELAB = $(VIVADO_DIR)/bin/xelab
XSIM_RUN = $(VIVADO_DIR)/bin/xsim

# Source and simulation settings
SRC_DIR = ../rtl
TB_TOP = tb_jpeg_encoder
TOP_MODULE = jpeg_encoder_top
TIMESCALE = 1ns/1ns
SIM_TIME = 10us
WAVE_FILE = sim.wdb

# Source files
VERILOG_SRC = $(wildcard $(SRC_DIR)/*.v)
SV_SRC = $(wildcard $(SRC_DIR)/*.sv)
ALL_SRC = $(VERILOG_SRC) $(SV_SRC)

# Include directory
INC_DIR = $(SRC_DIR)

# Output simulation files
SNAPSHOT = $(TB_TOP)_snapshot

# Default target
all: compile elaborate simulate

# Compile sources
compile:
	$(XSIM) -sv -i $(INC_DIR) $(ALL_SRC)

# Elaborate
elaborate:
	$(XELAB) $(TB_TOP) -s $(SNAPSHOT) -timescale $(TIMESCALE)

# Simulate with waveform dump
simulate:
	cp ../image/sample.bmp ./
	$(XSIM_RUN) $(SNAPSHOT) -R

# Clean generated files
clean:
	rm -rf xsim.dir *.log *.pb *.wdb *.jou *.jpg *.bmp

.PHONY: all compile elaborate simulate clean