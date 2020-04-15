// Verilog translation (C) 2017 David Banks
// Ulx3s board version (C) 2020 Lawrie Griffiths
//
// This file is copyright by Grant Searle 2014
// You are free to use this file in your own projects but must never charge for it nor use it without
// acknowledgement.
// Please ask permission from Grant Searle before republishing elsewhere.
// If you use this file or any part of it, please add an acknowledgement to myself and
// a link back to my main web site http://searle.hostei.com/grant/
// and to the "multicomp" page at http://searle.hostei.com/grant/Multicomp/index.html
//
// Please check on the above web pages to see if there are any updates before using this file.
// If for some reason the page is no longer available, please search for "Grant Searle"
// on the internet to see if I have moved to another web hosting service.
//
// Grant Searle
// eMail address available on my main web page link above.
// no timescale needed

`define include_video

module Microcomputer
  (
   input         clk25_mhz,
   // Buttons
   input [6:0]   btn,
   // Uart
   input         rxd1,
   output        txd1,
`ifdef include_video
   // Video
   output        videoSync,
   output        video,
   output        videoR0,
   output        videoG0,
   output        videoB0,
   output        videoR1,
   output        videoG1,
   output        videoB1,
   output        hSync,
   output        vSync,
   // HDMI
   output [3:0]  gpdi_dp,
   output [3:0]  gpdi_dn,
   // Keyboard
   output        usb_fpga_pu_dp,
   output        usb_fpga_pu_dn,
   inout         ps2Clk,
   inout         ps2Data,
`endif
   // SD card
   output        sdCS,
   output        sdMOSI,
   input         sdMISO,
   output        sdSCLK,
   // Leds
   output [7:0]  leds,
   output [15:0] diag
   );

   wire          n_WR;
   wire          n_RD;
   wire [15:0]   cpuAddress;
   wire [7:0]    cpuDataOut;
   wire [7:0]    cpuDataIn;
   wire          n_memWR;
   wire          n_memRD;
   wire          n_ioWR;
   wire          n_ioRD;
   wire          n_MREQ;
   wire          n_IORQ;
   wire          n_int1;
   wire          n_int2;
   wire          n_romCS;
   wire          n_externalRamCS;
   wire          n_basRomCS;
   wire [7:0]    basRomData;
   wire          n_interface1CS;
   wire [7:0]    interface1DataOut;
   wire          n_interface2CS;
   wire [7:0]    interface2DataOut;
   wire          n_sdCardCS;
   wire [7:0]    sdCardDataOut;

   reg [15:0]    serialClkCount = 0;
   reg [5:0]     cpuClkCount = 0;
   reg           cpuClock;
   wire          serialClock;
   reg           sdClock;
   reg           clk = 0;
   wire          driveLED;

   // ===============================================================
   // Reset generation
   // ===============================================================

   reg [15:0] pwr_up_reset_counter = 0; // hold reset low for ~1ms
   wire       pwr_up_reset_n = &pwr_up_reset_counter;

   always @(posedge clk25_mhz)
     begin
       if (!pwr_up_reset_n)
         pwr_up_reset_counter <= pwr_up_reset_counter + 1;
     end

   wire          n_hard_reset = pwr_up_reset_n & btn[0];

   // ===============================================================
   // System Clock generation (25MHz)
   // ===============================================================
   wire clk100, locked;

   pll pll_i (
     .clkin(clk25_mhz),
     .clkout0(clk100),
     .locked(locked)
   );

   // ____________________________________________________________________________________
   // CPU CHOICE GOES HERE
   
   tv80n
     #(
       .Mode(1),
       .T2Write(1),
       .IOWait(0)
       )
   cpu1
     (
      .reset_n(n_hard_reset),
      .clk(cpuClock),
      .wait_n(1'b 1),
      .int_n(1'b 1),
      .nmi_n(1'b 1),
      .busrq_n(1'b 1),
      .mreq_n(n_MREQ),
      .iorq_n(n_IORQ),
      .rd_n(n_RD),
      .wr_n(n_WR),
      .A(cpuAddress),
      .di(cpuDataIn),
      .do(cpuDataOut));

   // ____________________________________________________________________________________
   // ROM GOES HERE
   
   wire [7:0] romOut;

   ROM #(.MEM_INIT_FILE("../mem/CPM_BASIC.mem"), .A_WIDTH(13)) rom16 (
     .clock(clk100),
     .address(cpuAddress[12:0]),
     .q(romOut)
   );

   // ____________________________________________________________________________________
   // RAM GOES HERE
   
   wire [7:0] ramOut;
   
   ram ram64(
     .clk(clk100),
     .we(!n_memWR),
     .addr(cpuAddress),
     .din(cpuDataOut),
     .dout(ramOut)
   );

   // ____________________________________________________________________________________
   // INPUT/OUTPUT DEVICES GO HERE

   bufferedUART io1
     (
      .clk(clk),
      .n_wr(n_interface1CS | n_ioWR),
      .n_rd(n_interface1CS | n_ioRD),
      .n_int(n_int1),
      .regSel(cpuAddress[0]),
      .dataIn(cpuDataOut),
      .dataOut(interface1DataOut),
      .rxClock(serialClock),
      .txClock(serialClock),
      .rxd(rxd1),
      .txd(txd1),
      .n_cts(1'b 0),
      .n_dcd(1'b 0),
      .n_rts()
      );

`ifdef include_video
   // pull-ups for us2 connector 
   assign usb_fpga_pu_dp = 1;
   assign usb_fpga_pu_dn = 1;

   SBCTextDisplayRGB io2
     (
      .n_reset(n_hard_reset),
      .clk(clk),
      // RGB video signals
      .hSync(hSync),
      .vSync(vSync),
      .videoR0(videoR0),
      .videoR1(videoR1),
      .videoG0(videoG0),
      .videoG1(videoG1),
      .videoB0(videoB0),
      .videoB1(videoB1),
      // Monochrome video signals (when using TV timings only)
      .sync(videoSync),
      .video(video),
      .n_wr(n_interface2CS | n_ioWR),
      .n_rd(n_interface2CS | n_ioRD),
      .n_int(n_int2),
      .regSel(cpuAddress[0]),
      .dataIn(cpuDataOut),
      .dataOut(interface2DataOut),
      .ps2Clk(ps2Clk),
      .ps2Data(ps2Data)
      );
`else
   assign interface2DataOut = 8'hff;
`endif

   sd_controller sd1
     (
      .sdCS(sdCS),
      .sdMOSI(sdMOSI),
      .sdMISO(sdMISO),
      .sdSCLK(sdSCLK),
      .n_wr(n_sdCardCS | n_ioWR),
      .n_rd(n_sdCardCS | n_ioRD),
      .n_reset(n_hard_reset),
      .dataIn(cpuDataOut),
      .dataOut(sdCardDataOut),
      .regAddr(cpuAddress[2:0]),
      .driveLED(driveLED),
      .clk(clk)
      );
   

   // ____________________________________________________________________________________
   // MEMORY READ/WRITE LOGIC GOES HERE

   assign n_ioWR = n_WR | n_IORQ;
   assign n_memWR = n_WR | n_MREQ;
   assign n_ioRD = n_RD | n_IORQ;
   assign n_memRD = n_RD | n_MREQ;

   // ____________________________________________________________________________________
   // CHIP SELECTS GO HERE

   // 2 Bytes $80-$81
   assign n_interface1CS = cpuAddress[7:1] == 7'b 1000000 && (n_ioWR == 1'b 0 || n_ioRD == 1'b 0) ? 1'b 0 : 1'b 1;

   // 2 Bytes $82-$83
   assign n_interface2CS = cpuAddress[7:1] == 7'b 1000001 && (n_ioWR == 1'b 0 || n_ioRD == 1'b 0) ? 1'b 0 : 1'b 1;

   // 8 Bytes $88-$8F
   assign n_sdCardCS = cpuAddress[7:3] == 5'b 10001 && (n_ioWR == 1'b 0 || n_ioRD == 1'b 0) ? 1'b 0 : 1'b 1;

   assign n_romCS = cpuAddress[15:13] != 0;

   // Always enabled
   assign n_externalRamCS = 1'b0;

   // ____________________________________________________________________________________
   // BUS ISOLATION GOES HERE

   assign cpuDataIn =   n_interface1CS == 1'b 0 ? interface1DataOut   :
                        n_interface2CS == 1'b 0 ? interface2DataOut   :
                            n_sdCardCS == 1'b 0 ? sdCardDataOut       :
			       n_romCS == 1'b 0 ? romOut              :
                       n_externalRamCS == 1'b 0 ? ramOut              :
                                                  8'h FF;
  // ____________________________________________________________________________________
  // SYSTEM CLOCKS GO HERE
  // SUB-CIRCUIT CLOCK SIGNALS

   assign serialClock = serialClkCount[15];

   always @(posedge clk100)
      clk <= !clk;

   always @(posedge clk) begin
      if(cpuClkCount < 4) begin
         // 4 = 10MHz, 3 = 12.5MHz, 2=16.6MHz, 1=25MHz
         cpuClkCount <= cpuClkCount + 1;
      end
      else begin
         cpuClkCount <= {6{1'b0}};
      end
      if(cpuClkCount < 2) begin
         // 2 when 10MHz, 2 when 12.5MHz, 2 when 16.6MHz, 1 when 25MHz
         cpuClock <= 1'b 0;
      end
      else begin
         cpuClock <= 1'b 1;
      end
      // Serial clock DDS
      // 50MHz master input clock:
      // Baud Increment
      // 115200 2416
      // 38400 805
      // 19200 403
      // 9600 201
      // 4800 101
      // 2400 50
      serialClkCount <= serialClkCount + 2416;
   end

   // ===============================================================
   // Leds
   // ===============================================================

   wire led1 = 0;
   wire led2 = !driveLED;
   wire led3 = n_WR;
   wire led4 = !n_hard_reset;

   assign leds = {4'b0, led4, led3, led2, led1};
   assign diag = cpuAddress;
   
endmodule