# Networking Pocket Serial Terminal
## My Master's thesis project.

It is a handheld serial terminal intended for direct connection to serial ports, that can be found on enterprise level networking equipment for on-site debugging/configuration/monitoring different parameters of the equipment. It is designated to replace the neef for a computer that network engineers have to use in order to setup said kind of equipment. 

### Architecture
The device is based on FPGA technology, ensuring low power consumption and realibility

* FPGA - XC7A100T-1FGG676C, placed on a [development kit](https://github.com/ChinaQMTECH/QM_XC7A100T_WUKONG_BOARD) from QMTECH
* Peripherals - Display, Keyboard, Serial ports (RS232/UART)
* Battery?
* Daughter board for connecting different peripherals
* For testing and demo purposes I'll be using MikroTik RouterBoard RB433

### Tasks
- [x] Collect the development kit
- [x] Setup work environment
- [x] Implement PS/2 Communication
- [x] Handle keyboard inputs
- [x] Setup a simple logic that controls onboard LEDS from keyboard input
- [x] Select a proper display
- [x] Design a daughter board that houses all peripheral devices and connections
- [x] Setup serial interface and confirm that it works.
- [ ] ~~Implement onboard DDR3 memory R/W functions~~
- [ ] ~~Select EEPROM memory for storing font characters~~
- [ ] ~~Implement EEPROM memory read function~~
> From recent developments, difficulties in understanding the xylix IP-s, lack of technical time I opted out the RAM/EEPROM implementations in favor to BRAM blocks for storing and managing frame buffer for the display, font data and other user data.
- [x] Design a testing entity that cycles RGBW colors on the display to confirm proper work of the hardware.
- [ ] Extend testing entity to a working display driver by fetch monochrome data (pixel state on/off) from a frame buffer and visualize it on the display.
- [ ] Design a frame buffer builder that handles and builds a "terminal-like" interface by manipulating data sent to and from UART.

### Dependencies/Credits

This project uses [uart-for-fpga](https://github.com/jakubcabal/uart-for-fpga) by @jakubcabal.
Included as a Git submodule in `net-term.srcs/sources_1/uart`.
