package prj_pkg;

/// AHB Bus parameters ///

localparam ADDR_WIDTH   = 32;
localparam HBURST_WIDTH = 1;
localparam DATA_WIDTH   = 32;
localparam STRB_WIDTH   = DATA_WIDTH / 8;

/// Cache memory parameters ///

localparam SET_NUMBER   = 8;
localparam WORDS_NUMBER = 4;

localparam OFFSET_SIZE  = 2;
localparam INDEX_SIZE   = $clog2( SET_NUMBER );
localparam TAG_SIZE     = DATA_WIDTH - INDEX_SIZE - OFFSET_SIZE; 

localparam HIT_ADDR_SIZE = $clog2( WORDS_NUMBER ); 

endpackage