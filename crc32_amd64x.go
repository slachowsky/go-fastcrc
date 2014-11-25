// Copyright 2011 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build amd64 amd64p32

package crc32

// This file contains the code to call the SSE 4.2 version of the Castagnoli
// CRC.

// haveSSE42 is defined in crc_amd64.s and uses CPUID to test for SSE 4.2
// support.
func haveSSE42() bool

// castagnoliSSE42 is defined in crc_amd64.s and uses the SSE4.2 CRC32
// instruction.
func castagnoliSSE42(crc uint32, p []byte) uint32

var sse42 = haveSSE42()

func updateCastagnoli(crc uint32, p []byte) uint32 {
	if sse42 {
		return castagnoliSSE42(crc, p)
	}
	return update(crc, castagnoliTable, p)
}

func crcFastIEEE(crc uint32, tab *Table, p []byte) uint32

var fastIEEETable Table = Table{
	0x54442bd4,
	0x00000001,
	0xc6e41596,
	0x00000001,

	0x751997d0,
	0x00000001,
	0xccaa009e,
	0x00000000,

	0x63cd6124,
	0x00000001,
	0x00000000,
	0x00000000,

	0xFFFFFFFF,
	0x00000000,
	0x00000000,
	0x00000000,

	0xDB710641,
	0x00000001,
	0xF7011641,
	0x00000001,
}

func ChecksumFastIEEE(p []byte) uint32 {
	var crc uint32
	if len(p) >= 16 {
		l := len(p) - (len(p) & 15)
		crc = crcFastIEEE(crc, &fastIEEETable, p[:l])
		p = p[l:]
	}
	// fixup trailing
	crc = update(crc, IEEETable, p)
	return crc
}
