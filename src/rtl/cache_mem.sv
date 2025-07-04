module cache_mem(
  input  logic                    clk_i,
  input  logic                    rstn_i,

  input  logic                    cpu_req_i,
  input  logic [DATA_WIDTH - 1:0] cpu_wdata_i,
  input  logic                    cpu_we_i,
  input  logic [ADDR_WIDTH - 1:0] cpu_addr_i,
  output logic [DATA_WIDTH - 1:0] cpu_rdata_o,
  
  output logic                    mem_req_o,
//  output logic                  mem_wdata_i,
  output logic                    mem_we_o,
  output logic [ADDR_WIDTH - 1:0] mem_addr_o,
  input  logic [DATA_WIDTH - 1:0] mem_rdata_i,

  output logic                    hit_o,
  output logic                    miss_o
);

localparam DATA_WIDTH   = 32;
localparam ADDR_WIDTH   = 32;

localparam SET_NUMBER  = 8;
localparam WORDS_NUMBER = 4;

localparam OFFSET_SIZE  = 2;
localparam INDEX_SIZE   = $clog2( SET_NUMBER );
localparam TAG_SIZE     = DATA_WIDTH - INDEX_SIZE - OFFSET_SIZE; 

typedef enum { CACHE_IDLE, 
               CACHE_CHECK_TAG, 
               CACHE_CPU_WRITE,
               CACHE_CPU_READ,
               CACHE_MEM_READ

              } state_t;

state_t cur_state, next_state;

////////////////////////// Memory variables ///////////////////////////////////////
                                                                                 //
logic                    valid_cache_mem [0:SET_NUMBER - 1][0:WORDS_NUMBER - 1]; //
logic [TAG_SIZE - 1:0]   tag_cache_mem   [0:SET_NUMBER - 1][0:WORDS_NUMBER - 1]; //
logic [DATA_WIDTH - 1:0] data_cache_mem  [0:SET_NUMBER - 1][0:WORDS_NUMBER - 1]; //
                                                                                 //
///////////////////////////////////////////////////////////////////////////////////

////////////////////////// Splitting input address ////////////////////////////////
                                                                                 //   
logic [TAG_SIZE - 1:0]    cpu_tag;                                               //
logic [INDEX_SIZE - 1:0]  cpu_index;                                             //
logic [OFFSET_SIZE -1:0]  cpu_offset;                                            //
                                                                                 //
assign {cpu_tag, cpu_index, cpu_offset} = cpu_addr_i;                            //
                                                                                 //
///////////////////////////////////////////////////////////////////////////////////

////// States finish signals //////

logic cpu_write_done;
logic cpu_read_done;
logic mem_read_done;

///////////////////////////////////

logic hit;
logic miss;


always_comb begin : switch_logic
  next_state = CACHE_IDLE;
  case ( cur_state )
  
    CACHE_IDLE: begin
      if ( cpu_req_i ) begin
        next_state = CACHE_CHECK_TAG;
      end

      else begin 
        next_state = CACHE_IDLE;
      end
    end

    CACHE_CHECK_TAG: begin
      if ( hit ) begin
        if ( cpu_we_i ) begin
          next_state = CACHE_CPU_WRITE;
        end

        else begin
          next_state = CACHE_CPU_READ;
        end
      end

      else begin
        next_state = CACHE_MEM_READ;
      end
    end

    CACHE_CPU_WRITE: begin
      if ( cpu_write_done ) begin
        next_state = CACHE_IDLE;
      end

      else begin
        next_state = CACHE_CPU_WRITE;
      end
    end

    CACHE_CPU_READ: begin
      if ( cpu_read_done ) begin
        next_state = CACHE_IDLE;
      end

      else begin
        next_state = CACHE_CPU_READ;
      end
    end

    CACHE_MEM_READ: begin
      if ( mem_read_done ) begin
        next_state = CACHE_IDLE;
      end

      else begin
        next_state = CACHE_MEM_READ;
      end
    end

  endcase
end

always_ff @( posedge clk_i or negedge rstn_i ) begin: hit_check
  if ( ~rstn_i ) begin
    hit <= 1'b0;
  end

  else begin
    if ( cur_state == CACHE_CHECK_TAG ) begin
      for ( int w = 0; w < WORDS_NUMBER; w++ ) begin
        if ( ( tag_cache_mem[cpu_index][w] == cpu_tag ) && ( valid_cache_mem[cpu_index][w] ) )
          hit <= 1'b1;
      end
    end
  end
end

always_ff @( posedge clk_i or negedge rstn_i ) begin : state_switcher
  if ( ~rstn_i ) begin
    cur_state <= CACHE_IDLE;
  end

  else begin
    cur_state <= next_state;
  end
end

assign hit_o = hit;


endmodule
