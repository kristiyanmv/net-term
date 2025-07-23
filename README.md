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
- [ ] Implement USB communication
- [ ] Handle keyboard inputs
- [ ] Setup a simple logic that controls onboard LEDS from keyboard input
- [ ] Setup serial interface and confirm that it works.
- [ ] Select a proper display, implement it if no implementation is available
- [ ] Design a daughter board that houses all peripheral devices and connections
