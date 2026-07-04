import struct, zlib, os

def make_png(width, height, color=(0,122,255)):
    def chunk(name, data):
        c = name + data
        crc = struct.pack('>I', zlib.crc32(c) & 0xffffffff)
        return struct.pack('>I', len(data)) + c + crc
    raw = b''
    for y in range(height):
        for x in range(width):
            raw += bytes(color)
    ihdr = struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)
    return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', ihdr) + chunk(b'IDAT', zlib.compress(raw)) + chunk(b'IEND', b'')

icon = make_png(1024, 1024, (0, 122, 255))
out = '/Users/MAC/Documents/GitHub/ThreadMapper/ThreadMapper/Assets.xcassets/AppIcon.appiconset/AppIcon.png'
os.makedirs(os.path.dirname(out), exist_ok=True)
with open(out, 'wb') as f:
    f.write(icon)
print(out)
