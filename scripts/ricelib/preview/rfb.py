#!/usr/bin/env python3
"""Grab the guest's screen over VNC, from the host, with nothing installed in the guest.

Why not `grim` inside the guest: it hangs. A screencopy request only completes when the
compositor produces a frame, and a guest whose display nobody is watching produces none. The
same trap catches a nested compositor whose window is hidden. Capturing from outside removes
the dependency entirely.

Why not QEMU's own `screendump`: with `-display egl-headless` the scanout is a GL texture and
QEMU answers `no surface`. Measured on QEMU 11.0.3.

So the capture speaks RFB to the same VNC port a person would connect to, which has the useful
property that what the agent sees is exactly what the user sees. Raw encoding only, because the
image is decoded here and a preview is a handful of frames, not a video stream.
"""
import socket
import struct
import time
import zlib

__all__ = ["capture", "RfbError"]


class RfbError(Exception):
    """The capture could not be completed."""


def _recvn(sock, n):
    buf = b""
    while len(buf) < n:
        chunk = sock.recv(n - len(buf))
        if not chunk:
            raise RfbError("connection closed mid-message")
        buf += chunk
    return buf


def _png(width, height, rows):
    """A minimal PNG writer. No dependency worth taking for one image per screenshot."""
    def chunk(tag, data):
        return (struct.pack(">I", len(data)) + tag + data
                + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))
    return (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(rows, 6))
            + chunk(b"IEND", b""))


def capture(host, port, path, timeout=30):
    """Connect, pull one full frame, write a PNG. Returns (width, height).

    The request is non-incremental, so the server sends the whole framebuffer rather than a
    delta against a history this client does not keep."""
    try:
        sock = socket.create_connection((host, port), timeout=timeout)
    except OSError as exc:
        raise RfbError(f"could not connect to {host}:{port}: {exc}") from exc

    try:
        sock.settimeout(timeout)
        _recvn(sock, 12)
        sock.sendall(b"RFB 003.008\n")

        count = _recvn(sock, 1)[0]
        if count == 0:
            reason_len = struct.unpack(">I", _recvn(sock, 4))[0]
            raise RfbError(_recvn(sock, reason_len).decode("utf-8", "replace"))
        types = _recvn(sock, count)
        if 1 not in types:
            raise RfbError("the VNC server requires authentication; preview binds without it")
        sock.sendall(bytes([1]))
        if struct.unpack(">I", _recvn(sock, 4))[0] != 0:
            raise RfbError("VNC security handshake failed")

        sock.sendall(bytes([1]))                      # shared session
        header = _recvn(sock, 24)
        width, height = struct.unpack(">HH", header[:4])
        name_len = struct.unpack(">I", header[20:24])[0]
        _recvn(sock, name_len)
        if width == 0 or height == 0:
            raise RfbError("the guest reports a zero-sized framebuffer")

        # 32bpp true colour, little-endian, so a pixel is B,G,R,x in memory order.
        sock.sendall(struct.pack(">BBBB", 0, 0, 0, 0)
                     + struct.pack(">BBBBHHHBBBBBB",
                                   32, 24, 0, 1, 255, 255, 255, 16, 8, 0, 0, 0, 0))
        sock.sendall(struct.pack(">BBHi", 2, 0, 1, 0))          # encodings: raw
        sock.sendall(struct.pack(">BBHHHH", 3, 0, 0, 0, width, height))

        fb = bytearray(width * height * 4)
        covered = 0
        deadline = time.time() + timeout
        while covered < width * height:
            if time.time() > deadline:
                raise RfbError("timed out waiting for a full frame from the guest")
            if _recvn(sock, 1)[0] != 0:                          # FramebufferUpdate only
                continue
            _recvn(sock, 1)
            for _ in range(struct.unpack(">H", _recvn(sock, 2))[0]):
                rx, ry, rw, rh, enc = struct.unpack(">HHHHi", _recvn(sock, 12))
                if enc != 0:
                    raise RfbError(f"server used encoding {enc}; only raw was offered")
                data = _recvn(sock, rw * rh * 4)
                for row in range(rh):
                    dst = ((ry + row) * width + rx) * 4
                    fb[dst:dst + rw * 4] = data[row * rw * 4:(row + 1) * rw * 4]
                covered += rw * rh
    finally:
        sock.close()

    rows = bytearray()
    for y in range(height):
        rows.append(0)                                           # PNG filter: none
        line = fb[y * width * 4:(y + 1) * width * 4]
        for x in range(width):
            rows += bytes((line[x * 4 + 2], line[x * 4 + 1], line[x * 4]))

    with open(path, "wb") as fh:
        fh.write(_png(width, height, bytes(rows)))
    return width, height
