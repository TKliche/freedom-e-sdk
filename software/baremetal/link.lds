OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY
{
	ram (rwx) : ORIGIN = 0x08000000, LENGTH = 8K
}

SECTIONS
{
	.init : {
		. = ALIGN(8);
		*(.init)
	} > ram

	.text : {
		. = ALIGN(8);
		*(.text)
	} > ram

	.rodata : {
		. = ALIGN(8);
		*(.rodata)
	} > ram

	. = ALIGN(8);
	PROVIDE( _fbss = . );
	.bss : {
		*(.bss)
		. = ALIGN(8);
	} > ram
	PROVIDE( _ebss = . );

	.data : {
		. = ALIGN(8);
		*(.data)

		. = ALIGN(8);
		. += 1024;
		_stack = .;
	} > ram
}
