# 📡 FPGA-Based Real-Time BER Analyzer using SECDED (Hamming 7,4 Enhancement)

## Overview

This project presents a hardware-accelerated Bit Error Rate (BER) monitoring and error correction system implemented on FPGA using Verilog HDL. The design enhances the conventional Hamming (7,4) coding scheme by incorporating SECDED (Single Error Correction, Double Error Detection), enabling robust data integrity verification in real-time communication systems.

The system performs encoding, transmission monitoring, error detection, error correction, BER computation, and visualization entirely in hardware. By leveraging FPGA parallelism, the design achieves real-time performance while demonstrating practical concepts widely used in modern communication, networking, memory protection, and embedded systems.

---

## Problem Statement

Digital communication systems are highly susceptible to transmission errors caused by noise, interference, signal degradation, and environmental disturbances. Undetected or incorrectly corrected errors can significantly impact system reliability.

Traditional error control methods often focus solely on detection or correction. However, mission-critical applications such as satellite communication, ECC memory systems, automotive electronics, and high-speed networking require both robust error correction and accurate link quality monitoring.

This project addresses these challenges by integrating:

* SECDED-based error control coding
* Real-time BER monitoring
* FPGA hardware acceleration
* Live error visualization

into a unified FPGA-based solution.

---

## Objectives

* Implement Hamming (7,4) encoding and decoding in hardware.
* Enhance Hamming coding using SECDED.
* Correct single-bit transmission errors.
* Detect double-bit transmission errors.
* Calculate Bit Error Rate (BER) in real time.
* Display system status and error information on FPGA peripherals.
* Demonstrate practical FPGA-based communication system design.

---

## Key Features

### SECDED Error Control Coding

Implements Single Error Correction and Double Error Detection to improve transmission reliability.

### Real-Time BER Computation

Continuously monitors transmitted and received data streams and calculates BER during operation.

### Single-Bit Error Correction

Automatically identifies and corrects single-bit transmission errors.

### Double-Bit Error Detection

Detects double-bit errors and prevents incorrect data correction.

### Hardware-Based Processing

All operations are executed directly on FPGA hardware for low latency and high-speed performance.

### Error Visualization

Error patterns and system states are visualized through onboard LEDs.

### 7-Segment Display Output

Displays BER values, error counts, and system information in real time.

### Modular RTL Architecture

The design is divided into reusable modules for easier maintenance, testing, and scalability.

---

## System Architecture

```text
User Input
     │
     ▼
Hamming (7,4) Encoder
     │
     ▼
SECDED Parity Generator
     │
     ▼
Transmission Channel
     │
     ▼
Error Injection / Received Data
     │
     ▼
SECDED Decoder
     │
     ├── Single Error Correction
     │
     ├── Double Error Detection
     │
     ▼
BER Calculator
     │
     ▼
Display Controller
     │
     ├── LEDs
     └── 7-Segment Display
```

---

## Working Principle

### Step 1: Data Encoding

The system accepts 4-bit input data and encodes it using Hamming (7,4) coding.

### Step 2: SECDED Enhancement

An additional overall parity bit is generated to enable Single Error Correction and Double Error Detection.

### Step 3: Data Transmission

Encoded data is transmitted through a simulated communication channel.

### Step 4: Error Introduction

Single-bit and double-bit errors can be intentionally injected for testing and validation.

### Step 5: Error Detection and Correction

The decoder computes syndrome values and determines the error condition.

Possible outcomes:

* No Error
* Single-Bit Error (Corrected)
* Double-Bit Error (Detected)

### Step 6: BER Calculation

The BER engine compares transmitted and received data streams and updates error statistics continuously.

### Step 7: Visualization

Results are displayed through:

* FPGA LEDs
* 7-Segment Display
* System Status Indicators

---

## Hardware Components

| Component                      | Purpose                     |
| ------------------------------ | --------------------------- |
| FPGA Board (Nexys 4 / Artix-7) | Hardware implementation     |
| LEDs                           | Error pattern visualization |
| 7-Segment Display              | BER and status display      |
| Switches / Buttons             | Data and mode selection     |

---

## RTL Modules

### Encoder Module

* Hamming (7,4) encoding
* Parity generation

### SECDED Module

* Overall parity generation
* Extended error protection

### Decoder Module

* Syndrome computation
* Error localization
* Error correction

### BER Calculator

* Error counting
* BER computation
* Statistical analysis

### Display Controller

* LED control
* 7-segment display driving

### Mode Controller

Supports multiple operating modes:

* TX Input Mode
* Encoded Data Mode
* RX Data Mode
* Corrected Output Mode
* Error Pattern Mode
* BER Display Mode

---

## Technologies Used

### Hardware Description Language

* Verilog HDL

### FPGA Development Platform

* Nexys 4 FPGA Board
* Artix-7 FPGA

### Design Tools

* Xilinx Vivado

### Domain Knowledge

* Digital Communication
* Error Control Coding
* FPGA Design
* RTL Development

---

## Applications

### Wireless Communication Systems

Real-time BER monitoring for communication link quality evaluation.

### ECC Memory Systems

Error detection and correction similar to techniques used in RAM and cache memories.

### Satellite Communication

Reliable long-distance data transmission with error correction support.

### Automotive Electronics

Fault-tolerant embedded systems and safety-critical applications.

### High-Speed Digital Interfaces

Signal integrity validation for protocols such as:

* PCIe
* Ethernet
* Serial Communication Links

### Embedded Systems Research

Hardware-based communication performance analysis.

---

## Advantages

* Hardware-accelerated processing
* Real-time BER analysis
* Reliable SECDED implementation
* Low-latency operation
* Modular RTL architecture
* FPGA-based validation
* Industrially relevant design

---

## Results

Successfully implemented and verified:

✅ Hamming (7,4) Encoding

✅ SECDED Error Detection and Correction

✅ Single-Bit Error Correction

✅ Double-Bit Error Detection

✅ Real-Time BER Calculation

✅ FPGA Hardware Deployment

✅ LED and 7-Segment Visualization

The system accurately corrected single-bit errors, detected double-bit errors, and continuously monitored transmission quality through BER computation.

---

## Industrial Relevance

The concepts implemented in this project are widely used in:

* 5G Communication Systems
* ECC Memory Architectures
* Satellite Communication Networks
* Automotive Safety Electronics
* Data Centers
* High-Speed Networking Equipment
* Aerospace and Defense Systems

---

## Future Enhancements

* BCH and Reed-Solomon Coding
* LDPC Error Correction
* UART-Based Communication Testing
* Ethernet BER Monitoring
* Real-Time Dashboard Visualization
* AI-Assisted Error Prediction
* Hardware Performance Optimization

---

## Learning Outcomes

This project provided practical experience in:

* FPGA Design Flow
* Verilog HDL Development
* Error Control Coding
* SECDED Implementation
* Communication System Analysis
* Hardware Verification and Validation
* Xilinx Vivado Toolchain
* Real-Time Digital System Design

---

## Conclusion

The FPGA-Based Real-Time BER Analyzer using SECDED demonstrates how error control coding and communication performance monitoring can be implemented efficiently in hardware. By integrating Hamming (7,4), SECDED, real-time BER computation, and FPGA visualization, the project bridges theoretical communication concepts with industrial-grade digital system design practices.
