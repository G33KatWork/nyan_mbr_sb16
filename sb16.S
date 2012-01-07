.code16
.section .text
.global _start

.set SB_IOBASE,   0x220

.set SB_MIX_ADDR, (SB_IOBASE + 0x04)
.set SB_MIX_DATA, (SB_IOBASE + 0x05)
.set SB_RESET,    (SB_IOBASE + 0x06)
.set SB_READ,     (SB_IOBASE + 0x0A)
.set SB_WRITE,    (SB_IOBASE + 0x0C)
.set SB_POLL,     (SB_IOBASE + 0x0E)

.set SB_CMD_VERSION,    0xE1
.set SB_CMD_SPKR_ON,    0xD1
.set SB_CMD_SPKR_OFF,   0xD3

.set SB_CMD_PCM8_MONO_AUTO_OUTPUT, 0x1C
.set SB_CMD_SET_TIME_CONST, 0x40

.set SB_MIXCHAN_MASTER, 0x22
.set SB_MIX_IRQSET,     0x80
.set SB_MIX_DMASELECT,  0x81
.set SB_MIX_IRQSTATUS,  0x82

.set SB_IRQ5, (1<<1)
.set SB_DMA1, (1<<1)
.set SB_IRQ8BITACTIVE, (1<<0)

#registers for dma channel 1
.set DMA_ADDR,          0x2
.set DMA_COUNT,         0x3
.set DMA_PAGE,          0x83

#DMA regs for channels < 4
.set DMA_MASK,          0x0A
.set DMA_CLEAR,         0x0C
.set DMA_MODE,          0x0B


#Length of Audio data in bytes
.set AUDIO_SECTORCOUNT, 423
.set AUDIO_LEN, 216294

_start:
    call load_nyan_noises
    call load_nyan_display

    #assert dsp reset
    mov $SB_RESET, %dx
    mov $0x1, %al
    outb %al, %dx

    #deassert dsp reset
    mov $0x0, %al
    outb %al, %dx

    #wait for dsp to become ready
.check_ready:
    mov $SB_POLL, %dx
    inb %dx, %al
    and $0x80, %al
    cmp $0x80, %al
    jz .check_ready2
    jmp .check_ready

.check_ready2:
    mov $SB_READ, %dx
    inb %dx, %al
    cmp $0xAA, %al
    jz .reset_success
    jmp .check_ready2

.reset_success:
    #install irq 5 handler (vector 0x72)
    xor %ax, %ax
    mov %ax, %es
    cli
    mov $0x34, %di
    movw $irqHandler, %es:(%di)
    add $2, %di
    movw $0x0, %es:(%di)
    sti
    
    
    #configure DMA engine (channel 1, 8 bit)
    #see http://wiki.osdev.org/ISA_DMA for more information
    cli
    
    #mask channel for configuration
    movb $0x5, %al
    movw $DMA_MASK, %dx
    outb %al, %dx
    
    #clear word flip flop
    movb $0x0, %al
    movw $DMA_CLEAR, %dx
    outb %al, %dx
    
    #set DMA mode
    #Channel 1, Peripheral reads, Auto, Addresses up, Transfer on Demand
    movb $0x19, %al
    movw $DMA_MODE, %dx
    outb %al, %dx
    
    #copy first full buffer into dma region
    push %ds
    mov $0x1000, %ax
    mov %ax, %es
    mov $0x2000, %ax
    mov %ax, %ds
    xor %si, %si
    xor %di, %di
    mov $32768, %cx
    rep movsw
    pop %ds
    
    
    #set buffer location
    #buffer is at 0x10000
    movw $DMA_ADDR, %dx
    xorb %al, %al           #lower 8 bit
    outb %al, %dx
    outb %al, %dx           #upper 8 bit
    movw $DMA_PAGE, %dx
    movb $0x1, %al          #page = 1
    outb %al, %dx
    
    #set buffer length to 64K-1
    movw $DMA_COUNT, %dx
    movb $0xFF, %al           #lower 8 bit
    outb %al, %dx
    movb $0xFF, %al           #upper 8 bit
    outb %al, %dx
    
    #init finished, unmask the channel
    movb $0x1, %al
    movw $DMA_MASK, %dx
    outb %al, %dx
    
    sti
    
    #configure soundblaster DSP
    #set irq5 in soundblaster
    movw $SB_MIX_ADDR, %dx
    movb $SB_MIX_IRQSET, %al
    outb %al, %dx
    movw $SB_MIX_DATA, %dx
    movb $SB_IRQ5, %al
    outb %al, %dx
    
    #unmask irq 5 in master PIC
    movw $0x21, %dx
    inb %dx, %al
    andb $0xDF, %al
    outb %al, %dx
    
    
    #main screen^W speaker turn on
    movw $SB_WRITE, %dx
    movb $SB_CMD_SPKR_ON, %al
    outb %al, %dx
    call dsp_wait
    
    #set sample rate
    movw $SB_WRITE, %dx
    movb $0x41, %al
    outb %al, %dx
    call dsp_wait
    movb $0x1F, %al #8000Hz high byte
    outb %al, %dx
    call dsp_wait
    movb $0x40, %al #8000Hz low byte
    outb %al, %dx
    call dsp_wait
    
    movb $0xC6, %al
    outb %al, %dx
    call dsp_wait
    
    movb $0x00, %al
    outb %al, %dx
    call dsp_wait
    
    #set buffer size to 32K. After that an interrupt will be triggered
    #we fill the upper buffer and lower buffer half alternating,
    #so that we have double buffering. sounds nicer :)
    mov $0xFF, %al  #low byte
    outb %al, %dx
    call dsp_wait
    mov $0x7F, %al  #high byte
    outb %al, %dx
    call dsp_wait
    
    #Sound is playing
    #Run Forest, Run!
    call nyanVideoStart
.hang:
    jmp .hang


#wait for dsp to become ready
dsp_wait:
    pushw %ax
    pushw %dx
    movw $SB_WRITE, %dx
    inb %dx, %al
.testagain:
    andb $0x80, %al
    cmpb $0x80, %al
    jz .testagain
.ready:
    popw %dx
    popw %ax
    ret

#ask our buddy the BIOS to print some fancy stuff on the screen
bios_print:
    pop %si
    lodsb
    push %si
    or %al, %al
    jz .done
    mov $0x0E, %ah
    int $0x10
    jmp bios_print
.done:
    ret


load_nyan_display:
    movw $0x4200, %ax
    movw $_bios_lba_packet_display, %si
    int $0x13
    
    jc .readerror
    ret

load_nyan_noises:
    call bios_print
    .ascii "NYAN!\n\0"
    
    movw $0x4200, %ax
    movw $_bios_lba_packet, %si
    int $0x13
    
    jc .readerror
    ret
.readerror:
    call bios_print
    .ascii "Read error!\n\0"
.readhang:
    jmp .readhang

_bios_lba_packet:
    .byte 16            #size of the packet (16 Bytes)
    .byte 0             #always 0
    .word 423           #transfer 423 sectors
    .word 0x0000        #destination offset (0x0)
    .word 0x2000        #destination segment (0x2000)
    .word 2             #read from sector 2
    .word 0
    .word 0,0

_bios_lba_packet_display:
    .byte 16            #size of the packet (16 Bytes)
    .byte 0             #always 0
    .word 1             #transfer 423 sectors
    .word 0x7E00        #destination offset (0x0)
    .word 0x0000        #destination segment (0x2000)
    .word 1             #read from sector 2
    .word 0
    .word 0,0






#some variables for the interrupt handler to keep the state
nextBufferFillLocation: .word 0x0000
nextReadStartOffset: .word 0x0000
nextReadStartSegment: .word 0x3000

irqHandler:
    cli
    pusha
    
    push %ds
    #copy the next meowing block to the DMA buffer
    #setup destination
    movw $0x1000, %ax
    movw %ax, %es
    movw (nextBufferFillLocation), %di
    
    #setup source
    movw (nextReadStartOffset), %si
    movw (nextReadStartSegment), %ax
    movw %ax, %ds
    
    #set count
    mov $0x4000, %cx
    #copy
    rep movsw
    
    pop %ds
    
    #save next buffer fill (overflows automatically to the beginning)
    mov %di, (nextBufferFillLocation)
    
    #save source offset
    movw %si, (nextReadStartOffset)
    
    #did it overflow?
    test %si, %si
    jne .noNextSourceSegment
    #if yes, got to next segment
    add $0x1000, %ax
    
    cmp $0x5000, %ax
    jne .noNewBeginning
    mov $0x2000, %ax
    
.noNewBeginning:
    mov %ax, (nextReadStartSegment)
    
.noNextSourceSegment:
    
    #ACK 8Bit interrupt
    movw $SB_POLL, %dx
    inb %dx, %al
    
    #EOI master PIC
    movw $0x20, %dx  #master pic command register
    movb $0x20, %al  #EOI
    outb %al, %dx
    
    popa
    sti
    
    iret

.org 510
    .byte 0x55, 0xAA

nyanVideoStart:
.include "nyan.S"

