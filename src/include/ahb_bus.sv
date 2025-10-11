`include "prj_pkg.sv"
import prj_pkg::*;

interface ahb_bus;
  
  logic                       hclk;
  logic                       hrstn;

  logic [ADDR_WIDTH - 1:0]   haddr;
  logic [HBURST_WIDTH - 1:0] hburst;
  logic [2:0]                hsize;
  logic [1:0]                htrans;
  logic [DATA_WIDTH - 1:0]   hwdata;
  logic [STRB_WIDTH - 1:0]   hwstrb;
  logic                      hwrite;

  logic [DATA_WIDTH - 1:0]   hrdata;
  logic                      hreadyout;
  logic                      hresp;

  modport slave_port (
    input  hclk,
    input  hrstn,

    input  haddr,
    input  hburst,
    input  hsize,
    input  htrans,
    input  hwdata,
    input  hwstrb,
    input  hwrite,

    output hrdata,
    output hreadyout,
    output hresp
  );

modport master_port (
  output  hclk,
  output  hrstn,

  output  haddr,
  output  hburst,
  output  hsize,
  output  htrans,
  output  hwdata,
  output  hwstrb,
  output  hwrite,

  input   hrdata,
  input   hreadyout,
  input   hresp
);

endinterface 
