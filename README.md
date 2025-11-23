# riscv-embedded-systems
# RISC-V Embedded Systems – Bare-Metal Firmware Projects  
Firmware Development on SiFive FE310-G002 (RISC-V Architecture)

This repository contains a collection of **bare-metal embedded systems projects** developed on the **SiFive FE310-G002 RISC-V microcontroller**. All firmware is written in **RISC-V assembly** and runs without an operating system, directly interacting with the hardware using **memory-mapped I/O**, **register-level control**, and **interrupt-driven event handling**.

These projects demonstrate real-time embedded design, low-level firmware engineering, and precise hardware interfacing.

---

## 🚀 Projects Included

### 1. **Morse Code LED Transmitter**
- Converts ASCII characters into 16-bit Morse code patterns using a lookup table.  
- Drives an LED using dot/dash timing and bitwise pattern decoding.  
- Demonstrates subroutines, stack usage, and structured assembly design.  

### 2. **Human Reaction-Time Measurement System**
- Generates a pseudo-random start delay (2–10 seconds).  
- Turns on an LED and starts a **32-bit timer** running at 0.1 ms intervals.  
- Captures user input from a pushbutton to measure reflex speed.  
- Displays timing results via the LED bar in 8-bit segments.  
- Demonstrates real-time constraints, polling loops, and precise timing control.

### 3. **Interrupt-Driven Event Handling (Machine-Mode ISR)**
- Implements interrupt service routines (ISRs) using **RISC-V CSRs**.  
- Handles asynchronous events through the trap handler.  
- Demonstrates low-level interrupt setup, masking, clearing, and event response.  
- Highlights differences between polling and hardware-based interrupt workflows.

---

## 🛠️ Technologies & Concepts

- **RISC-V Assembly (RV32IMAC)**
- **Bare-metal firmware (no OS / no runtime)**
- **Memory-mapped I/O (GPIO control)**
- **Interrupts & trap handling**
- **Bitwise operations & pattern decoding**
- **Real-time timing loops**
- **Stack frames, subroutine calls, register preservation**
- **JTag based Hardware debugging (register tracing, breakpoints, memory inspection)**

---

## 🧰 Hardware & Tools

- **SiFive FE310-G002** (SparkFun RED-V Thing Plus)  
- **RISC-V Debugger (via PlatformIO / VS Code)**  
- **On-board GPIO, LED bar, and pushbutton inputs**  
