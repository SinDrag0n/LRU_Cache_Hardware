`include "../include/prj_pkg.sv"
import prj_pkg::*;

module lru_addr_block (
  input  logic                  clk_i,
  input  logic                  rstn_i,
 
  input  logic                  cpu_req_i,
  input  logic [TAG_SIZE - 1:0] cpu_tag_i,

  output logic [TAG_SIZE - 1:0] replace_tag_o
);

logic [TAG_SIZE - 1:0] tags_shift_reg [0:WORDS_NUMBER - 1];
logic                  valid_reg      [0:WORDS_NUMBER - 1];

always_ff @( posedge clk_i or negedge rstn_i ) begin
  if ( ~rstn_i ) begin
    for ( int i = 0; i < WORDS_NUMBER; i = i + 1 ) begin
      tags_shift_reg[i] <= TAG_SIZE'(0);
    end
  end
  else begin
    for ( int i = 0; i < WORDS_NUMBER; i = i + 1 ) begin
      if ( valid_reg[i] ) begin
        tags_shift_reg[i] <= tags_shift_reg[i - 1];  // shift tag into next reg if it isnot equal with input tag, otherwise it will be replace
      end
    end
  end
end

genvar i;
generate
  for ( i = 1; i < WORDS_NUMBER; i = i + 1) begin
    assign valid_reg[i] = tags_shift_reg[i-1] != cpu_tag_i;  // Generation of Clock Enable signal for next flip-flops
  end                                                        // valid = 1 if reg data is not equal with input tag
endgenerate
assign valid_reg[0] = cpu_req_i;

assign replace_tag_o = tags_shift_reg[WORDS_NUMBER - 1];

endmodule
