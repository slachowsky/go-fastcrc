#if 0
// Copyright 2011 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//#include "../../../cmd/ld/textflag.h"
#define NOSPLIT 4

// func castagnoliSSE42(crc uint32, p []byte) uint32
TEXT ·castagnoliSSE42(SB),NOSPLIT,$0
	MOVL crc+0(FP), AX  // CRC value
	MOVQ p+8(FP), SI  // data pointer
	MOVQ p_len+16(FP), CX  // len(p)

	NOTL AX

	/* If there's less than 8 bytes to process, we do it byte-by-byte. */
	CMPQ CX, $8
	JL cleanup

	/* Process individual bytes until the input is 8-byte aligned. */
startup:
	MOVQ SI, BX
	ANDQ $7, BX
	JZ aligned

	CRC32B (SI), AX
	DECQ CX
	INCQ SI
	JMP startup

aligned:
	/* The input is now 8-byte aligned and we can process 8-byte chunks. */
	CMPQ CX, $8
	JL cleanup

	CRC32Q (SI), AX
	ADDQ $8, SI
	SUBQ $8, CX
	JMP aligned

cleanup:
	/* We may have some bytes left over that we process one at a time. */
	CMPQ CX, $0
	JE done

	CRC32B (SI), AX
	INCQ SI
	DECQ CX
	JMP cleanup

done:
	NOTL AX
	MOVL AX, ret+32(FP)
	RET

// func haveSSE42() bool
TEXT ·haveSSE42(SB),NOSPLIT,$0
	XORQ AX, AX
	INCL AX
	CPUID
	SHRQ $20, CX
	ANDQ $1, CX
	MOVB CX, ret+0(FP)
	RET

// func havePCLMULQDQ() bool
TEXT ·havePCLMULQDQ(SB),NOSPLIT,$0
	XORQ AX, AX
	INCL AX
	CPUID
	SHRQ $4, CX
	ANDQ $1, CX
	MOVB CX, ret+0(FP)
	RET

// func crcIEEE(crc uint32, p []byte) uint32
//TEXT ·crcIEEE(SB),NOSPLIT,$0
////Fold_by_1_loop: // for(i=rax-1; i>0 ; i--) {
//	//MOVDQA X2, X1 // xmm2 = xmm1;
//	MOVQ X2, X1 // xmm2 = xmm1;
//	ADDQ $16, CX // buf += 16
//	//MOVDQA X0, [rCX] // xmm0 = buf;
//	//PSHUFB X0, [SHUF_MASK] // endianness swap if required
//	//PCLMULQDQ X1, X3, 0x00 // xmm1 = clmul(xmm1 , K2)
//	//PCLMULQDQ X2, X3, $0x11 // xmm2 = clmul(xmm2 , K1)
//	PCLMULQDQ $0x11, X2, X3 // xmm2 = clmul(xmm2 , K1)
//	PXOR X0, X1 // xmm0 = xmm0  xmm1
//	//PXOR X0, X2 // xmm0 = xmm0  xmm2
//	//MOVDQA X1, X0 // xmm1 = xmm0
//	//SUB rax, $1
//	//JNE Fold_by_1_loop // }
////SHUF_MASK : DDQ 000102030405060708090A0B0C0D0E0Fh
////xmm3 : K1|K2
////
#endif


#define CONSTANT %xmm0

#define BUF     %rdi
#define LEN     %rsi
#define CRC     %edx
 

.data
	.align 16
        v1: .float 1.1, 2.2, 3.3, 4.4
        v2: .float 5.5, 6.6, 7.7, 8.8
        v3: .float 0, 0, 0, 0
// k1 = x 4*128+64 mod P(x) = 0x8833794C
// k2 = x 4*128 mod P(x) = 0xE6228B11
// k3 = x 128+64 mod P(x) = 0xC5B9CD4C
// k4 = x 128 mod P(x) = 0xE8A45605
// k5 = x 96 mod P(x) = 0xF200AA66
// k6 = x 64 mod P(x) = 0x490D678D
// mu = x 64/P(x) = 0x104D101DF
	k1: .long 0x8833794c
	k2: .long 0xE6228B11
	k3: .long 0xC5B9CD4C
	k4: .long 0xE8A45605
	k5: .long 0xF200AA66
	k6: .long 0x490D678D
	mu: .long 0x04D101DF
// Bit-reflected constants: 
// P(x)’ = 0x1DB710641
// k1’ = (x 4*128+32 mod P(x) << 32)’ << 1 = 0x154442bd4
// k2’ = (x 4*128-32 mod P(x) << 32)’ << 1 = 0x1c6e41596
// k3’ = (x 128+32 mod P(x) << 32)’ << 1 = 0x1751997d0
// k4’ = (x 128-32 mod P(x) << 32)’ << 1 = 0x0ccaa009e
// k5’ = (x 64 mod P(x) << 32)’ << 1 = 0x163cd6124
// k6’ = (x 32 mod P(x) << 32)’ << 1 = 0x1db710640
// mu’ = (x 64/P(x))’ = 0x1F7011641

	.align 16
	R2R1: .octa 0x00000001c6e415960000000154442bd4
	R4R3: .octa 0x00000000ccaa009e00000001751997d0 
	R5: .octa 0x00000000000000000000000163cd6124
	mask32: .octa 0x000000000000000000000000FFFFFFFF
	RUpoly: .octa 0x00000001F701164100000001DB710641
 
 
.text
.global func 
func:

	movdqa  (BUF), %xmm1
//	movdqa  0x10(BUF), %xmm2
//	movdqa  0x20(BUF), %xmm3
//	movdqa  0x30(BUF), %xmm4
	NOT	CRC
	movd    CRC, CONSTANT
	pxor    CONSTANT, %xmm1

//	movdqa R2R1, CONSTANT
//4*128 loop

	movdqa  R4R3, CONSTANT

loop_fold128:
	cmp $16, LEN
	jle last

	add	$16, BUF
	sub	$16, LEN

	movdqa	(BUF), %xmm2

	movdqa  %xmm1, %xmm5
	PCLMULQDQ $0x00, CONSTANT, %xmm1
	PCLMULQDQ $0x11, CONSTANT, %xmm5
	pxor    %xmm5, %xmm1
	pxor    %xmm2, %xmm1

	jmp loop_fold128

last:
/* perform the last 64 bit fold, also adds 32 zeroes
 * to the input stream */
	PCLMULQDQ $0x01, %xmm1, CONSTANT /* R4 * xmm1.low */
	psrldq  $0x08, %xmm1
	pxor    CONSTANT, %xmm1

/* final 32-bit fold */
	movdqa  %xmm1, %xmm2

	movdqa  R5, CONSTANT
	movdqa  mask32, %xmm3

	psrldq  $0x04, %xmm2
	pand    %xmm3, %xmm1
	PCLMULQDQ $0x00, CONSTANT, %xmm1
	pxor    %xmm2, %xmm1

/* Finish up with the bit-reversed barrett reduction 64 ==> 32 bits */
	movdqa  RUpoly, CONSTANT
	movdqa  %xmm1, %xmm2
	pand    %xmm3, %xmm1
	PCLMULQDQ $0x10, CONSTANT, %xmm1
	pand    %xmm3, %xmm1
	PCLMULQDQ $0x00, CONSTANT, %xmm1
	pxor    %xmm2, %xmm1
	PEXTRD  $0x01, %xmm1, %eax

	NOT %eax
	ret
