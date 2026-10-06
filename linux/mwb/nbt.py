"""Bounded, dependency-free reader for Java Edition's big-endian NBT."""

import gzip
import io
import struct
from pathlib import Path

MAX_BYTES = 64 * 1024 * 1024
MAX_DEPTH = 64


class NBTError(ValueError):
    pass


class Reader:
    def __init__(self, data: bytes):
        if len(data) > MAX_BYTES:
            raise NBTError("level.dat 超过读取上限")
        self.stream = io.BytesIO(data)

    def read(self, count: int) -> bytes:
        if count < 0 or count > MAX_BYTES:
            raise NBTError("NBT 长度无效")
        value = self.stream.read(count)
        if len(value) != count:
            raise NBTError("NBT 文件不完整")
        return value

    def number(self, fmt: str):
        return struct.unpack(">" + fmt, self.read(struct.calcsize(fmt)))[0]

    def string(self) -> str:
        data = self.read(self.number("H")).replace(b"\xc0\x80", b"\0")
        try:
            text = data.decode("utf-8", "surrogatepass")
            return text.encode("utf-16", "surrogatepass").decode("utf-16")
        except UnicodeError as error:
            raise NBTError("NBT 字符串编码无效") from error

    def length(self, element_size: int = 1) -> int:
        count = self.number("i")
        if count < 0 or count > MAX_BYTES // element_size:
            raise NBTError("NBT 数组长度无效")
        if count * element_size > len(self.stream.getbuffer()) - self.stream.tell():
            raise NBTError("NBT 数组不完整")
        return count

    def payload(self, tag: int, depth: int = 0):
        if depth > MAX_DEPTH:
            raise NBTError("NBT 嵌套过深")
        formats = {1: "b", 2: "h", 3: "i", 4: "q", 5: "f", 6: "d"}
        if tag in formats:
            return self.number(formats[tag])
        if tag == 7:
            return self.read(self.length())
        if tag == 8:
            return self.string()
        if tag == 9:
            element = self.number("B")
            count = self.length()
            if element == 0 and count:
                raise NBTError("NBT 列表类型无效")
            return [self.payload(element, depth + 1) for _ in range(count)]
        if tag == 10:
            result = {}
            while True:
                child = self.number("B")
                if child == 0:
                    return result
                name = self.string()
                result[name] = self.payload(child, depth + 1)
        if tag in (11, 12):
            fmt, size = ("i", 4) if tag == 11 else ("q", 8)
            return [self.number(fmt) for _ in range(self.length(size))]
        raise NBTError(f"不支持的 NBT 类型：{tag}")

    def root(self) -> dict:
        if self.number("B") != 10:
            raise NBTError("NBT 根节点不是 Compound")
        self.string()
        return self.payload(10)


def read_level(path: Path) -> dict:
    with gzip.open(path, "rb") as stream:
        data = stream.read(MAX_BYTES + 1)
    root = Reader(data).root()
    value = root.get("Data", root)
    if not isinstance(value, dict):
        raise NBTError("NBT Data 节点不是 Compound")
    return value
