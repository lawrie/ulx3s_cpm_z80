# ulx3s_cpm_z80

A port of the Ice40CPMZ80 project to the Ulx3s ECP5 board.

Thanks to https://github.com/hoglet67 for the Ice40 version and Grant Searle for the original VHDL version.

To build and upload the bit file do:

```sh
cd ulx3s
make prog
```

The SD card image is available at http://obsolescence.wixsite.com/obsolescence/multicomp-fpga-cpm-demo-disk.

Input is via a PS/2 keyboard or a UART at 115200 baud.

HDMI and VGA output is supported. VGA uses a Digilent Pmod.

Follow the instructions on the screen to load CP/M.

Unfortunately, loading CP/M currently hangs or gives a repeated K> prompt and does not allow input.

The default board is the 85F, use a DEVICE parameter to the makefile for other boards. Currently building with DEVICE=12k hangs in nextpnr routing.

