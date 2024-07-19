%include '../includes/io.inc'
%include '../includes/gfx.inc'
%include '../includes/util.inc'

%define WIDTH  1280
%define HEIGHT 720
%define BUTTON_SIZE 32

%define WHITE 			0xFFFFFF
%define	PRIMARY_COLOR 	0x4D5561
%define SECONDARY_COLOR 0x36414B

%define	IMG_OFFSET	dword [img_header + 10]
%define	IMG_WIDTH	dword [img_header + 18]
%define	IMG_HEIGHT	dword [img_header + 22]
%define	IMG_BPPX	 word [img_header + 28]
%define IMG_COMPR	dword [img_header + 30]
%define	IMG_COLORS	dword [img_header + 46]

global main

section .text
main:
	call	getpath

	xor		ebx, ebx 		; file mode: read
	call	fio_open

	test 	eax, eax 		; can't open file
	jz 		.fileerror

	mov 	ebx, img_header
	mov 	ecx, 54

	call	fio_read

	cmp		IMG_WIDTH, WIDTH - 64
	jg 		.sizeerror

	cmp		IMG_HEIGHT, HEIGHT
	jg 		.sizeerror

	cmp 	IMG_BPPX, 8
	jne 	.nopalette
	call 	readpalette
	.nopalette:

	xor		ebx, ebx	; 0 meaning from the beginning of the file
	mov 	ecx, IMG_OFFSET
	call	fio_seek	; jump to the beginning of pixel grid

	cmp  	IMG_COMPR, 0
	jne		.compressed
	
	call	loadimg
	jmp		.close
	
	.compressed:
	cmp 	IMG_BPPX, 8
	je 		.rle8
	jmp		.rle24

	.rle8:
	call	load8rle
	jmp		.close

	.rle24:
	call	load24rle

	.close:
	call	fio_close

    mov		eax, WIDTH
	mov		ebx, HEIGHT
	xor		ecx, ecx		; window mode (NOT fullscreen!)
	mov		edx, caption
	call	gfx_init

	test	eax, eax
	jz		.error

	call 	clearcanvas

	call	drawbar
	
	call	eventlistener
	
	jmp 	.end

	.fileerror:
	mov		eax, fileerrormsg
	call	io_writestr
	call	io_writeln
	jmp		.end

	.sizeerror:
	mov		eax, sizeerrormsg
	call	io_writestr
	call	io_writeln
	jmp		.end

	.error:
	mov		eax, errormsg
	call	io_writestr
	call	io_writeln

	.end:	
	call	gfx_destroy
    ret

; file handle in eax
loadimg:
	push	eax
	push	ebx
	push	ecx
	push 	edx
	push	esi

	mov 	ebx, eax 	; save file handle

	mov 	ecx, IMG_WIDTH
	xor 	eax, eax
	mov 	ax, IMG_BPPX
	imul 	ecx, eax
	add		ecx, 31
	shr		ecx, 5
	shl		ecx, 2

	mov 	edx, IMG_WIDTH
	imul	edx, IMG_HEIGHT
	shl		edx, 2
	mov 	eax, edx
	call	mem_alloc

	mov 	[img], eax

	xchg 	eax, ebx

	add 	ebx, edx

	mov 	edx, IMG_WIDTH
	shl		edx, 2
	sub 	ebx, edx

	xor		esi, esi
	.loop:
	call	fio_read
	cmp 	IMG_BPPX, 24
	je 		.fix24
	cmp 	IMG_BPPX, 8
	je 		.fix8
	jmp 	.32

	.fix24:
	call 	fix24
	jmp .32

	.fix8:
	call 	fix8
	jmp 	.32

	.32:
	mov 	edx, IMG_WIDTH
	shl		edx, 2
	sub		ebx, edx

	inc  	esi
	
	cmp		esi, IMG_HEIGHT
	jl		.loop

	mov 	IMG_COLORS, 0

	pop 	esi
	pop  	edx
	pop  	ecx
	pop  	ebx
	pop  	eax
	ret

load8rle:
	push	eax
	push	ebx
	push	ecx
	push 	edx
	push	esi
	push	edi

	mov 	edi, eax 	; save file handle

	mov 	edx, IMG_WIDTH
	imul	edx, IMG_HEIGHT
	shl		edx, 2
	mov 	eax, edx
	call	mem_alloc

	mov 	[img], eax

	xchg	edi, eax

	add 	edi, edx
	mov 	edx, IMG_WIDTH
	shl		edx, 2
	sub		edi, edx

	xor 	esi, esi
	.loopy:
		push	edi
		.loopx:
		mov 	ecx, 1

		mov 	ebx, cntrle
		call	fio_read

		mov 	ebx, prevrle
		call	fio_read

		mov 	dl, [cntrle]
		
		test 	dl, dl
		jz 		.skip

		mov 	cl, [prevrle]

			xor 	edx, edx
			.loop2:
			mov 	[edi], cl
			inc 	edi
			inc 	dl

			cmp 	dl, [cntrle]
			jl		.loop2

		jmp		.loopx
	.skip:
	pop 	edi
	inc 	esi
	;sub		edi, edx

	mov 	ebx, edi
	call	fix8

	mov 	edx, IMG_WIDTH
	shl		edx, 2
	sub		edi, edx

	cmp 	esi, IMG_HEIGHT
	jl		.loopy
	

	pop 	edi
	pop 	esi
	pop  	edx
	pop  	ecx
	pop  	ebx
	pop  	eax
ret

load24rle:
	push	eax
	push	ebx
	push	ecx
	push 	edx
	push	esi
	push	edi

	mov 	edi, eax 	; save file handle

	mov 	edx, IMG_WIDTH
	imul	edx, IMG_HEIGHT
	shl		edx, 2
	mov 	eax, edx
	call	mem_alloc

	mov 	[img], eax

	xchg	edi, eax

	; BLUE
	mov 	edi, [img]
	mov		edx, IMG_HEIGHT
	dec 	edx
	imul 	edx, IMG_WIDTH
	shl		edx, 2
	add 	edi, edx

	xor 	esi, esi
	.loopyblue:
		push	edi
		.loopxblue:
		mov 	ecx, 1

		mov 	ebx, cntrle
		call	fio_read

		mov 	ebx, prevrle
		call	fio_read

		mov 	dl, [cntrle]
		
		test 	dl, dl
		jz 		.skipblue

		mov 	cl, [prevrle]

			xor 	edx, edx
			.loop2blue:
			mov 	[edi], cl
			add 	edi, 4
			inc 	dl

			cmp 	dl, [cntrle]
			jl		.loop2blue

		jmp		.loopxblue
	.skipblue:
	pop 	edi
	inc 	esi

	mov 	edx, IMG_WIDTH
	shl		edx, 2
	sub		edi, edx

	cmp 	esi, IMG_HEIGHT
	jl		.loopyblue

	; GREEN
	mov 	edi, [img]
	mov		edx, IMG_HEIGHT
	dec 	edx
	imul 	edx, IMG_WIDTH
	shl		edx, 2
	add 	edi, edx
	inc 	edi

	xor 	esi, esi
	.loopygreen:
		push	edi
		.loopxgreen:
		mov 	ecx, 1

		mov 	ebx, cntrle
		call	fio_read

		mov 	ebx, prevrle
		call	fio_read

		mov 	dl, [cntrle]
		
		test 	dl, dl
		jz 		.skipgreen

		mov 	cl, [prevrle]

			xor 	edx, edx
			.loop2green:
			mov 	[edi], cl
			add 	edi, 4
			inc 	dl

			cmp 	dl, [cntrle]
			jl		.loop2green

		jmp		.loopxgreen
	.skipgreen:
	pop 	edi
	inc 	esi

	mov 	edx, IMG_WIDTH
	shl		edx, 2
	sub		edi, edx

	cmp 	esi, IMG_HEIGHT
	jl		.loopygreen



	; RED
	mov 	edi, [img]
	mov		edx, IMG_HEIGHT
	dec 	edx
	imul 	edx, IMG_WIDTH
	shl		edx, 2
	add 	edi, edx
	add 	edi, 2

	xor 	esi, esi
	.loopyred:
		push	edi
		.loopxred:
		mov 	ecx, 1

		mov 	ebx, cntrle
		call	fio_read

		mov 	ebx, prevrle
		call	fio_read

		mov 	dl, [cntrle]
		
		test 	dl, dl
		jz 		.skipred

		mov 	cl, [prevrle]

			xor 	edx, edx
			.loop2red:
			mov 	[edi], cl
			add 	edi, 4
			inc 	dl

			cmp 	dl, [cntrle]
			jl		.loop2red

		jmp		.loopxred
	.skipred:
	pop 	edi
	inc 	esi

	mov 	edx, IMG_WIDTH
	shl		edx, 2
	sub		edi, edx

	cmp 	esi, IMG_HEIGHT
	jl		.loopyred

	pop 	edi
	pop 	esi
	pop  	edx
	pop  	ecx
	pop  	ebx
	pop  	eax
ret

readpalette:
	push	ecx
	push	ebx

	mov 	ebx, palette
	mov 	ecx, IMG_COLORS
	test 	ecx, ecx
	jnz 	.colors
	mov 	ecx, 256
	.colors: 
	imul	ecx, 4
	call	fio_read

	pop 	ebx
	pop  	ecx
ret

fix24:
	push 	eax
	push 	ecx
	push	esi
	push 	edi

	mov 	esi, ebx
	mov		eax, IMG_WIDTH
	imul	eax, 3
	add 	esi, eax

	mov 	edi, ebx
	add 	eax, IMG_WIDTH
	add		edi, eax
	
	mov		ecx, IMG_WIDTH
	.loop:
	dec 	ecx

	sub		esi, 3
	sub		edi, 4

	mov 	[edi + 3], byte 0 

	mov 	al, [esi + 2]
	mov 	[edi + 2], al

	mov 	al, [esi + 1]
	mov 	[edi + 1], al

	mov 	al, [esi]
	mov 	[edi], al

	cmp 	ecx, 0
	jg		.loop


	pop 	edi
	pop  	esi
	pop 	ecx
	pop 	eax
ret

fix8:
	push 	eax
	push 	ecx
	push	esi
	push 	edi

	mov 	esi, ebx
	add		esi, IMG_WIDTH

	mov 	edi, ebx
	mov		eax, IMG_WIDTH
	shl  	eax, 2
	add		edi, eax
	
	mov		ecx, IMG_WIDTH
	.loop:
	dec 	ecx

	dec 	esi
	sub		edi, 4

	xor 	eax, eax
	mov 	al, [esi]
	imul	eax, 4
	mov 	eax, [palette + eax]
	mov 	[edi], eax

	cmp 	ecx, 0
	jg 		.loop

	pop 	edi
	pop  	esi
	pop 	ecx
	pop 	eax
ret

getpath:
	call	getargs
	add		eax, 2
	.loop:
	inc 	eax
	cmp		byte [eax-2], '"'
	jne 	.loop
	.end:
	ret

clearcanvas:
	push	eax
	push	ebx
	push	ecx
	push	edx
	push	esi
	push	edi

	call	gfx_map

	mov 	edi, eax
	mov 	esi, [img]

	xor		ecx, ecx
	.yloop:
	add		edi, 256 		; don't overwrite the toolbar

	cmp		ecx, HEIGHT
	jge		.end
	

	xor		edx, edx
	.xloop:
	cmp		edx, WIDTH - 64
	jge		.xend
	
	cmp		edx, IMG_WIDTH
	jge		.background

	cmp		ecx, IMG_HEIGHT
	jge		.background

	.image:	
	mov 	eax, [esi]
	add 	esi, 4
	jmp		.inc

	.background:
	mov 	eax, SECONDARY_COLOR
	
	.inc:
	mov 	[edi], eax
	add		edi, 4

	inc		edx
	jmp		.xloop
	
	.xend:
	inc		ecx
	jmp		.yloop
	
	.end:
	call	gfx_unmap
	call	gfx_draw

	pop 	edi
	pop 	esi
	pop		edx
	pop		ecx
	pop		ebx
	pop		eax
	ret

drawbar:
	push	eax
	push	ebx
	push 	ecx
	push	edx
	push 	esi

	call	gfx_map
	mov 	ebx, PRIMARY_COLOR
	
	xor		ecx, ecx
	.baryloop:
	cmp		ecx, HEIGHT
	jge		.baryend	
	
	xor		edx, edx
	.barxloop:
	cmp		edx, 64
	jge		.barxend

	mov 	[eax], ebx

	add		eax, 4
	
	inc		edx
	jmp		.barxloop
	
	.barxend:
	inc		ecx
	add		eax, WIDTH * 4 - 64 * 4

	jmp		.baryloop
	
	.baryend:
	call	gfx_map

	;check if any button is selected
	xor 	ecx, ecx
	mov 	cl, [selected]
	cmp		cl, 0
	je 		.buttons

	;draw square under selected button
	dec 	ecx
	mov 	esi, button_selected
	imul	ecx, WIDTH * 4 * 48
	add		ecx, WIDTH * 4 * 16 + BUTTON_SIZE * 2 - 4
	add		eax, ecx

	mov 	ebx, SECONDARY_COLOR
	call	drawbutton
	
	sub 	eax, ecx

	;draw every single button
	.buttons:
	mov 	ebx, WHITE
	add		eax, WIDTH * 4 * 16 + BUTTON_SIZE * 2 - 4
	mov 	esi, button_crop
	call 	drawbutton

	add		eax, WIDTH * 4 * 48
	mov 	esi, button_resize
	call 	drawbutton

	add		eax, WIDTH * 4 * 48
	mov 	esi, button_blur
	call 	drawbutton

	add		eax, WIDTH * 4 * 48
	mov 	esi, button_save
	call 	drawbutton

	add		eax, WIDTH * 4 * 48
	mov 	esi, button_save_rle
	call 	drawbutton

	call	gfx_unmap
	call	gfx_draw
	
	pop 	esi
	pop		edx
	pop 	ecx
	pop		ebx
	pop 	eax
	ret

; canvas in eax
; color in ebx
; matrix in esi
drawbutton:
	push 	eax
	push	ebx
	push	ecx
	push 	edx
	push 	esi
	
	xor 	edx, edx

	.loopy:
	inc 	dl

	xor 	dh, dh

	.loopx:
	inc 	dh

	mov 	cl, [esi]
	inc 	esi

	cmp 	cl, 0
	je 		.skip

	mov 	[eax], ebx

	.skip:
	add 	eax, 4
	cmp 	dh, BUTTON_SIZE
	jl 		.loopx


	add 	eax, WIDTH * 4
	sub 	eax, BUTTON_SIZE * 4

	cmp 	dl, BUTTON_SIZE
	jl 		.loopy
	
	pop 	esi
	pop 	edx
	pop 	ecx
	pop		ebx
	pop 	eax
	ret

; coords in eax, ebx, ecx, edx
drawselection:
	push 	eax
	push 	ebx
	push	ecx
	push	edx
	push	edi
	push 	esi

	cmp		eax, ecx
	jle		.noswap
	xchg	eax, ecx
	.noswap:
	cmp		ebx, edx
	jle 	.noswap2
	xchg	ebx, edx
	.noswap2:
	mov 	esi, eax
	mov 	edi, ebx

	call 	gfx_map
	
	;initialize pos
	mov 	ebx, edi
	imul	ebx, 4*WIDTH
	add		eax, ebx

	;calc diff
	mov 	ebx, esi
	imul	ebx, 4
	add		eax, ebx




	mov 	ebx, esi
	.hline1:
	inc 	ebx

	neg  	dword [eax] 
	add		dword [eax], 0xFFFFFF

	add		eax, 4

	cmp 	ebx, ecx
	jl 	.hline1


	mov 	ebx, edi
	.vline1:
	inc 	ebx

	neg  	dword [eax] 
	add		dword [eax], 0xFFFFFF
	
	add		eax, WIDTH * 4

	cmp 	ebx, edx
	jl 	.vline1


	mov 	ebx, esi
	.hline2:
	inc 	ebx

	neg 	dword [eax] 
	add		dword [eax], 0xFFFFFF
	
	sub		eax, 4

	cmp 	ebx, ecx
	jl 		.hline2



	mov 	ebx, edi
	.vline2:
	inc 	ebx

	neg 	dword [eax] 
	add		dword [eax], 0xFFFFFF
	
	sub		eax, WIDTH * 4

	cmp 	ebx, edx
	jl 		.vline2
	
	pop 	esi
	pop 	edi
	pop 	edx
	pop 	ecx
	pop		ebx
	pop 	eax
ret

drawsavemenu:
	push	eax
	push 	ebx
	push	ecx
	push	edx
	push 	esi

	call 	gfx_map
	mov 	ebx, WIDTH / 2 - 90
	mov 	ecx, HEIGHT / 2 - 30

	mov 	edx, ecx
	imul	edx, WIDTH
	add 	edx, ebx

	shl		edx, 2

	add 	eax, edx

	.loopy:

	mov		ebx, WIDTH / 2 - 90
	.loopx:
	mov 	dword [eax], PRIMARY_COLOR
	add 	eax, 4
	inc 	ebx
	
	cmp 	ebx, WIDTH / 2 + 90
	jle 	.loopx
	
	add 	eax, (WIDTH - 181) * 4
	inc 	ecx

	cmp 	ecx, HEIGHT / 2 + 30
	jle 	.loopy

	call	gfx_unmap
	call	gfx_draw


	; buttons
	call 	gfx_map
	mov 	ebx, WIDTH / 2 - 80
	mov 	ecx, HEIGHT / 2 - 16

	mov 	edx, ecx
	imul	edx, WIDTH
	add 	edx, ebx

	shl		edx, 2

	add 	eax, edx

	mov 	ebx, WHITE

	add 	eax, 16 * 4
	mov 	esi, button_8
	call	drawbutton

	add 	eax, 32 * 4 + 16 * 4
	mov 	esi, button_24
	call	drawbutton

	add 	eax, 32 * 4 + 16 * 4
	mov 	esi, button_32
	call	drawbutton

	call	gfx_unmap
	call	gfx_draw

	pop 	esi
	pop 	edx
	pop 	ecx
	pop 	ebx
	pop 	eax
ret

; coords in eax, ebx, ecx, edx
crop:
	push 	eax
	push 	ebx
	push	ecx
	push	edx
	push	edi
	push 	esi


	cmp		eax, ecx
	jle		.noswap
	xchg	eax, ecx
	.noswap:
	cmp		ebx, edx
	jle 	.noswap2
	xchg	ebx, edx
	.noswap2:

	mov 	[new_width], ecx
	sub 	[new_width], eax
	inc 	dword [new_width]

	mov 	[new_height], edx
	sub 	[new_height], ebx
	inc 	dword [new_height]

	mov 	edi, eax
	mov 	eax, [new_height]
	imul	eax, [new_width]
	shl		eax, 2
	call	mem_alloc
	xchg	edi, eax
	push 	edi

	mov 	esi, ebx
	imul	esi, IMG_WIDTH
	add		esi, eax
	shl		esi, 2
	add 	esi, [img]

	mov 	ebx, IMG_WIDTH
	sub 	ebx, [new_width]
	shl 	ebx, 2

	xor		ecx, ecx
	.loopy:
	inc 	ecx

	xor		edx, edx
	.loopx:
	inc 	edx

	mov 	eax, [esi]
	mov 	[edi], eax
	add		edi, 4
	add 	esi, 4

	cmp		edx, [new_width]
	jl 		.loopx

	add 	esi, ebx

	cmp		ecx, [new_height]
	jl 		.loopy

	mov 	eax, [img]
	call	mem_free
	pop 	edi
	mov 	[img], edi


	mov 	eax, [new_width]
	mov 	IMG_WIDTH, eax
	mov 	eax, [new_height]
	mov 	IMG_HEIGHT, eax
.end:
	pop 	esi
	pop 	edi
	pop 	edx
	pop 	ecx
	pop		ebx
	pop 	eax
ret

; new size in eax, ebx
resize:
	push 		eax
	push 		ebx
	push 		ecx
	push 		edx
	push 		esi
	push 		edi

	sub			eax, 64
	mov 		[new_height], ebx
	mov  		[new_width], eax

	imul 		eax, ebx
	shl			eax, 2

	call		mem_alloc

	mov 		edi, eax
	mov 		esi, [img]

	cvtsi2ss	xmm2, [new_width]
	cvtsi2ss	xmm3, IMG_WIDTH
	cvtsi2ss	xmm4, [new_height]
	cvtsi2ss	xmm5, IMG_HEIGHT

	xor			ecx, ecx
	.loopy:
	cvtsi2ss	xmm0, ecx
	divss		xmm0, xmm4
	mulss		xmm0, xmm5

		xor 		edx, edx
		.loopx:
		cvtsi2ss	xmm1, edx
		divss		xmm1, xmm2
		mulss		xmm1, xmm3

		cvtss2si	eax, xmm0
		inc 		eax
		cmp  		eax, IMG_HEIGHT
		cmovg		eax, IMG_HEIGHT
		dec 		eax

		imul		eax, IMG_WIDTH

		cvtss2si	ebx, xmm1
		inc 		ebx
		cmp 		ebx, IMG_WIDTH
		cmovg		ebx, IMG_WIDTH
		dec 		ebx

		add 		eax, ebx
		shl			eax, 2

		mov 		ebx, [esi + eax]
		mov 		[edi], ebx

		add 		edi, 4
		inc 		edx

		cmp 		edx, [new_width]
		jl 			.loopx

	inc 		ecx

	cmp  		ecx, [new_height]
	jl 			.loopy

	mov 		eax, [new_height]
	mov 		IMG_HEIGHT, eax
	mov 		eax, [new_width]
	mov 		IMG_WIDTH, eax

	mov 		eax, [img]
	call		mem_free

	mov 		ebx, IMG_HEIGHT
	imul 		ebx, IMG_WIDTH
	shl			ebx, 2

	sub			edi, ebx

	mov 		[img], edi

	pop 		edi
	pop 		esi
	pop 		edx
	pop 		ecx
	pop 		ebx
	pop 		eax
ret

blur:
	push		eax
	push		ebx
	push		ecx
	push		edx
	push		esi
	push 		edi

	mov 		eax, IMG_WIDTH
	imul 		eax, IMG_HEIGHT
	shl			eax, 2

	call		mem_alloc

	mov 		edi, eax
	mov 		esi, [img]
	
	xor			ecx, ecx
	.loopy:

		xor			edx, edx
		.loopx:
		call 		calcAvg
		mov 		[edi], eax



		add 		esi, 4
		add 		edi, 4
		inc 		edx

		cmp			edx, IMG_WIDTH
		jl 			.loopx

	inc 		ecx

	cmp			ecx, IMG_HEIGHT
	jl			.loopy


	mov 		eax, [img]
	call		mem_free
	
	mov 		eax, IMG_WIDTH
	imul 		eax, IMG_HEIGHT
	shl			eax, 2

	sub			edi, eax
	mov 		[img], edi

	pop 		edi
	pop 		esi
	pop 		edx
	pop 		ecx
	pop 		ebx
	pop 		eax
ret

calcAvg:
	push		ebx
	push 		edx
	push		esi

	xor			ebx, ebx
	xor			eax, eax

	inc 		ecx
	inc 		edx

	mov 		dword [tempb], 0
	mov 		dword [tempg], 0
	mov 		dword [tempr], 0

	cmp			ecx, 1
	je 			.midrow

	.firstrow:
	sub			esi, IMG_WIDTH
	sub			esi, IMG_WIDTH
	sub			esi, IMG_WIDTH
	sub			esi, IMG_WIDTH

	cmp			edx, 1
	je 			.mid
	;(0, 0)
	sub			esi, 4
	mov 		bl, [esi]
	add 		[tempb], ebx
	
	mov 		bl, [esi + 1]
	add 		[tempg], ebx

	mov 		bl, [esi + 2]
	add 		[tempr], ebx
	
	add 		esi, 4
	inc 		eax

	.mid:
	;(0, 1)
	xor			ebx, ebx
	mov 		bl, [esi]
	shl			ebx, 1
	add 		[tempb], ebx

	xor			ebx, ebx
	mov 		bl, [esi + 1]
	shl			ebx, 1
	add 		[tempg], ebx

	xor			ebx, ebx
	mov 		bl, [esi + 2]
	shl			ebx, 1
	
	add 		[tempr], ebx
	add 		eax, 2

	cmp			edx, IMG_WIDTH
	jge 		.skip

	;(0, 2)
	add			esi, 4
	xor			ebx, ebx
	mov 		bl, [esi]
	add 		[tempb], ebx

	xor			ebx, ebx
	mov 		bl, [esi + 1]
	add 		[tempg], ebx
	
	xor			ebx, ebx
	mov 		bl, [esi + 2]
	add 		[tempr], ebx
	
	sub 		esi, 4
	inc 		eax

	.skip:
	add 		esi, IMG_WIDTH
	add 		esi, IMG_WIDTH
	add 		esi, IMG_WIDTH
	add 		esi, IMG_WIDTH

	.midrow:
	cmp			edx, 1
	je 			.mid2

	;(1, 0)
	sub			esi, 4
	xor			ebx, ebx
	mov 		bl, [esi]
	shl			ebx, 1
	add 		[tempb], ebx
	
	xor			ebx, ebx
	mov 		bl, [esi + 1]
	shl			ebx, 1
	add 		[tempg], ebx
	
	xor			ebx, ebx
	mov 		bl, [esi + 2]
	shl			ebx, 1
	add 		[tempr], ebx
	
	add 		esi, 4
	add 		eax, 2

	.mid2:
	;(1, 1)
	xor			ebx, ebx
	mov 		bl, [esi]
	shl			ebx, 2
	add 		[tempb], ebx
	
	xor			ebx, ebx
	mov 		bl, [esi + 1]
	shl			ebx, 2
	add 		[tempg], ebx
	
	xor			ebx, ebx
	mov 		bl, [esi + 2]
	shl			ebx, 2
	add 		[tempr], ebx

	add 		eax, 4

	cmp			edx, IMG_WIDTH
	jge 		.thirdrow

	;(1, 2)
	add			esi, 4
	xor			ebx, ebx
	mov 		bl, [esi]
	shl			ebx, 1
	add 		[tempb], ebx
	
	xor			ebx, ebx
	mov 		bl, [esi + 1]
	shl			ebx, 1
	add 		[tempg], ebx
	
	xor			ebx, ebx
	mov 		bl, [esi + 2]
	shl			ebx, 1
	add 		[tempr], ebx
	
	sub 		esi, 4
	add 		eax, 2
	.thirdrow:
	cmp			ecx, IMG_HEIGHT
	jge 		.skip3

	add 		esi, IMG_WIDTH
	add 		esi, IMG_WIDTH
	add 		esi, IMG_WIDTH
	add 		esi, IMG_WIDTH

	cmp			edx, 1
	je 			.mid3

	;(2, 0)
	sub			esi, 4
	xor			ebx, ebx
	mov 		bl, [esi]
	add 		[tempb], ebx
	
	xor			ebx, ebx
	mov 		bl, [esi + 1]
	add 		[tempg], ebx
	
	xor			ebx, ebx
	mov 		bl, [esi + 2]
	add 		[tempr], ebx
	
	add 		esi, 4
	inc 		eax

	.mid3:
	;(2, 1)
	xor			ebx, ebx
	mov 		bl, [esi]
	shl			ebx, 1
	add 		[tempb], ebx
	
	xor			ebx, ebx
	mov 		bl, [esi + 1]
	shl			ebx, 1
	add 		[tempg], ebx
	
	xor			ebx, ebx
	mov 		bl, [esi + 2]
	shl			ebx, 1
	add 		[tempr], ebx
	
	add 		eax, 2


	cmp			edx, IMG_WIDTH
	jge 		.skip3

	;(2, 2)
	add			esi, 4
	xor			ebx, ebx
	mov 		bl, [esi]
	add 		[tempb], ebx
	
	xor			ebx, ebx
	mov 		bl, [esi + 1]
	add 		[tempg], ebx
	
	xor			ebx, ebx
	mov 		bl, [esi + 2]
	add 		[tempr], ebx
	
	sub 		esi, 4
	inc 		eax

	.skip3:
	mov 		ebx, eax

	xor			edx, edx
	mov 		eax, [tempr]
	div			ebx
	and			eax, 0x000000FF
	shl			eax, 16
	mov 		esi, eax

	xor			edx, edx
	mov 		eax, [tempg]
	div			ebx
	and			eax, 0x000000FF
	shl			eax, 8
	or 			esi, eax

	xor			edx, edx
	mov 		eax, [tempb]
	div			ebx
	and			eax, 0x000000FF
	shl			eax, 0
	or 			esi, eax

	mov 		eax, esi

	dec 		ecx
	dec 		edx	

	pop 		esi
	pop 		edx
	pop 		ebx
ret

eventlistener:
	.eventloop:
	call	gfx_getevent

	cmp		eax, 23
	je		.end
	
	cmp		eax, 27
	je		.end

	cmp		eax, 1
	je		.pressed

	cmp		eax, -1
	je		.released

	cmp 	eax, 0
	jne		.eventloop

	cmp		byte [movemouse], -1
	je 		.action

	cmp		byte [movemouse], 1
	je 		.preview

	jmp 	.eventloop

	.pressed:
	mov 	byte [movemouse], 1
	call 	gfx_getmouse
	mov 	[prevmousex], eax
	mov 	[prevmousey], ebx
	jmp 	.eventloop


	.released:
	mov 	byte [movemouse], -1
	jmp 	.eventloop


	.preview:
	mov 	eax, [prevmousex]
	cmp		eax, 64
	jl 		.eventloop

	call 	gfx_getmouse
	
	cmp		eax, 64
	jge		.larger
	
	mov 	eax, 64
	
	.larger:
	cmp		byte [selected], 1
	je 		.previewcrop
	
	cmp		byte [selected], 2
	je 		.previewres
	
	jmp		.eventloop


	.previewcrop:
	mov 	ecx, [prevmousex]
	mov 	edx, [prevmousey]
	
	sub		ecx, 64
	cmp		ecx, IMG_WIDTH
	jge		.eventloop
	add		ecx, 64

	cmp		edx, IMG_HEIGHT
	jge		.eventloop

	sub		eax, 64
	cmp		eax, IMG_WIDTH
	jl		.skipx
	mov 	eax, IMG_WIDTH
	dec 	eax
	.skipx:
	add		eax, 64
	cmp		ebx, IMG_HEIGHT
	jl		.skipy
	mov 	ebx, IMG_HEIGHT
	dec 	ebx
	.skipy:

	call	clearcanvas
	call 	drawselection
	call	gfx_draw
	jmp 	.eventloop

	.previewres:
	mov 	ecx, 64
	xor 	edx, edx
	call	clearcanvas
	call 	drawselection
	call	gfx_draw
	jmp 	.eventloop

	.action:
	mov 	byte [movemouse], 0
	call	gfx_getmouse

	cmp 	dword [prevmousex], 64
	jge 	.canvasaction


	cmp 	eax, 48
	jge 	.eventloop
	cmp 	eax, 16
	jle 	.eventloop

	cmp 	ebx, 16
	jl		.eventloop
	cmp 	ebx, 48
	jle 	.button1
	cmp		ebx, 64
	jl		.eventloop
	cmp		ebx, 96
	jl 		.button2
	cmp		ebx, 112
	jl 		.eventloop
	cmp		ebx, 144
	jl 		.button3
	cmp		ebx, 160
	jl 		.eventloop
	cmp		ebx, 192
	jl 		.button4
	cmp		ebx, 208
	jl 		.eventloop
	cmp		ebx, 240
	jl 		.button5
	jmp 	.eventloop

	.button1:
	mov 	byte [selected], 1
	jmp 	.drawhighlight
	.button2:
	mov 	byte [selected], 2
	jmp 	.drawhighlight
	.button3:
	mov 	byte [selected], 3
	call 	blur
	call	clearcanvas
	jmp 	.drawhighlight
	.button4:
	mov 	byte [selected], 4
	call 	drawsavemenu
	jmp 	.drawhighlight
	.button5:
	mov 	byte [selected], 5
	call 	drawsavemenu
	jmp 	.drawhighlight

	.drawhighlight:
	call 	drawbar
	jmp		.eventloop

	.canvasaction:
	cmp		byte [selected], 0
	jne		.crop
	jmp		.eventloop

	.crop:
	cmp		byte [selected], 1
	jne 	.resize

	mov 	ecx, [prevmousex]
	mov 	edx, [prevmousey]
	
	sub		ecx, 64
	cmp		ecx, IMG_WIDTH
	jge		.eventloop

	cmp		edx, IMG_HEIGHT
	jge		.eventloop

	sub		eax, 64
	cmp		eax, IMG_WIDTH
	cmovg	eax, IMG_WIDTH
	dec 	eax

	cmp 	eax, 0
	cmovl	eax, [zero]

	cmp		ebx, IMG_HEIGHT
	cmovg	ebx, IMG_HEIGHT
	dec 	ebx

	cmp 	ebx, 0
	cmovl	ebx, [zero]

	call	crop
	call	clearcanvas
	jmp		.eventloop


	.resize:
	cmp		byte [selected], 2
	jne 	.save

	call	resize
	call	clearcanvas

	.save:
	cmp		byte [selected], 4
	jne 	.saverle

	call	gfx_getmouse

	cmp 	ebx, HEIGHT / 2 - 16
	jl 		.refresh
	cmp 	ebx, HEIGHT / 2 + 16
	jg 		.refresh
	cmp 	eax, WIDTH / 2 - 90
	jl 		.refresh
	cmp 	eax, WIDTH / 2 + 90
	jg 		.refresh

	cmp 	eax, WIDTH / 2 - 90 + 16
	jl 		.eventloop
	cmp 	eax, WIDTH / 2 - 90 + 16 + 32
	jg 		.save24
	call	save8
	jmp		.refresh

	.save24:
	cmp 	eax, WIDTH / 2 - 90 + 2 * 16 + 32 
	jl 		.eventloop
	cmp 	eax, WIDTH / 2 - 90 + 2 * 16 + 2 * 32
	jg 		.save32
	call	save24
	jmp		.refresh

	.save32:
	cmp 	eax, WIDTH / 2 - 90 + 3 * 16 + 2 * 32
	jl 		.eventloop
	cmp 	eax, WIDTH / 2 - 90 + 3 * 16 + 3 * 32
	jge 	.eventloop

	call	save32
	jmp		.refresh

	.saverle:
	cmp		byte [selected], 5
	jne 	.eventloop

	call	gfx_getmouse

	cmp 	ebx, HEIGHT / 2 - 16
	jl 		.refresh
	cmp 	ebx, HEIGHT / 2 + 16
	jg 		.refresh
	cmp 	eax, WIDTH / 2 - 90
	jl 		.refresh
	cmp 	eax, WIDTH / 2 + 90
	jg 		.refresh

	cmp 	eax, WIDTH / 2 - 90 + 16
	jl 		.eventloop
	cmp 	eax, WIDTH / 2 - 90 + 16 + 32
	jg 		.save24rle
	call	save8rle
	jmp		.refresh

	.save24rle:
	cmp 	eax, WIDTH / 2 - 90 + 2 * 16 + 32 
	jl 		.eventloop
	cmp 	eax, WIDTH / 2 - 90 + 2 * 16 + 2 * 32
	jg 		.save32rle
	call	save24rle
	jmp		.refresh

	.save32rle:
	cmp 	eax, WIDTH / 2 - 90 + 3 * 16 + 2 * 32
	jl 		.eventloop
	cmp 	eax, WIDTH / 2 - 90 + 3 * 16 + 3 * 32
	jge 	.eventloop

	call	save32rle

	.refresh:
	call	clearcanvas
	jmp		.eventloop

	.end:
	ret

save32:
	push	eax
	push	ebx
	push 	ecx

	call 	getpath

	mov 	ebx, 1

	call 	fio_open

	mov 	IMG_OFFSET, 54
	mov 	IMG_BPPX, 32
	mov 	IMG_COMPR, 0
	
	mov 	ebx, img_header
	mov 	ecx, 54

	call	fio_write

	mov 	ecx, IMG_HEIGHT
	dec 	ecx
	imul	ecx, IMG_WIDTH
	shl		ecx, 2

	mov 	ebx, [img]
	add		ebx, ecx

	mov 	ecx, IMG_WIDTH
	shl		ecx, 2

	.loop:
	call	fio_write
	sub		ebx, ecx
	cmp		ebx, [img]
	jge 	.loop

	.end:
	call 	fio_close
	
	pop  	ecx
	pop 	ebx
	pop  	eax
ret

save24:
	push	eax
	push	ebx
	push 	ecx
	push	edx
	push 	esi
	push 	edi

	call 	getpath

	mov 	ebx, 1

	call 	fio_open

	mov 	IMG_OFFSET, 54
	mov 	IMG_BPPX, 24
	mov 	IMG_COMPR, 0
	mov 	IMG_COLORS, 0
	
	mov 	ebx, img_header
	mov 	ecx, 54

	call	fio_write

	mov 	edx, IMG_HEIGHT
	dec 	edx
	imul	edx, IMG_WIDTH
	shl		edx, 2

	mov 	ebx, [img]
	add		ebx, edx

	mov 	edi, IMG_WIDTH
	imul 	edi, 24
	add		edi, 31
	shr		edi, 5
	shl		edi, 2

	mov 	ecx, 3
	.loopy:
		xor 	esi, esi
		.loopx:
		call	fio_write
		add		ebx, 4
		inc 	esi
		cmp		esi, IMG_WIDTH
		jl		.loopx

	push	ebx
	mov 	ebx, zero

		imul	esi, 3
		.loop2:
		cmp 	esi, edi
		jge		.skip
		call	fio_write
		add 	esi, 3
		jmp		.loop2
		
	.skip:
	pop 	ebx

	mov 	edx, IMG_WIDTH
	shl		edx, 3
	sub		ebx, edx


	cmp		ebx, [img]
	jge 	.loopy

	.end:
	call 	fio_close
	
	pop 	edi
	pop 	esi
	pop  	edx
	pop  	ecx
	pop 	ebx
	pop  	eax
ret

save8:
	push	eax
	push	ebx
	push 	ecx
	push	edx
	push 	esi
	push 	edi

	call 	getpath

	mov 	ebx, 1

	call 	fio_open

	mov 	IMG_OFFSET, 1078
	mov 	IMG_BPPX, 8
	mov 	IMG_COMPR, 0
	mov 	IMG_COLORS, 256
	
	mov 	ebx, img_header
	mov 	ecx, 54

	call	fio_write

	mov 	ebx, default_palette
	mov 	ecx, 1024

	call 	fio_write

	mov 	edx, IMG_HEIGHT
	dec 	edx
	imul	edx, IMG_WIDTH
	shl		edx, 2

	mov 	ebx, [img]
	add		ebx, edx

	mov 	edi, IMG_WIDTH
	shl 	edi, 3
	add		edi, 31
	shr		edi, 5
	shl		edi, 2

	mov 	ecx, 1
	.loopy:
		
		xor 	esi, esi
		.loopx:
		mov 	edx, [ebx]

		call	getClosestColor

		push	ebx
		mov 	ebx, closestcol
		call	fio_write
		pop 	ebx

		add		ebx, 4
		inc 	esi
		cmp		esi, IMG_WIDTH
		jl		.loopx

	push	ebx
	mov 	ebx, zero

		.loop2:
		cmp 	esi, edi
		jge		.skip
		call	fio_write
		inc 	esi
		jmp		.loop2
		
	.skip:
	pop 	ebx

	mov 	edx, IMG_WIDTH
	shl		edx, 3
	sub		ebx, edx


	cmp		ebx, [img]
	jge 	.loopy

	.end:
	call 	fio_close
	
	pop 	edi
	pop 	esi
	pop  	edx
	pop  	ecx
	pop 	ebx
	pop  	eax
ret

save8rle:
	push	eax
	push	ebx
	push 	ecx
	push	edx
	push 	esi
	push 	edi

	call 	getpath

	mov 	ebx, 1

	call 	fio_open

	mov 	IMG_OFFSET, 1078
	mov 	IMG_BPPX, 8
	mov 	IMG_COMPR, 1
	mov 	IMG_COLORS, 256
	
	mov 	ebx, img_header
	mov 	ecx, 54

	call	fio_write

	mov 	ebx, default_palette
	mov 	ecx, 1024

	call 	fio_write

	mov 	edx, IMG_HEIGHT
	dec 	edx
	imul	edx, IMG_WIDTH
	shl		edx, 2

	mov 	edi, [img]
	add		edi, edx
	
	mov 	ebx, zero
	mov 	ecx, 2
	.loopy:
		
		mov 	edx, [edi]
		call	getClosestColor
		mov 	dl, [closestcol]
		mov 	[prevrle], dl
		mov 	[cntrle], byte 0

			xor 	esi, esi
			.loopx:
			mov 	edx, [edi]

			call	getClosestColor

			mov 	dl, [closestcol]

			cmp 	dl, [prevrle]
			jne 	.write

			cmp 	byte [cntrle], 127
			je 		.write

			jmp		.continue

			.write:
			call 	writerle

			mov 	[prevrle], dl
			mov 	byte [cntrle], 0

			.continue:
			inc 	byte [cntrle]
			add		edi, 4
			inc 	esi
			cmp		esi, IMG_WIDTH
			jl		.loopx

	call 	writerle

	call 	fio_write

	mov 	edx, IMG_WIDTH
	shl		edx, 3
	sub		edi, edx


	cmp		edi, [img]
	jge 	.loopy

	.end:
	call 	fio_close
	
	pop 	edi
	pop 	esi
	pop  	edx
	pop  	ecx
	pop 	ebx
	pop  	eax
ret

save24rle:
	push	eax
	push	ebx
	push 	ecx
	push	edx
	push 	esi
	push 	edi

	call 	getpath

	mov 	ebx, 1

	call 	fio_open

	mov 	IMG_OFFSET, 54
	mov 	IMG_BPPX, 24
	mov 	IMG_COMPR, 1
	mov 	IMG_COLORS, 0
	
	mov 	ebx, img_header
	mov 	ecx, 54

	call	fio_write

	mov 	ebx, zero
	mov 	ecx, 2

	; BLUE
	mov 	edx, IMG_HEIGHT
	dec 	edx
	imul	edx, IMG_WIDTH
	shl		edx, 2

	mov 	edi, [img]
	add		edi, edx

	.loopyblue:
		xor 	esi, esi
		
		mov 	byte [cntrle], 0
		mov 	dl, [edi]
		mov 	byte [prevrle], dl

		.loopxblue:
		mov 	dl, [edi]
		cmp 	dl, [prevrle]
		jne 	.writeblue
		cmp 	byte [cntrle], 127
		je 		.writeblue
		jmp		.incblue

		.writeblue:
		call	writerle
		mov 	[prevrle], dl
		mov 	byte [cntrle], 0

		.incblue:
		add		edi, 4
		inc 	byte [cntrle]
		inc 	esi
		cmp		esi, IMG_WIDTH
		jl		.loopxblue

	call 	writerle
	call	fio_write

	mov 	edx, IMG_WIDTH
	shl		edx, 3
	sub		edi, edx

	cmp		edi, [img]
	jge 	.loopyblue

	; GREEN
	mov 	edx, IMG_HEIGHT
	dec 	edx
	imul	edx, IMG_WIDTH
	shl		edx, 2

	mov 	edi, [img]
	add		edi, edx
	inc 	edi

	.loopygreen:
		xor 	esi, esi
		
		mov 	byte [cntrle], 0
		mov 	dl, [edi]
		mov 	byte [prevrle], dl

		.loopxgreen:
		mov 	dl, [edi]
		cmp 	dl, [prevrle]
		jne 	.writegreen
		cmp 	byte [cntrle], 127
		je 		.writegreen
		jmp		.incgreen

		.writegreen:
		call	writerle
		mov 	[prevrle], dl
		mov 	byte [cntrle], 0

		.incgreen:
		add		edi, 4
		inc 	byte [cntrle]
		inc 	esi
		cmp		esi, IMG_WIDTH
		jl		.loopxgreen

	call 	writerle
	call	fio_write

	mov 	edx, IMG_WIDTH
	shl		edx, 3
	sub		edi, edx

	cmp		edi, [img]
	jge 	.loopygreen


	; RED
	mov 	edx, IMG_HEIGHT
	dec 	edx
	imul	edx, IMG_WIDTH
	shl		edx, 2

	mov 	edi, [img]
	add		edi, edx
	add 	edi, 2

	mov 	ebx, zero
	mov 	ecx, 2
	.loopyred:
		xor 	esi, esi
		
		mov 	byte [cntrle], 0
		mov 	dl, [edi]
		mov 	byte [prevrle], dl

		.loopxred:
		mov 	dl, [edi]
		cmp 	dl, [prevrle]
		jne 	.writered
		cmp 	byte [cntrle], 127
		je 		.writered
		jmp		.incred

		.writered:
		call	writerle
		mov 	[prevrle], dl
		mov 	byte [cntrle], 0

		.incred:
		add		edi, 4
		inc 	byte [cntrle]
		inc 	esi
		cmp		esi, IMG_WIDTH
		jl		.loopxred

	call 	writerle
	call	fio_write

	mov 	edx, IMG_WIDTH
	shl		edx, 3
	sub		edi, edx

	cmp		edi, [img]
	jge 	.loopyred

	.end:
	call 	fio_close
	
	pop 	edi
	pop 	esi
	pop  	edx
	pop  	ecx
	pop 	ebx
	pop  	eax
ret

save32rle:
	push	eax
	push	ebx
	push 	ecx
	push	edx
	push 	esi
	push 	edi

	call 	getpath

	mov 	ebx, 1

	call 	fio_open

	mov 	IMG_OFFSET, 54
	mov 	IMG_BPPX, 24
	mov 	IMG_COMPR, 1
	mov 	IMG_COLORS, 0
	
	mov 	ebx, img_header
	mov 	ecx, 54

	call	fio_write

	mov 	ebx, zero
	mov 	ecx, 2

	; BLUE
	mov 	edx, IMG_HEIGHT
	dec 	edx
	imul	edx, IMG_WIDTH
	shl		edx, 2

	mov 	edi, [img]
	add		edi, edx

	.loopyblue:
		xor 	esi, esi
		
		mov 	byte [cntrle], 0
		mov 	dl, [edi]
		mov 	byte [prevrle], dl

		.loopxblue:
		mov 	dl, [edi]
		cmp 	dl, [prevrle]
		jne 	.writeblue
		cmp 	byte [cntrle], 127
		je 		.writeblue
		jmp		.incblue

		.writeblue:
		call	writerle
		mov 	[prevrle], dl
		mov 	byte [cntrle], 0

		.incblue:
		add		edi, 4
		inc 	byte [cntrle]
		inc 	esi
		cmp		esi, IMG_WIDTH
		jl		.loopxblue

	call 	writerle
	call	fio_write

	mov 	edx, IMG_WIDTH
	shl		edx, 3
	sub		edi, edx

	cmp		edi, [img]
	jge 	.loopyblue

	; GREEN
	mov 	edx, IMG_HEIGHT
	dec 	edx
	imul	edx, IMG_WIDTH
	shl		edx, 2

	mov 	edi, [img]
	add		edi, edx
	inc 	edi

	.loopygreen:
		xor 	esi, esi
		
		mov 	byte [cntrle], 0
		mov 	dl, [edi]
		mov 	byte [prevrle], dl

		.loopxgreen:
		mov 	dl, [edi]
		cmp 	dl, [prevrle]
		jne 	.writegreen
		cmp 	byte [cntrle], 127
		je 		.writegreen
		jmp		.incgreen

		.writegreen:
		call	writerle
		mov 	[prevrle], dl
		mov 	byte [cntrle], 0

		.incgreen:
		add		edi, 4
		inc 	byte [cntrle]
		inc 	esi
		cmp		esi, IMG_WIDTH
		jl		.loopxgreen

	call 	writerle
	call	fio_write

	mov 	edx, IMG_WIDTH
	shl		edx, 3
	sub		edi, edx

	cmp		edi, [img]
	jge 	.loopygreen


	; RED
	mov 	edx, IMG_HEIGHT
	dec 	edx
	imul	edx, IMG_WIDTH
	shl		edx, 2

	mov 	edi, [img]
	add		edi, edx
	add 	edi, 2

	mov 	ebx, zero
	mov 	ecx, 2
	.loopyred:
		xor 	esi, esi
		
		mov 	byte [cntrle], 0
		mov 	dl, [edi]
		mov 	byte [prevrle], dl

		.loopxred:
		mov 	dl, [edi]
		cmp 	dl, [prevrle]
		jne 	.writered
		cmp 	byte [cntrle], 127
		je 		.writered
		jmp		.incred

		.writered:
		call	writerle
		mov 	[prevrle], dl
		mov 	byte [cntrle], 0

		.incred:
		add		edi, 4
		inc 	byte [cntrle]
		inc 	esi
		cmp		esi, IMG_WIDTH
		jl		.loopxred

	call 	writerle
	call	fio_write

	mov 	edx, IMG_WIDTH
	shl		edx, 3
	sub		edi, edx

	cmp		edi, [img]
	jge 	.loopyred

	; ALPHA
	mov 	edx, IMG_HEIGHT
	dec 	edx
	imul	edx, IMG_WIDTH
	shl		edx, 2

	mov 	edi, [img]
	add		edi, edx
	add 	edi, 3

	mov 	ebx, zero
	mov 	ecx, 2
	.loopyalpha:
		xor 	esi, esi
		
		mov 	byte [cntrle], 0
		mov 	dl, [edi]
		mov 	byte [prevrle], dl

		.loopxalpha:
		mov 	dl, [edi]
		cmp 	dl, [prevrle]
		jne 	.writealpha
		cmp 	byte [cntrle], 127
		je 		.writealpha
		jmp		.incalpha

		.writealpha:
		call	writerle
		mov 	[prevrle], dl
		mov 	byte [cntrle], 0

		.incalpha:
		add		edi, 4
		inc 	byte [cntrle]
		inc 	esi
		cmp		esi, IMG_WIDTH
		jl		.loopxalpha

	call 	writerle
	call	fio_write

	mov 	edx, IMG_WIDTH
	shl		edx, 3
	sub		edi, edx

	cmp		edi, [img]
	jge 	.loopyalpha

	.end:
	call 	fio_close
	
	pop 	edi
	pop 	esi
	pop  	edx
	pop  	ecx
	pop 	ebx
	pop  	eax
ret

writerle:
	push	ebx
	push	ecx
	push 	edx

	mov 	ecx, 1

	mov 	ebx, cntrle
	call 	fio_write

	mov 	ebx, prevrle
	call	fio_write
	
	pop 	edx
	pop 	ecx
	pop 	ebx
ret

getClosestColor:
	push	ebx
	push 	ecx
	xor		ecx, ecx

	mov 	[color1], edx
	mov 	dword [mindist], 0xFFFFFF

	.loop:
	mov 	edx, [default_palette + ecx * 4]
	mov 	[color2], edx

	call	distHex

	cmp 	edx, [mindist]
	jge		.notcloser

	mov 	[mindist], edx
	mov 	[closestcol], cl
	.notcloser:
	inc 	ecx

	cmp 	ecx, 256
	jl		.loop

	pop 	ecx
	pop 	ebx
ret

distHex:
	push 	eax
	push	ebx

	xor		edx, edx

	;blue
	mov 	eax, [color1]
	and		eax, 0x00FF0000
	shr		eax, 16

	mov 	ebx, [color2]
	and		ebx, 0x00FF0000
	shr		ebx, 16

	sub		eax, ebx
	imul	eax, eax
	add 	edx, eax

	;green
	mov 	eax, [color1]
	and		eax, 0x0000FF00
	shr		eax, 8

	mov 	ebx, [color2]
	and		ebx, 0x0000FF00
	shr		ebx, 8

	sub		eax, ebx
	imul	eax, eax
	add 	edx, eax

	;red
	mov 	eax, [color1]
	and		eax, 0x000000FF

	mov 	ebx, [color2]
	and		ebx, 0x000000FF

	sub		eax, ebx
	imul	eax, eax
	add 	edx, eax

	pop  	ebx
	pop 	eax
ret


section .rodata
    caption db "BMP Editor", 0
	errormsg db "ERROR: could not initialize graphics!", 0
	fileerrormsg db "ERROR: could not open image!", 0
	sizeerrormsg db "ERROR: image dimensions are too large!", 0
	infomsg db "Use WASD and mouse (drag) to move the image!", 0
	
	zero dd 0

	button_crop 	db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,1,1,1,0,1,1,1,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0
					db 0,0,0,1,1,1,0,1,1,1,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0
					db 0,0,0,1,1,1,0,1,1,1,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,1,1,1,0,1,1,1,0,0,0
					db 0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,1,1,1,0,1,1,1,0,0,0
					db 0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,1,1,1,0,1,1,1,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

	button_resize 	db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,1,1,1,0,0,0,1,1,1,0,0,0,1,1,1,0,0,0,1,1,1,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,0,0,0,1,1,1,0,0,0,1,1,1,0,0,0,1,1,1,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,0,0,0,1,1,1,0,0,0,1,1,1,0,0,0,1,1,1,0,0,1,1,1,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,0,0,0,1,1,1,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0
					db 0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,0,0,0,0,0,0,0,0,1,1,1,1,1,0,1,1,1,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,0,0,0,0,0,0,0,1,1,1,1,1,0,0,1,1,1,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0
					db 0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0
					db 0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0
					db 0,0,0,1,1,1,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,1,1,1,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,1,1,1,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,1,1,1,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,1,1,1,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,1,1,1,0,0,1,1,1,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

	button_blur 	db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,1,1,1,1,1,1,0,1,1,1,0,0,1,1,1,1,1,1,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,1,1,1,1,1,0,0,0,1,1,1,0,0,0,0,1,1,1,1,1,0,0,0,0,0,0
					db 0,0,0,0,0,1,1,1,1,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0
					db 0,0,0,0,0,1,1,1,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0
					db 0,0,0,0,1,1,1,1,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0
					db 0,0,0,0,1,1,1,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0
					db 0,0,0,1,1,1,1,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,1,1,1,1,0,0,0
					db 0,0,0,1,1,1,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0
					db 0,0,0,1,1,1,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0
					db 0,0,0,1,1,1,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0
					db 0,0,0,1,1,1,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,1,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,1,1,1,1,0,0,0
					db 0,0,0,0,1,1,1,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0
					db 0,0,0,0,1,1,1,1,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0
					db 0,0,0,0,0,1,1,1,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0
					db 0,0,0,0,0,1,1,1,1,0,0,0,0,0,1,1,1,0,0,0,0,0,0,1,1,1,1,0,0,0,0,0
					db 0,0,0,0,0,0,1,1,1,1,1,0,0,0,1,1,1,0,0,0,0,1,1,1,1,1,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,1,1,1,1,1,1,0,1,1,1,0,0,1,1,1,1,1,1,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

	button_selected db 0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0
					db 0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0
					db 0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0
					db 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
					db 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
					db 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
					db 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
					db 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
					db 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
					db 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
					db 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
					db 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
					db 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
					db 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
					db 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
					db 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
					db 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
					db 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
					db 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
					db 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
					db 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
					db 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
					db 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
					db 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
					db 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
					db 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
					db 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
					db 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
					db 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
					db 0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0
					db 0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0
					db 0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0

	button_save		db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0
					db 0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0
					db 0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0
					db 0,0,0,1,1,1,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,0,0,0,0,0
					db 0,0,0,1,1,1,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,1,1,0,1,1,1,1,0,0,0,0
					db 0,0,0,1,1,1,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,1,1,0,0,1,1,1,1,0,0,0
					db 0,0,0,1,1,1,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,0,0,0,1,1,1,0,0,0,0,0,0,0,0,1,1,1,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,0,0,0,1,1,0,1,1,1,1,1,1,1,1,0,1,1,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,0,0,0,1,1,0,1,1,1,1,1,1,1,1,0,1,1,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0
					db 0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0
					db 0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

	button_save_rle db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0
					db 0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0
					db 0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0
					db 0,0,0,1,1,1,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,0,0,0,0,0
					db 0,0,0,1,1,1,0,0,0,1,1,0,0,0,1,1,1,0,0,0,0,1,1,0,1,1,1,1,0,0,0,0
					db 0,0,0,1,1,1,0,0,0,1,1,0,0,0,1,0,0,0,0,0,0,1,1,0,0,1,1,1,1,0,0,0
					db 0,0,0,1,1,1,0,0,0,1,1,0,0,0,1,0,0,0,0,0,0,1,1,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,0,0,0,1,1,0,0,0,1,1,1,0,0,0,0,1,1,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,0,0,0,1,1,1,0,0,0,0,0,0,0,0,1,1,1,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,0,0,0,1,1,0,1,1,1,1,1,1,1,1,0,1,1,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,0,0,0,1,1,0,1,1,1,1,1,1,1,1,0,1,1,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0
					db 0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0
					db 0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	
	button_8		db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

	button_24		db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0,1,1,1,0,0,0,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0,1,1,1,0,0,0,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0,1,1,1,0,0,0,0,0,0,1,1,1,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,1,1,1,0,0,0,0,0,0,1,1,1,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,1,1,1,0,0,0,0,0,0,1,1,1,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,1,1,1,0,0,0,0,0,0,1,1,1,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,1,1,1,0,0,0,0,0,0,1,1,1,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,1,1,1,0,0,0,0,0,0,1,1,1,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,1,1,1,0,0,0,0,0,0,1,1,1,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,1,1,1,0,0,0,0,0,0,1,1,1,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,1,1,1,0,0,0,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0
					db 0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0
					db 0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0
					db 0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	
	button_32		db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0
					db 0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0
					db 0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0
					db 0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0
					db 0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0
					db 0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0
					db 0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0
					db 0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
					db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

	default_palette	dd 0x000000, 0x000000, 0x00005F, 0x000080, 0x000087, 0x0000AF, 0x0000D7, 0x0000FF, 0x0000FF, 0x005F00, 0x005F5F, 0x005F87, 0x005FAF, 0x005FD7, 0x005FFF, 0x008000, 0x008080, 0x008700, 0x00875F, 0x008787, 0x0087AF, 0x0087D7, 0x0087FF, 0x00AF00, 0x00AF5F, 0x00AF87, 0x00AFAF, 0x00AFD7, 0x00AFFF, 0x00D700, 0x00D75F, 0x00D787, 0x00D7AF, 0x00D7D7, 0x00D7FF, 0x00FF00, 0x00FF00, 0x00FF5F, 0x00FF87, 0x00FFAF, 0x00FFD7, 0x00FFFF, 0x00FFFF, 0x080808, 0x121212, 0x1C1C1C, 0x262626, 0x303030, 0x3A3A3A, 0x444444, 0x4E4E4E, 0x585858, 0x5F0000, 0x5F005F, 0x5F0087, 0x5F00AF, 0x5F00D7, 0x5F00FF, 0x5F5F00, 0x5F5F5F, 0x5F5F87, 0x5F5FAF, 0x5F5FD7, 0x5F5FFF, 0x5F8700, 0x5F875F, 0x5F8787, 0x5F87AF, 0x5F87D7, 0x5F87FF, 0x5FAF00, 0x5FAF5F, 0x5FAF87, 0x5FAFAF, 0x5FAFD7, 0x5FAFFF, 0x5FD700, 0x5FD75F, 0x5FD787, 0x5FD7AF, 0x5FD7D7, 0x5FD7FF, 0x5FFF00, 0x5FFF5F, 0x5FFF87, 0x5FFFAF, 0x5FFFD7, 0x5FFFFF, 0x626262, 0x6C6C6C, 0x767676, 0x800000, 0x800080, 0x808000, 0x808080, 0x808080, 0x870000, 0x87005F, 0x870087, 0x8700AF, 0x8700D7, 0x8700FF, 0x875F00, 0x875F5F, 0x875F87, 0x875FAF, 0x875FD7, 0x875FFF, 0x878700, 0x87875F, 0x878787, 0x8787AF, 0x8787D7, 0x8787FF, 0x87AF00, 0x87AF5F, 0x87AF87, 0x87AFAF, 0x87AFD7, 0x87AFFF, 0x87D700, 0x87D75F, 0x87D787, 0x87D7AF, 0x87D7D7, 0x87D7FF, 0x87FF00, 0x87FF5F, 0x87FF87, 0x87FFAF, 0x87FFD7, 0x87FFFF, 0x8A8A8A, 0x949494, 0x9E9E9E, 0xA8A8A8, 0xAF0000, 0xAF005F, 0xAF0087, 0xAF00AF, 0xAF00D7, 0xAF00FF, 0xAF5F00, 0xAF5F5F, 0xAF5F87, 0xAF5FAF, 0xAF5FD7, 0xAF5FFF, 0xAF8700, 0xAF875F, 0xAF8787, 0xAF87AF, 0xAF87D7, 0xAF87FF, 0xAFAF00, 0xAFAF5F, 0xAFAF87, 0xAFAFAF, 0xAFAFD7, 0xAFAFFF, 0xAFD700, 0xAFD75F, 0xAFD787, 0xAFD7AF, 0xAFD7D7, 0xAFD7FF, 0xAFFF00, 0xAFFF5F, 0xAFFF87, 0xAFFFAF, 0xAFFFD7, 0xAFFFFF, 0xB2B2B2, 0xBCBCBC, 0xC0C0C0, 0xC6C6C6, 0xD0D0D0, 0xD70000, 0xD7005F, 0xD70087, 0xD700AF, 0xD700D7, 0xD700FF, 0xD75F00, 0xD75F5F, 0xD75F87, 0xD75FAF, 0xD75FD7, 0xD75FFF, 0xD78700, 0xD7875F, 0xD78787, 0xD787AF, 0xD787D7, 0xD787FF, 0xD7AF00, 0xD7AF5F, 0xD7AF87, 0xD7AFAF, 0xD7AFD7, 0xD7AFFF, 0xD7D700, 0xD7D75F, 0xD7D787, 0xD7D7AF, 0xD7D7D7, 0xD7D7FF, 0xD7FF00, 0xD7FF5F, 0xD7FF87, 0xD7FFAF, 0xD7FFD7, 0xD7FFFF, 0xDADADA, 0xE4E4E4, 0xEEEEEE, 0xFF0000, 0xFF0000, 0xFF005F, 0xFF0087, 0xFF00AF, 0xFF00D7, 0xFF00FF, 0xFF00FF, 0xFF5F00, 0xFF5F5F, 0xFF5F87, 0xFF5FAF, 0xFF5FD7, 0xFF5FFF, 0xFF8700, 0xFF875F, 0xFF8787, 0xFF87AF, 0xFF87D7, 0xFF87FF, 0xFFAF00, 0xFFAF5F, 0xFFAF87, 0xFFAFAF, 0xFFAFD7, 0xFFAFFF, 0xFFD700, 0xFFD75F, 0xFFD787, 0xFFD7AF, 0xFFD7D7, 0xFFD7FF, 0xFFFF00, 0xFFFF00, 0xFFFF5F, 0xFFFF87, 0xFFFFAF, 0xFFFFD7, 0xFFFFFF, 0xFFFFFF

section .data
	selected 	db 	0
	movemouse 	db 	0
	
	currmousex 	dd 	0
	currmousey 	dd 	0

	prevmousex 	dd 	0
	prevmousey 	dd 	0

	img 		dd 	0

	color1		dd 	0
	color2 		dd 	0
	mindist		dd 	0
	closestcol	db 	0

	new_width	dd 	0
	new_height	dd 	0

	tempb		dd 	0
	tempg 		dd 	0
	tempr 		dd 	0

	prevrle		db 	0
	cntrle		db 	0

	flt_4_0		dd 	4.0

section .bss
	img_header 	resb 54
	palette 	resb 256 * 4
