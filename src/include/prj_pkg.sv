package prj_pkg;

/// AHB Bus parameters ///

localparam int ADDR_WIDTH    = 32;
localparam int HBURST_WIDTH  = 1;
localparam int DATA_WIDTH    = 32;
localparam int STRB_WIDTH    = DATA_WIDTH / 8;

/// Cache memory parameters ///

localparam int SET_NUMBER    = 8;
localparam int WORDS_NUMBER  = 4;
 
localparam int OFFSET_SIZE   = 2;
localparam int INDEX_SIZE    = $clog2( SET_NUMBER );
localparam int TAG_SIZE      = DATA_WIDTH - INDEX_SIZE - OFFSET_SIZE; 

localparam int HIT_ADDR_SIZE = $clog2( WORDS_NUMBER ); 

endpackage
