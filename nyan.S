push %cs
pop %ds
cld

mov $20, %cx
mov $starlist, %bx
0:
rdtsc
xor %ax, %si
rol $17, %si
mov %si, (%bx)

add $4, %bx
loop 0b

# 320x200x256
mov $0x13, %ax
int $0x10

push $0xa000
pop %es

push $4 # hor
push $0 # phase

mov $(320*2), %bp
nyan:
# paint background
xor %di, %di
mov $126, %ax
xor %cx, %cx
dec %cx
rep stosb

push $(64*320)
pop %di

mov $5, %cl
rainbow:
push %di
add %bp, %di
neg %bp
call gradient
pop %di
add $24, %di
loop rainbow

add %bp, %di

push $data
pop %si

#
# sammish
#

call xslantedrect
call xslantedrect
call xslantedrect

pop %ax
pop %dx
test $1, %ax
jz hop
neg %bp
not %dx
hop:
neg %bp
inc %ax
push %dx
push %ax
sub %dx, %di
xor %dx, %dx

#
# catface
#

call xslantedrect
call xslantedrect

mov $5, %cl
0:
call xsquares
loop 0b

#
# feet
#

add $(320*16-76), %di
call foot
add $20, %di
call foot
add $36, %di
call foot
add $24, %di
call foot

mov $20, %cx
mov $starlist, %bx
starloop:
mov (%bx), %di
pop %ax
push %ax
shl $4, %ax
sub %ax, %di
xor %ax, %ax
cmp $(320*(200-16)), %di
ja oob
add $(320*8), %di
mov $stars, %si
push %bx
call xsquares
pop %bx
oob:
add $4, %bx
loop starloop

xor %ax, %ax
# cx=0
xor %dx, %dx
mov $2, %cl
mov $0x86, %ah
int $0x15
jmp nyan

xsquares:
xor %bx, %bx
lodsb
xchg %ax, %bx
lodsb
0:
xchg %ax, %dx
lodsw
xchg %ax, %dx
cmp $1, %dx
je 1f
add %dx, %di
mov %bx, %dx
call rect
jmp 0b
1:
ret

rect:
push %cx
0:
push %di
mov %bx, %cx
rep stosb
pop %di
addw $320, %di
dec %dx
jne 0b
pop %cx
ret

gradient:
push %cx
mov $5, %cx
push $40
pop %ax
0:
push $24
pop %bx
push $12
pop %dx
call rect
add $4, %ax
loop 0b
pop %cx
ret

xslantedrect:
lodsw
add %ax, %di
xor %ax, %ax
lodsb
xchg %ax, %cx
lodsb
xchg %ax, %bx
lodsb
xchg %ax, %dx
lodsb
0:
push %di
push %dx
call rect
pop %dx
pop %di
sub $8, %dl
add $8, %bl
add $(320*4-4), %di
loop 0b
ret

foot:
push %di
push %si
call xslantedrect
call xslantedrect
pop %si
pop %di
ret

data:
.short -4*320
.byte 3,72,72,0

.short -320*8+12
.byte 2,72,64,89

.short -320*4+16
.byte 3,56,56,60

.short 320*12+56
.byte 4,40,40,0

.short -320*12+16
.byte 3,40,32,25

.byte 16,25
.short -320*24+4, -320*16+40, 1

.byte 8,0
.short -28+320*4, -320*8+28, 1

.byte 4,15
.short -320*8-28, -320*4+28, 1

.byte 8,65
.short 320*4-36, -320*8+44, 1

.byte 4,0
.short -320*24-48, -320*8, -320*8, -320*8, -320*8+4, -320*4+4, 4, 0, -320*4+28, -320*8, -320*8+4,-320*4+4,4,0,0,0, -36+320*16,0,-320*4+4,-320*4+4,-320*4+4,-320*4+4,-320*4+4,-320*4+4,-320*8,-320*4-12,-320*12+4,  1

#feet
.short 0
.byte 2,8,12,0

.short -320*4+8
.byte 1,8,4,25

stars:

.byte 4,15
.short -320*8-4, -320*4+8, 320*4, -320*4-8, -320*8+4, 1

starlist:

