
TARGET = xmc4300-ecat-subdevice
BUILD_DIR := ./build

DEVICE = XMC4300
VARIANT = F100x256

EC_SII = sii_eeprom.bin

XMC_LIB = ./mtb-xmclib-cat3
SOES_DIR = ./SOES/soes
CMSIS_DIR = ./CMSIS_5


SRC = \
	main.c \
	objectlist.c \
	$(SOES_DIR)/ecat_slv.c \
	$(SOES_DIR)/esc.c \
	$(SOES_DIR)/esc_coe.c \
	$(SOES_DIR)/esc_eep.c \
	$(SOES_DIR)/esc_foe.c \
	$(SOES_DIR)/hal/xmc4/esc_hw.c \
	$(SOES_DIR)/hal/xmc4/esc_hw_eep.c \
	$(XMC_LIB)/XMCLib/src/xmc_gpio.c \
	$(XMC_LIB)/XMCLib/src/xmc4_gpio.c \
	$(XMC_LIB)/XMCLib/src/xmc4_scu.c \
	$(XMC_LIB)/XMCLib/src/xmc_ecat.c \
	$(XMC_LIB)/XMCLib/src/xmc4_flash.c \
	$(XMC_LIB)/XMCLib/src/xmc_fce.c \
	$(XMC_LIB)/Newlib/syscalls.c \
	$(XMC_LIB)/CMSIS/Infineon/COMPONENT_XMC4300/Source/system_XMC4300.c \

ASRC = \
	$(XMC_LIB)/CMSIS/Infineon/COMPONENT_XMC4300/Source/TOOLCHAIN_GCC_ARM/startup_XMC4300.S \

BINS = \
	$(EC_SII)\

LINKER_SCRIPT = $(XMC_LIB)/CMSIS/Infineon/COMPONENT_XMC4300/Source/TOOLCHAIN_GCC_ARM/XMC4300x256.ld

# JLink options
JLINK_SPEED = 1000
JLINK_IFACE = swd

# Define all object files.
OBJ = $(SRC:%=$(BUILD_DIR)/%.o) $(ASRC:%=$(BUILD_DIR)/%.o) $(BINS:%=$(BUILD_DIR)/%.o)

# Define all dependency files.
DEP = $(OBJ:.o=.d)

CPPFLAGS = -D$(DEVICE)_$(VARIANT)
CPPFLAGS += -MMD -MP

CPPFLAGS += -I$(XMC_LIB)/XMCLib/inc
CPPFLAGS += -I$(XMC_LIB)/CMSIS/Include
CPPFLAGS += -I$(XMC_LIB)/CMSIS/Infineon/COMPONENT_XMC4300/Include
CPPFLAGS += -I.
CPPFLAGS += -I$(SOES_DIR)
CPPFLAGS += -I$(SOES_DIR)/hal/xmc4
CPPFLAGS += -I$(SOES_DIR)/include/sys/gcc
CPPFLAGS += -I$(CMSIS_DIR)/CMSIS/Core/Include

ARCHFLAGS = -mfloat-abi=softfp -mcpu=cortex-m4 -mfpu=fpv4-sp-d16 -mthumb

OBJFLAGS = -Wall -fmessage-length=0 -Wa,-adhlns=$(@:.o=.lst) $(ARCHFLAGS)

CFLAGS = $(CPPFLAGS) $(OBJFLAGS) -Os -ffunction-sections -fdata-sections  -std=gnu99 -pipe
ASFLAGS = -x assembler-with-cpp $(CPPFLAGS) $(OBJFLAGS)

LDFLAGS = -T$(LINKER_SCRIPT) -nostartfiles -Xlinker --gc-sections
LDFLAGS += -specs=nano.specs -specs=nosys.specs
LDFLAGS += -Wl,-Map,$(BUILD_DIR)/$(TARGET).map
LDFLAGS += $(ARCHFLAGS)

# Define programs and commands.
SHELL = sh
REMOVE = rm -f
CC = arm-none-eabi-gcc
OBJCOPY = arm-none-eabi-objcopy
OBJDUMP = arm-none-eabi-objdump
SIZE = arm-none-eabi-size
ifeq ($(OS),Windows_NT)
	JLINK = JLink
else
	JLINK = JLinkExe
endif

# Define Messages
# English
MSG_SIZE = Size: 
MSG_FLASH_FILE = Creating load file for Flash:
MSG_FLASH = Programming target flash memory:
MSG_FLASH_ERASE = Erasing target flash memory:
MSG_EXTENDED_LISTING = Creating Extended Listing:
MSG_LINKING = Linking:
MSG_COMPILING = Compiling:
MSG_ASSEMBLING = Assembling:
MSG_OBJCOPY = ObjCopy:
MSG_CLEANING = Cleaning project:

# Default target.
all: $(BUILD_DIR)/$(TARGET).hex size

# Compile: create object files from C source files.
$(BUILD_DIR)/%.c.o : %.c
	@echo
	mkdir -p $(@D)
	@echo $(MSG_COMPILING) $<
	$(CC) -c $(CFLAGS) -o $@ $< 

# Assemble: create object files from assembler source files.
$(BUILD_DIR)/%.S.o : %.S
	@echo
	mkdir -p $(@D)
	@echo $(MSG_ASSEMBLING) $<
	$(CC) -c $(ASFLAGS) -o $@ $<

# ObjCopy: create object files from binary files.
$(BUILD_DIR)/%.bin.o : %.bin
	@echo
	mkdir -p $(@D)
	@echo $(MSG_OBJCOPY) $<
	$(OBJCOPY) -I binary -O elf32-littlearm -B arm $< $@

# Link: create ELF output file from object files.
$(BUILD_DIR)/$(TARGET).elf: $(OBJ)
	@echo
	@echo $(MSG_LINKING) $@
	$(CC) $(LDFLAGS) -o $@ $(OBJ) 

# Create final output file from ELF output file.
$(BUILD_DIR)/$(TARGET).hex: $(BUILD_DIR)/$(TARGET).elf
	@echo
	@echo $(MSG_FLASH_FILE) $@
	$(OBJCOPY) -O ihex $< $@

# Create extended listing file from ELF output file.
$(BUILD_DIR)/$(TARGET).lss: $(BUILD_DIR)/$(TARGET).elf
	@echo
	@echo $(MSG_EXTENDED_LISTING) $@
	$(OBJDUMP) -h -S $(BUILD_DIR)/$(TARGET).elf > $(BUILD_DIR)/$(TARGET).lss

# Display size of file.
size: $(BUILD_DIR)/$(TARGET).elf
	@echo
	@echo $(MSG_SIZE)
	$(SIZE) --format=berkeley $(BUILD_DIR)/$(TARGET).elf
	@echo

# Flash the target device.
flash: $(BUILD_DIR)/$(TARGET).hex
	@echo
	@echo $(MSG_FLASH)
	echo -e "device $(DEVICE)-$(VARIANT)\nspeed $(JLINK_SPEED)\nsi $(JLINK_IFACE)\nloadfile $(BUILD_DIR)/$(TARGET).hex\ng\nqc\n" | $(JLINK)

# Erase the target flash
erase:
	@echo
	@echo $(MSG_FLASH_ERASE)
	echo -e "device $(DEVICE)-$(VARIANT)\nspeed $(JLINK_SPEED)\nsi $(JLINK_IFACE)\nerase\nqc\n" | $(JLINK)

# Target: clean project.
clean:
	@echo
	@echo $(MSG_CLEANING)
	rm -r $(BUILD_DIR)

# Include the dependency files.
-include $(DEP)

# Listing of phony targets.
.PHONY: all clean size flash erase

