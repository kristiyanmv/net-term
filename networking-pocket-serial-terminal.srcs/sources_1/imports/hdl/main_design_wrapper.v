//Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
//Copyright 2022-2025 Advanced Micro Devices, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2025.1 (win64) Build 6140274 Thu May 22 00:12:29 MDT 2025
//Date        : Thu Jul 31 14:33:56 2025
//Host        : DESKTOP-RPU4VI9 running 64-bit major release  (build 9200)
//Command     : generate_target main_design_wrapper.bd
//Design      : main_design_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module main_design_wrapper
   (clk_0,
    led1,
    led2,
    ps2_clk,
    ps2_data);
  input clk_0;
  output led1;
  output led2;
  input ps2_clk;
  input ps2_data;

  wire clk_0;
  wire led1;
  wire led2;
  wire ps2_clk;
  wire ps2_data;

  main_design main_design_i
       (.clk_0(clk_0),
        .led1(led1),
        .led2(led2),
        .ps2_clk(ps2_clk),
        .ps2_data(ps2_data));
endmodule
