#!/usr/bin/env python3
import argparse
import json
import struct
import sys


class Node:
    def __init__(self, parent=None):
        self.parent = parent
        self.props = {}
        self.order = []
        self.children = []

    @property
    def name(self):
        v = self.props.get("name", b"")
        return v.split(b"\0")[0].decode(errors="replace")

    def path(self):
        parts = []
        n = self
        while n.parent is not None:
            parts.append(n.name)
            n = n.parent
        return "/" + "/".join(reversed(parts))

    def u32(self, key, default=None):
        v = self.props.get(key)
        if v is None or len(v) < 4:
            return default
        return struct.unpack_from("<I", v)[0]

    def strings(self, key):
        v = self.props.get(key)
        if not v:
            return []
        return [s.decode(errors="replace") for s in v.split(b"\0") if s]

    def walk(self):
        yield self
        for c in self.children:
            yield from c.walk()


def parse(data):
    def node(off, parent):
        n = Node(parent)
        nprops, nchildren = struct.unpack_from("<II", data, off)
        off += 8
        for _ in range(nprops):
            name = data[off:off + 32].split(b"\0")[0].decode(errors="replace")
            size = struct.unpack_from("<I", data, off + 32)[0]
            off += 36
            ln = size & 0x7FFFFFFF
            n.props[name] = data[off:off + ln]
            n.order.append(name)
            off += (ln + 3) & ~3
        for _ in range(nchildren):
            c, off = node(off, n)
            n.children.append(c)
        return n, off

    root, _ = node(0, None)
    return root


def load(path):
    data = open(path, "rb").read()
    if data[:2] == b"\x30\x82" or data[:2] == b"\x30\x83" or data[:2] == b"\x30\x84":
        sys.exit("im4p input: extract first with `ipsw img4 im4p extract -o out.adt file.im4p`")
    return parse(data)


def cells(v, n):
    out = 0
    for i in range(n):
        out |= struct.unpack_from("<I", v, i * 4)[0] << (32 * i)
    return out


def translate(node, addr):
    n = node.parent
    while n is not None and n.parent is not None:
        ranges = n.props.get("ranges")
        if ranges:
            ca = n.u32("#address-cells", 2)
            pa = n.parent.u32("#address-cells", 2)
            cs = n.u32("#size-cells", 2)
            step = 4 * (ca + pa + cs)
            for i in range(0, len(ranges) - step + 1, step):
                child = cells(ranges[i:], ca)
                parent = cells(ranges[i + 4 * ca:], pa)
                size = cells(ranges[i + 4 * (ca + pa):], cs)
                if child <= addr < child + size:
                    addr = addr - child + parent
                    break
        n = n.parent
    return addr


def regs(node):
    v = node.props.get("reg")
    if not v or node.parent is None:
        return []
    p = node.parent
    if p.strings("device_type") == ["i2c"]:
        return []
    ac = p.u32("#address-cells", p.u32("#address-cels"))
    sc = p.u32("#size-cells")
    if ac is None or sc is None or ac > 2 or sc > 2:
        return []
    step = 4 * (ac + sc)
    if step == 0:
        return []
    out = []
    for i in range(0, len(v) - step + 1, step):
        a = cells(v[i:], ac)
        s = cells(v[i + 4 * ac:], sc)
        out.append((translate(node, a), s))
    return out


def phandles(root):
    return {n.u32("AAPL,phandle"): n for n in root.walk() if "AAPL,phandle" in n.props}


def fmt(key, v):
    if not v:
        return "<empty>"
    s = v.rstrip(b"\0")
    if s and all(32 <= c < 127 or c == 0 for c in s) and (len(s) > 1 or v[-1:] == b"\0"):
        parts = [p.decode() for p in s.split(b"\0")]
        if all(parts):
            return ", ".join('"%s"' % p for p in parts)
    if len(v) % 4 == 0 and len(v) <= 64:
        return " ".join("%08x" % x for x in struct.unpack("<%dI" % (len(v) // 4), v))
    if len(v) <= 64:
        return v.hex()
    return v[:64].hex() + "... (%d bytes)" % len(v)


def describe(node, ph, verbose):
    lines = []
    for a, s in regs(node):
        lines.append("reg      %#012x +%#x" % (a, s))
    if node.parent is not None and node.parent.strings("device_type") == ["i2c"] and "reg" in node.props:
        lines.append("i2c-addr %#x" % node.u32("reg"))
    ip = node.u32("interrupt-parent")
    irqs = node.props.get("interrupts")
    if irqs:
        nums = struct.unpack("<%dI" % (len(irqs) // 4), irqs[:len(irqs) & ~3])
        par = ph.get(ip)
        lines.append("irq      %s -> %s" % (" ".join(str(x) for x in nums), par.name if par else "?"))
    for key in node.order:
        if key in ("name", "reg", "interrupts", "interrupt-parent", "AAPL,phandle"):
            continue
        if not verbose and key not in ("compatible", "device_type", "function-power-gate", "clock-gates", "power-gates", "clock-ids", "AAPL,unit-string") and not key.startswith("function-"):
            continue
        lines.append("%-8s %s" % (key, fmt(key, node.props[key])))
    return lines


def functions(node, ph):
    out = []
    for key in node.order:
        if not key.startswith("function-"):
            continue
        v = node.props[key]
        if len(v) < 8:
            continue
        p = struct.unpack_from("<I", v)[0]
        tag = v[4:8][::-1].decode(errors="replace")
        args = struct.unpack_from("<%dI" % ((len(v) - 8) // 4), v, 8)
        tgt = ph.get(p)
        out.append((key, tgt.path() if tgt else "%#x" % p, tag, args))
    return out


def cmd_dump(root, args):
    ph = phandles(root)
    for n in root.walk():
        depth = n.path().count("/") - 1 if n.parent else 0
        if args.match and not any(m in n.path() or m in ",".join(n.strings("compatible")) for m in args.match):
            continue
        ind = "  " * depth
        print("%s%s" % (ind, n.path() if args.match else n.name or "/"))
        for line in describe(n, ph, args.verbose):
            print("%s    %s" % (ind, line))
        for key, tgt, tag, a in functions(n, ph):
            print("%s    %-8s %s %s %s" % (ind, key, tgt, tag, " ".join("%#x" % x for x in a)))


def cmd_map(root, args):
    rows = []
    for n in root.walk():
        for a, s in regs(n):
            if a >= 0x200000000:
                rows.append((a, s, n.path(), ",".join(n.strings("compatible"))))
    for a, s, p, c in sorted(rows):
        print("%#012x %#10x  %-48s %s" % (a, s, p, c))


def cmd_json(root, args):
    def conv(n):
        d = {k: fmt(k, n.props[k]) for k in n.order}
        r = regs(n)
        if r:
            d["@reg"] = ["%#x+%#x" % x for x in r]
        if n.children:
            d["@children"] = {c.name: conv(c) for c in n.children}
        return d

    json.dump(conv(root), sys.stdout, indent=1)


def main():
    ap = argparse.ArgumentParser(description="Apple device tree (ADT) dumper")
    ap.add_argument("adt")
    sub = ap.add_subparsers(dest="cmd")
    d = sub.add_parser("dump")
    d.add_argument("-v", "--verbose", action="store_true")
    d.add_argument("match", nargs="*")
    sub.add_parser("map")
    sub.add_parser("json")
    args = ap.parse_args()
    root = load(args.adt)
    {"dump": cmd_dump, "map": cmd_map, "json": cmd_json, None: cmd_dump}[args.cmd](root, args if args.cmd else argparse.Namespace(match=[], verbose=False))


if __name__ == "__main__":
    main()
