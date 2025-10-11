`include "../include/prj_pkg.sv"
import prj_pkg::*;

module cache_ctrl_top(

  /// CPU connection
  ahb_bus.slave  cpu_bus,

  output logic   hit,
  output logic   miss,

  /// Main Memory connection
  ahb_bus.master mem_bus
);






endmodule