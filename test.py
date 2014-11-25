
# constants for IEEE bitreversed
R1 = 0x0000000154442bd4
R2 = 0x00000001c6e415960
R3 = 0x00000001751997d0 
R4 = 0x00000000ccaa009e
R5 = 0x0000000163cd6124
R6 = 0x00000001DB710641
mu = 0x00000001F7011641
mask32 = 0xFFFFFFFF


# From trailing alignment 4 bytes over
#(gdb) p/x $xmm1.uint128
#$39 = 0x1f1e1d1c1950a23b03b0d2c3b14ad950
X1 = 0x1f1e1d1c1950a23b03b0d2c3b14ad950
#(gdb) p/x $xmm2.uint128
#$40 = 0x1f1e1d1c1b1a19181716151413121110
X2 = 0x1f1e1d1c1b1a19181716151413121110

Y1 = X1<<32 | (X2&0xffffffff)
Y2 = (X2&0xffffffff) << 128 | X1


def mycrc(n, poly, crc=0):
  crc ^= n
  while n:
    if n & 1:
      crc ^= poly
    crc >>= 1
    n >>= 1
  # 32 shift
  return crc

def bitrev(n, p):
   r = 0
   for i in range(p):
     r = (r<<1) | (n&1)
     n >>= 1
   return r

def byte2poly(b):
  'read bit reversed data into big int'
  l = 0
  p = 0
  for x in b:
    for i in range(8):
      p = (p << 1) | ((x>>i)&1)
  return p, 8*len(b)

def mod(M, m, P, n):
  for s in range(m-1,n-2,-1):
    if M & (1<<s):
      M ^= (P << (s-n+1))
      if M & (1<<s):
        print "xor error"
  return M

def div(M, m, P, n):
  d = 0
  for s in range(m-1,n-2,-1):
    if M & (1<<s):
      M ^= (P << (s-n+1))
      d |= (1 << (s-n+1))
      if M & (1<<s):
        print "xor error"
  return d

def mul(A, a, B, b):
  c = 0
  while B:
    if B & 1:
      c = (c<<1) ^ A
    else:
      c = (c<<1)
    B >>= 1
  return c


from binascii import crc32 as _crc32
crc32 = lambda x: ((~_crc32(x, -1))+(1<<32))&0xffffffff
poly = 0xedb88320
P, p = byte2poly([0x20, 0x83, 0xb8, 0xed])
P |= (1<<32)
p += 1

b = range(16)
M, m = byte2poly(b)
M <<= 32
m += 32

print crc32(''.join(map(chr,b)))
print bitrev(mod(M,m,P,p),32)

print 'P`=', hex(bitrev( P, 33 ))
print 'K1=', hex(bitrev( mod(1<<(4*128+32), 4*128+32+1, P, p) << 32, 64) << 1)
print 'K2=', hex(bitrev( mod(1<<(4*128-32), 4*128-32+1, P, p) << 32, 64) << 1)
print 'K3=', hex(bitrev( mod(1<<(128+32), 128+32+1, P, p) << 32, 64) << 1)
print 'K4=', hex(bitrev( mod(1<<(128-32), 128-32+1, P, p) << 32, 64) << 1)
print 'K5=', hex(bitrev( mod(1<<64, 64+1, P, p), 32) << 1)
print 'K6=', hex(bitrev( mod(1<<32, 32+1, P, p), 32) << 1)
print 'u`=', hex(bitrev( div(1<<64, 65, P, p), 33))
