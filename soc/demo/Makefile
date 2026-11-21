TARGET?=digilent_arty_s7

ifeq ($(TARGET),digilent_arty_s7)
	BUILD_DIR?=../build/digilent_arty_s7
else ifeq ($(TARGET),digilent_cmod_s7)
	BUILD_DIR?=../build/digilent_cmod_s7
else
	$(error Unknown TARGET $(TARGET))
endif

include $(BUILD_DIR)/software/include/generated/variables.mak
include $(SOC_DIRECTORY)/software/common.mak
HELIX_DIR = helix_mp3

CFLAGS += -I$(HELIX_DIR)/src \
          -I$(HELIX_DIR)/src/libhelix \
          -I$(HELIX_DIR)/src/libhelix/pub \
          -I$(HELIX_DIR)/src/libhelix/real

HELIX_DIR = helix_mp3

CFLAGS += -I$(HELIX_DIR)/src \
          -I$(HELIX_DIR)/src/libhelix \
          -I$(HELIX_DIR)/src/libhelix/pub \
          -I$(HELIX_DIR)/src/libhelix/real

HELIX_SRCS = $(HELIX_DIR)/src/helix_mp3.c \
             $(HELIX_DIR)/src/libhelix/mp3dec.c \
             $(HELIX_DIR)/src/libhelix/mp3tabs.c \
             $(HELIX_DIR)/src/libhelix/real/bitstream.c \
             $(HELIX_DIR)/src/libhelix/real/buffers.c \
             $(HELIX_DIR)/src/libhelix/real/dct32.c \
             $(HELIX_DIR)/src/libhelix/real/dequant.c \
             $(HELIX_DIR)/src/libhelix/real/dqchan.c \
             $(HELIX_DIR)/src/libhelix/real/huffman.c \
             $(HELIX_DIR)/src/libhelix/real/hufftabs.c \
             $(HELIX_DIR)/src/libhelix/real/imdct.c \
             $(HELIX_DIR)/src/libhelix/real/polyphase.c \
             $(HELIX_DIR)/src/libhelix/real/scalfact.c \
             $(HELIX_DIR)/src/libhelix/real/stproc.c \
             $(HELIX_DIR)/src/libhelix/real/subband.c \
             $(HELIX_DIR)/src/libhelix/real/trigtabs.c

HELIX_OBJS = $(HELIX_SRCS:.c=.o)

OBJECTS = donut.o helloc.o crt0.o main.o sine_test.o decode_audio_stream.o $(HELIX_OBJS)

ifdef WITH_CXX
	OBJECTS += hellocpp.o
	CFLAGS += -DWITH_CXX
endif

COMMA = ,
REGULAR_LIBS = $(filter-out $(ALWAYS_LINK_LIBS),$(LIBS))
ALWAYS_LINK_LIBFLAGS = $(if $(ALWAYS_LINK_LIBS),-Wl$(COMMA)--whole-archive $(ALWAYS_LINK_LIBS:lib%=-l%) -Wl$(COMMA)--no-whole-archive)

all: demo.bin


%.bin: %.elf
	$(OBJCOPY) -O binary $< $@
ifneq ($(OS),Windows_NT)
	chmod -x $@
endif

vpath %.a $(PACKAGES:%=../%)

demo.elf: $(OBJECTS)
	$(CC) $(LDFLAGS) -T linker.ld -N -o $@ \
		$(OBJECTS) \
		$(PACKAGES:%=-L$(BUILD_DIR)/software/%) \
		-Wl,--start-group \
		$(REGULAR_LIBS:lib%=-l%) \
		$(ALWAYS_LINK_LIBFLAGS) \
		-Wl,--end-group \
		-Wl,--gc-sections \
		-Wl,-Map,$@.map

ifneq ($(OS),Windows_NT)
	chmod -x $@
endif


# pull in dependency info for *existing* .o files
-include $(OBJECTS:.o=.d)

donut.o: CFLAGS   += -w

VPATH = $(BIOS_DIRECTORY):$(BIOS_DIRECTORY)/cmds:$(CPU_DIRECTORY):$(HELIX_DIR)/src:$(HELIX_DIR)/src/libhelix:$(HELIX_DIR)/src/libhelix/real

%.o: %.cpp
	$(compilexx)

%.o: %.c
	$(compile)

%.o: %.S
	$(assemble)

clean:
	$(RM) $(OBJECTS) demo.elf demo.bin .*~ *~

.PHONY: all clean
