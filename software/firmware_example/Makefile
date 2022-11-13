# SHELL := /bin/bash
include Makefile.sys

FIRMWARE_OBJS 	= $(addprefix obj/, $(MAIN_OBJS) $(SYSTEM_OBJS) $(IRQ_OBJS) \
					$(NETIF_OBJS) ${ASM_OBJS})

OBJ_DIR		  	= obj

RAM_SIZE 		= 131072 #128*1024
# BLOCK_RAM_SIZE = 131072 # 4096

INCLUDES		= -I./src \
					-I./src/netif

firmware: obj/firmware.bin
	python3 python_script/makehex.py $< $(RAM_SIZE) > hex/$(addsuffix .hex,$@)
	python3 python_script/makebin.py $< $(RAM_SIZE) hex/$(addsuffix .bin,$@)
	cp hex/firmware.hex /home/lijunnan/share/firmware.hex
	cp hex/firmware.bin /home/lijunnan/share/firmware.bin
	cp hex/firmware.hex ../iCore_Controller/firmware.hex

obj/firmware.bin: obj/firmware.elf obj/firmware.elf.S
	$(TOOLCHAIN_PREFIX)objcopy -O binary $< $@;
	wc -c obj/firmware.bin
	size obj/firmware.elf
	chmod -x $@

obj/firmware.elf.S: obj/firmware.elf
	$(TOOLCHAIN_PREFIX)objdump $< -s -d > $@

obj/firmware.elf: ${FIRMWARE_OBJS} link/link.ld
	$(TOOLCHAIN_PREFIX)gcc $(CCFLAGS) -Os -ffreestanding -nostdlib -o $@ \
		-Wl,-Bstatic,-T,link/link.ld,-Map,hex/firmware.map,--strip-debug \
		${FIRMWARE_OBJS} -lgcc
	chmod -x $@

obj/%.o: src/asm/%.S
	$(TOOLCHAIN_PREFIX)gcc -c $(CCFLAGS) -o $@ $<

obj/${SYSTEM_OBJS}: ${SYSTEM_SRC}
	$(TOOLCHAIN_PREFIX)gcc -c $(CCFLAGS) $(INCLUDES) -Os --std=c99 $(GCC_WARNS) -o $@ $<

obj/${IRQ_OBJS}: ${IRQ_SRC}
	$(TOOLCHAIN_PREFIX)gcc -c $(CCFLAGS) $(INCLUDES) -Os --std=c99 $(GCC_WARNS) -o $@ $<

obj/${NETIF_OBJS}: ${NETIF_SRC}
	$(TOOLCHAIN_PREFIX)gcc -c $(CCFLAGS) $(INCLUDES) -Os --std=c99 $(GCC_WARNS) -o $@ $<

obj/$(MAIN_OBJS): src/main.c
	$(TOOLCHAIN_PREFIX)gcc -c $(CCFLAGS) $(INCLUDES) -Os --std=c99 $(GCC_WARNS) -o $@ $<

clean:
	rm -f  hex/* obj/*
