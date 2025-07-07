`include "../include/prj_pkg.sv"
import prj_pkg::*;

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

typedef enum { CACHE_IDLE, 
               CACHE_CHECK_TAG, 
               CACHE_CPU_WRITE,
               CACHE_CPU_READ,
               CACHE_MEM_READ,
               CACHE_CHECK_VLD,
               CACHE_REPLACE_LRU,
               CACHE_WRITE_FREE

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

logic mem_rdy;    // Temp name for this variable - used to check are there any free place in current set

///////////////////////////////////

logic hit;
logic miss;

logic [HIT_ADDR_SIZE - 1:0] hit_addr_reg; // register to save address of hited word


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
          next_state = CACHE_CPU_WRITE; // In fact, just rewrite memory that already exists
        end                             // TODO: add another condition to write without cache hit

        else begin
          next_state = CACHE_CPU_READ;
        end
      end

      else begin
        if ( cpu_we_i ) begin
          if ( mem_rdy )
            next_state = CACHE_WRITE_FREE;
          else
            next_state = CACHE_REPLACE_LRU;
        end

        else begin
          next_state = CACHE_MEM_READ;
        end
      end
    end

    CACHE_CPU_WRITE: begin
      if ( cpu_write_done ) begin
        next_state = CACHE_IDLE;  // I think it should update data in main memory too. Gonna return to this later
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
        next_state = CACHE_IDLE;  // Need to be changed to continue CPU reading operation
      end

      else begin
        next_state = CACHE_MEM_READ;
      end
    end

    CACHE_WRITE_FREE: begin
      if ( cpu_write_done ) begin
        next_state = CACHE_IDLE;
      end

      else begin
        next_state = CACHE_WRITE_FREE;
      end
    end

    CACHE_REPLACE_LRU: begin
      if ( cpu_write_done ) begin
        next_state = CACHE_IDLE;
      end

      else begin
        next_state = CACHE_REPLACE_LRU;
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
          hit          <= 1'b1;
          hit_addr_reg <= w;
      end
    end
    else begin
      hit <= 1'b0;
    end
  end
end

assign miss = ~hit;

always_ff @( posedge clk_i or negedge rstn_i ) begin : mem_write_stage;

  if ( ~rstn_i ) begin
    for ( int s = 0; s < SET_NUMBER; s++ ) begin
      for ( int w = 0; w < WORDS_NUMBER; w++) begin
        valid_cache_mem[s][w] <= 1'b0;
        tag_cache_mem  [s][w] <= TAG_SIZE'(0);
        cpu_write_done        <= 1'b0;
        cpu_read_done         <= 1'b0;
      end
    end
  end

  else begin
    cpu_write_done        <= 1'b0;
    cpu_read_done         <= 1'b0;

    if ( cur_state == CACHE_CPU_WRITE ) begin
      data_cache_mem[cpu_index][hit_addr_reg] <= cpu_wdata_i;
      cpu_write_done <= 1'b1;
    end

    else if ( cur_state == CACHE_CPU_READ ) begin
      cpu_rdata_o   <= data_cache_mem[cpu_index][hit_addr_reg];
      cpu_read_done <= 1'b1;
    end

    else begin
      // Will be used later for replacing state and another writing state
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

assign hit_o  = hit;
assign miss_o = miss;

endmodule
