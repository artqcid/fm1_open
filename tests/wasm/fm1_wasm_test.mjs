/* SPDX-License-Identifier: GPL-3.0-only WITH GPL-3.0-linking-exception */
/* Behaviour checks for the WebAssembly simulator (T-30).
 *
 * Loads build/web/simulator.wasm through the FM1SimulatorCore class defined by
 * sdk/Simulator.js, then drives the same sim_* boundary the browser uses.
 * No npm dependencies: `node tests/wasm/fm1_wasm_test.mjs`.
 */
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const wasmPath = path.join(root, 'build', 'web', 'simulator.wasm');
const simulatorPath = path.join(root, 'sdk', 'Simulator.js');

if (!fs.existsSync(wasmPath))
    throw new Error(`missing ${wasmPath} - run "build.bat --web" first`);
if (!fs.existsSync(simulatorPath))
    throw new Error(`missing ${simulatorPath}`);

let failures = 0;
const check = (condition, text) => {
    if (!condition) {
        console.error(`FAIL: ${text}`);
        ++failures;
    }
};
const rejects = (fn, text) => {
    let error;
    try {
        fn();
    } catch (caught) {
        error = caught;
    }
    check(error?.constructor === Error, text);
};

const crcTable = new Uint32Array(256);
for (let n = 0; n < 256; ++n) {
    let c = n;
    for (let bit = 0; bit < 8; ++bit)
        c = (c & 1) ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    crcTable[n] = c >>> 0;
}
const crc32 = (bytes, start, end) => {
    let c = 0xffffffff;
    for (let i = start; i < end; ++i)
        c = crcTable[(c ^ bytes[i]) & 0xff] ^ (c >>> 8);
    return (c ^ 0xffffffff) >>> 0;
};
const readU32 = (bytes, at) =>
    (bytes[at] | (bytes[at + 1] << 8) | (bytes[at + 2] << 16) | (bytes[at + 3] << 24)) >>> 0;
const writeU32 = (bytes, at, value) => {
    bytes[at] = value & 0xff;
    bytes[at + 1] = (value >>> 8) & 0xff;
    bytes[at + 2] = (value >>> 16) & 0xff;
    bytes[at + 3] = (value >>> 24) & 0xff;
};
const equalBytes = (a, b) =>
    a.length === b.length && a.every((value, index) => value === b[index]);

vm.runInThisContext(fs.readFileSync(simulatorPath, 'utf8'), { filename: simulatorPath });
check(typeof globalThis.FM1SimulatorCore === 'function', 'FM1SimulatorCore exposed');

const wasm = fs.readFileSync(wasmPath);
const module = new WebAssembly.Module(wasm);
check(WebAssembly.Module.imports(module).length === 0, 'simulator has no imports');

const core = new globalThis.FM1SimulatorCore(wasm);
check(core.c.sim_block_frames() === 128, 'init: block frames');
const initial = core.frame(true);
check(initial.state.length === 225, 'init: state export');
check(initial.pixels && initial.pixels.length === 57600, 'init: pixel export');
check(typeof initial.workspace.name === 'string', 'init: workspace export');

/* Documented boundary rejects. */
rejects(() => core.command({ type: 'midi', data: new Uint8Array(1025) }),
       'reject oversized MIDI');
rejects(() => core.command({ type: 'import', data: new Uint8Array(100) }),
       'reject wrong-length project');
rejects(() => core.command({ type: 'import', patch: true, data: new Uint8Array(155) }),
       'reject wrong-length patch');
rejects(() => core.command({ type: 'samples', data: new Uint8Array(511) }),
       'reject undersized sample bank');
rejects(() => core.command({ type: 'library-write', bank: 0, data: new Uint8Array(4095) }),
       'reject wrong-length library bank');

/* A sequencer edit must be visible in the exported project bytes. */
const before = core.command({ type: 'export' });
const beforeRevision = core.projectRevision();
core.command({ type: 'step', index: 0, toggle: true });
const after = core.command({ type: 'export' });
check(core.projectRevision() !== beforeRevision, 'step edit changes revision');
check(!equalBytes(before, after), 'step edit visible in export');

/* Tuning imports must round-trip through the trailing 200-byte block. */
const factory = core.command({ type: 'factory', index: 0 });
check(factory.length === 4264, 'factory project export length');
const tuningAt = 4064;
check(readU32(factory, tuningAt) === 0x54314d46, 'factory tuning magic');

const tuned = new Uint8Array(factory);
tuned[tuningAt + 4] = 5;        /* t[0].main[0] */
tuned[tuningAt + 4 + 12 + 11] = 0x81; /* t[0].alt[11] = -127 */
writeU32(tuned, tuningAt + 196, crc32(tuned, tuningAt, tuningAt + 196));
core.command({ type: 'import', data: tuned });
const exported = core.command({ type: 'export' });
check(exported[tuningAt + 4] === 5, 'tuning main round-trip');
check(exported[tuningAt + 4 + 12 + 11] === 0x81, 'tuning alt round-trip');

const invalid = new Uint8Array(factory);
invalid[tuningAt + 4] = 0x80;   /* -128 is reserved */
writeU32(invalid, tuningAt + 196, crc32(invalid, tuningAt, tuningAt + 196));
rejects(() => core.command({ type: 'import', data: invalid }),
       'reject -128 tuning');

if (failures) {
    console.error(`${failures} WASM check(s) failed`);
    process.exit(1);
}
console.log('WASM checks passed');
