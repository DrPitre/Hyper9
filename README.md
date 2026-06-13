# Hyper9

Hyper9 is a [Turbo9 microprocessor](http://www.turbo9.org/) simulator written in Swift. It provides a full-featured macOS debugger and an SPM library that also builds on Linux.

![Screenshot of Hyper9 running TurbOS on macOS.](assets/Hyper9.png)

---

## Features

- Full Turbo9 / 6809 CPU emulation — all addressing modes, all instructions, three opcode pages
- Integrated disassembler with symbol table support (`.map` files)
- Interactive terminal with keyboard input, blinking cursor, and scrollable history
- Live register, memory, and disassembly views that update while the CPU runs
- Breakpoint manager
- Timer and interrupt injection (IRQ, FIRQ, NMI)
- Instruction and clock-cycle statistics
- File logging via CocoaLumberjack
- Cross-platform: macOS GUI app + `hyper9-cmd` command-line tool (Linux / Terminal)

---

## Requirements

- **macOS app**: Xcode 15+, macOS 14+
- **SPM / CLI**: Swift 5.9+, macOS or Linux

---

## Building

### macOS app

Open `Hyper9.xcodeproj` in Xcode and press **⌘R**.

### Command-line tool (macOS / Linux)

```bash
swift build -c release
.build/release/hyper9-cmd <image.img>
```

### Run tests

```bash
cd Hyper9/Turbo9Sim
swift test
```

---

## Usage

### macOS app

1. Launch Hyper9.
2. Click the **folder** button in the Control bar to load a `.img` binary image.
3. Press **▶** to run, **⏸** to pause.
4. Click the **Terminal** tab and click inside the terminal area to give it keyboard focus (border turns green). Type commands and press Return.
5. Use **→** (step into) or **↓** (step) to execute one instruction at a time.
6. The **Memory** view shows 512 bytes around the current PC; it refreshes on each pause or step.

### hyper9-cmd

```bash
hyper9-cmd turbos.img
```

Keyboard input is read directly from stdin in raw mode. Press **Ctrl-C** to exit.

---

## Architecture

```
Hyper9 (macOS app — SwiftUI)
  └─ Turbo9ViewModel          observable bridge between CPU and UI
  └─ DocumentView / ControlView / TerminalView / MemoryView / …

Turbo9Sim (SPM library)
  ├─ Turbo9CPU                fetch-decode-execute, interrupts, registers
  ├─ Bus                      64 KB address space, memory-mapped I/O handlers
  ├─ CPU+*.swift              one file per instruction group (ADD, SUB, Branch…)
  ├─ Disassembler             extends Turbo9CPU; produces Turbo9Operation values
  └─ Extensions               UInt8/16 bit helpers, String hex formatting

hyper9-cmd (SPM executable)
  └─ main.swift               raw-mode stdin, timer loop, I/O handlers
```

The SPM package (`Hyper9/Turbo9Sim/Package.swift`) exposes `Turbo9Sim` as a library so other projects can embed the simulator without the GUI.

---

## Memory I/O Map

| Address | Description |
|---------|-------------|
| `$0000–$FEFF` | RAM |
| `$FF00` | **Terminal Output** — write a byte to emit a character |
| `$FF01` | **Terminal Input** — write a byte to deliver a character; read to retrieve it |
| `$FF02` | **IRQ Status** — bit 0: timer IRQ pending; bit 1: input IRQ pending (write 1 to a bit to clear it) |
| `$FF03` | **IRQ Control** — bit 0: enable timer IRQ; bit 1: enable input IRQ |
| `$FFF0–$FFFF` | Interrupt vectors (RESET at `$FFFE`) |

---

## Running TurbOS

[TurbOS](http://www.turbo9.org/) is a multi-tasking OS for the Turbo9. Load `turbos.img`, press run, and interact via the Terminal tab. Useful shell commands:

| Command | Description |
|---------|-------------|
| `mdir` | List files in the current directory |
| `mdir -e` | Extended directory listing |
| `procs` | Show running processes |
| `mfree` | Show free memory |
| `shell` | Start a new shell |

---

## License

See [LICENSE](LICENSE) for details.
