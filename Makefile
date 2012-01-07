SHELL=/bin/bash

TARGETS=sb16.mbr sb16.img
OBJS=$(patsubst %.img, %.o, $(TARGETS))

all: $(TARGETS)

%.o: %.S
	as -o $@ $<

%.img: %.mbr
	dd if=/dev/zero of=$@_temp count=1024 bs=1
	dd if=$< of=$@_temp conv=notrunc
	cat $@_temp nyan_raw_filled.raw > $@
	rm $@_temp

%.mbr: %.o
	ld --oformat binary -Ttext 0x7c00 -o $@ $< 

clean:
	-rm -f $(TARGETS) $(OBJS)
