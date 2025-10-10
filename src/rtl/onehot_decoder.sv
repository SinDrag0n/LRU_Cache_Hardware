`include "../include/prj_pkg.sv"
import prj_pkg::*;

module onehot_decoder (
  input  logic [WORDS_NUMBER - 1:0]           data_i,
  output logic [$clog2( WORDS_NUMBER ) - 1:0] data_o,
  output logic                                set_full_o
  // output logic                                set_empty_o
);

logic [WORDS_NUMBER - 1:0] lsb_zero;
assign lsb_zero =  ( data_i & ~( data_i + 1'b1 ) ) << 1'b1; // shift to left to find onehot vector of first zero from most significant active bit

always_comb begin
  data_o = $clog2( WORDS_NUMBER )'(0);
  for ( int i = 0; i < WORDS_NUMBER; i = i + 1 ) begin
    if ( lsb_zero[i] ) begin
       data_o = i;
    end
  end
end

assign set_full_o  =  &data_i;
// assign set_empty_o = ~|data_i;

endmodule