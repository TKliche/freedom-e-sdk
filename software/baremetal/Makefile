CFLAGS += -nostartfiles -nostdlib -fno-builtin -g -mcmodel=medany -I$(BSP_BASE)/include -I$(BSP_BASE)/env/$(BOARD)

baremetal: main.c entry.S lock.s hartid.s link.lds
	$(CC) $(CFLAGS) -o $@ $(filter-out %.lds,$^) -T link.lds

clean:
	rm -f baremetal
