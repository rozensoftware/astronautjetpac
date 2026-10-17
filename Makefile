ifeq ($(OS),Windows_NT)
SHELL := bash.exe
else
SHELL := /bin/bash
endif
.SHELLFLAGS := -eu -o pipefail -c

ROOT := $(CURDIR)
BUILD_DIR := $(ROOT)/build
HASC_ROOT ?= $(ROOT)/../highamigaassembler
LIB_DIR := $(if $(wildcard $(ROOT)/lib),$(ROOT)/lib,$(HASC_ROOT)/lib)

CPU ?= 68000
HASC_PYTHON ?= $(if $(wildcard $(ROOT)/.venv/bin/python),$(ROOT)/.venv/bin/python,$(if $(wildcard $(ROOT)/venv/bin/python),$(ROOT)/venv/bin/python,python3))
HASC_PYTHONPATH := $(if $(wildcard $(HASC_ROOT)/hasc),$(HASC_ROOT))
HASC_COMMAND := $(if $(HASC_PYTHONPATH),PYTHONPATH="$(HASC_PYTHONPATH)") $(HASC_PYTHON) -m hasc.cli
HASC_IMPORT := $(if $(HASC_PYTHONPATH),PYTHONPATH="$(HASC_PYTHONPATH)") $(HASC_PYTHON) -c 'import hasc.cli'
VASM ?= vasmm68k_mot
VLINK ?= vlink
VBCC_CC ?= vbccm68k
VBCC_ROOT ?=
VBCC_INCLUDE := $(if $(VBCC_ROOT),$(VBCC_ROOT)/targets/m68k-amigaos/include)
VBCC_OPT_FLAGS := -O=131

MODULES := jetpac frontpage
EXES := $(addprefix $(BUILD_DIR)/,$(addsuffix .exe,$(MODULES)))
ASSET_SOURCES := $(sort $(wildcard assets/*.s))
ASSET_OBJECTS := $(patsubst assets/%.s,$(BUILD_DIR)/%.o,$(ASSET_SOURCES))
FRONTPAGE_ASSET_OBJECTS := $(filter-out $(BUILD_DIR)/move_letters.o,$(ASSET_OBJECTS))
STAR_OBJECT := $(BUILD_DIR)/star.o

LIBRARY_NAMES := helpers cpu timer takeover wbstartup graphics input keyboard sprite gui gui_keyboard str heap math bob textbob fileio debug ptplayer
LIBRARY_SOURCES := $(addprefix $(LIB_DIR)/,$(addsuffix .s,$(LIBRARY_NAMES)))
LIBRARY_OBJECTS := $(patsubst $(LIB_DIR)/%.s,$(BUILD_DIR)/%.o,$(LIBRARY_SOURCES))
JETPAC_LIBRARIES := helpers cpu timer takeover wbstartup graphics input keyboard sprite gui gui_keyboard heap bob textbob fileio debug ptplayer
FRONTPAGE_LIBRARIES := helpers takeover graphics input keyboard sprite
JETPAC_OBJECTS := $(addprefix $(BUILD_DIR)/,$(addsuffix .o,$(JETPAC_LIBRARIES)))
FRONTPAGE_OBJECTS := $(addprefix $(BUILD_DIR)/,$(addsuffix .o,$(FRONTPAGE_LIBRARIES)))
LIBS ?= $(LIBRARY_NAMES)
GAME_LIBRARY_OBJECTS := $(addprefix $(BUILD_DIR)/,$(addsuffix .o,$(LIBS)))

GFX_SPACE_CODE ?= 0
GFX_SPACE_GLYPH ?= 0
HEAP_MEMORY ?= 141308
COMMON_DEFINES := -D GFX_SPACE_CODE=$(GFX_SPACE_CODE) -D GFX_SPACE_GLYPH=$(GFX_SPACE_GLYPH) -D HEAP_MEMORY=$(HEAP_MEMORY)
VASM_FLAGS := -m$(CPU) -quiet -Fhunk -kick1hunks -I $(LIB_DIR) -D DISABLE_DUALPF=1 $(COMMON_DEFINES)
VBCC_VASM_FLAGS := -m$(CPU) -quiet -Fhunk -kick1hunks -nowarn=62 -I $(LIB_DIR) $(COMMON_DEFINES)

.DEFAULT_GOAL := all
.PHONY: all clean rebuild help list-modules game build-68020 $(MODULES) check-tools

all: $(EXES)

build-68020:
	$(MAKE) CPU=68020 BUILD_DIR="$(ROOT)/build-68020" all

$(MODULES): %: $(BUILD_DIR)/%.exe

$(BUILD_DIR):
	mkdir -p "$@"

check-tools:
	@command -v "$(HASC_PYTHON)" >/dev/null || { echo "ERROR: Python not found; set HASC_PYTHON." >&2; exit 1; }
	@$(HASC_IMPORT) || { echo "ERROR: hasc not found; set HASC_ROOT or install it for HASC_PYTHON." >&2; exit 1; }
	@$(if $(HASC_PYTHONPATH),PYTHONPATH="$(HASC_PYTHONPATH)") $(HASC_PYTHON) -c 'import lark' || { echo "ERROR: Missing Python dependency 'lark' for hasc." >&2; echo "Run: $(HASC_PYTHON) -m pip install lark" >&2; exit 1; }
	@command -v "$(VASM)" >/dev/null || { echo "ERROR: assembler not found; set VASM." >&2; exit 1; }
	@command -v "$(VLINK)" >/dev/null || { echo "ERROR: linker not found; set VLINK." >&2; exit 1; }
	@command -v "$(VBCC_CC)" >/dev/null || { echo "ERROR: vbccm68k not found; set VBCC_CC." >&2; exit 1; }

# HAS modules reference asset labels directly, so all generated asset objects are linked.
$(BUILD_DIR)/jetpac.exe: jetpac.has $(ASSET_OBJECTS) $(JETPAC_OBJECTS) $(STAR_OBJECT) | $(BUILD_DIR) check-tools
	@echo "=== Build: $< ($(CPU)) ==="
	$(HASC_COMMAND) "$<" --cpu "$(CPU)" -o "$(BUILD_DIR)/jetpac.s"
	$(VASM) $(VASM_FLAGS) -D DISABLE_640x256=1 -D DISABLE_HAM=1 "$(BUILD_DIR)/jetpac.s" -o "$(BUILD_DIR)/jetpac.o"
	$(VLINK) -bamigahunk -Bstatic "$(BUILD_DIR)/jetpac.o" $(JETPAC_OBJECTS) $(ASSET_OBJECTS) $(STAR_OBJECT) -o "$@"

$(BUILD_DIR)/frontpage.exe: frontpage.has $(FRONTPAGE_ASSET_OBJECTS) $(FRONTPAGE_OBJECTS) $(STAR_OBJECT) | $(BUILD_DIR) check-tools
	@echo "=== Build: $< ($(CPU)) ==="
	$(HASC_COMMAND) "$<" --cpu "$(CPU)" -o "$(BUILD_DIR)/frontpage.s"
	$(VASM) $(VASM_FLAGS) -D DISABLE_640x256=1 "$(BUILD_DIR)/frontpage.s" -o "$(BUILD_DIR)/frontpage.o"
	$(VLINK) -bamigahunk -Bstatic "$(BUILD_DIR)/frontpage.o" $(FRONTPAGE_OBJECTS) $(FRONTPAGE_ASSET_OBJECTS) $(STAR_OBJECT) -o "$@"

$(BUILD_DIR)/%.o: assets/%.s | $(BUILD_DIR) check-tools
	$(VASM) $(VASM_FLAGS) "$<" -o "$@"

$(BUILD_DIR)/%.o: $(LIB_DIR)/%.s | $(BUILD_DIR) check-tools
	$(VASM) $(VASM_FLAGS) "$<" -o "$@"

$(BUILD_DIR)/star_c.s: star.c | $(BUILD_DIR) check-tools
	$(VBCC_CC) -cpu=$(CPU) -quiet $(VBCC_OPT_FLAGS) -o="$@" $(if $(wildcard $(VBCC_INCLUDE)),-I=$(VBCC_INCLUDE)) "$<"

$(STAR_OBJECT): $(BUILD_DIR)/star_c.s | $(BUILD_DIR) check-tools
	$(VASM) $(VBCC_VASM_FLAGS) "$<" -o "$@"

# Build a one-off HAS module: make game SOURCE=path/to/file.has [OUT=name]
game: check-tools | $(BUILD_DIR)
	@test -n "$(SOURCE)" || { echo "Usage: make game SOURCE=path/to/file.has [OUT=name]" >&2; exit 2; }
	@name="$(if $(OUT),$(OUT),$(basename $(notdir $(SOURCE))))"; \
	$(HASC_COMMAND) "$(SOURCE)" --cpu "$(CPU)" -o "$(BUILD_DIR)/$$name.s"; \
	$(VASM) $(VASM_FLAGS) "$(BUILD_DIR)/$$name.s" -o "$(BUILD_DIR)/$$name.o"; \
	$(VLINK) -bamigahunk -Bstatic "$(BUILD_DIR)/$$name.o" $(GAME_LIBRARY_OBJECTS) $(ASSET_OBJECTS) $(STAR_OBJECT) -o "$(BUILD_DIR)/$$name.exe"

clean:
	rm -rf "$(BUILD_DIR)"

rebuild: clean all

list-modules:
	@printf '%s\n' $(MODULES)

help:
	@echo "Targets: all, jetpac, frontpage, build-68020, game, clean, rebuild, list-modules"
	@echo "Overrides: CPU=68000 (default)|68020 HEAP_MEMORY=141308 HASC_PYTHON=... HASC_ROOT=... VASM=... VLINK=... VBCC_CC=... LIBS='graphics input'"
