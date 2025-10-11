`include "../include/prj_pkg.sv"
import prj_pkg::*;

module cache_mem (
  input  logic                    clk_i,
  input  logic                    rstn_i,

  input  logic                    cpu_req_i,
  input  logic [DATA_WIDTH - 1:0] cpu_wdata_i,
  input  logic                    cpu_we_i,
  input  logic [ADDR_WIDTH - 1:0] cpu_addr_i,
  output logic [DATA_WIDTH - 1:0] cpu_rdata_o,
  
  output logic                    mem_req_o,
//  output logic                  mem_wdata_o,
  output logic                    mem_we_o,
  output logic [ADDR_WIDTH - 1:0] mem_addr_o,
  input  logic [DATA_WIDTH - 1:0] mem_rdata_i,
  input  logic                    mem_valid_i,

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

state_t cur_state;
state_t next_state;

////////////////////////// Memory variables /////////////////////////////////////////
                                                                                   //
logic [WORDS_NUMBER - 1:0] valid_cache_mem                   [0:SET_NUMBER - 1];   //
logic [TAG_SIZE - 1:0]     tag_cache_mem   [0:SET_NUMBER - 1][0:WORDS_NUMBER - 1]; //
logic [DATA_WIDTH - 1:0]   data_cache_mem  [0:SET_NUMBER - 1][0:WORDS_NUMBER - 1]; //
                                                                                   //
/////////////////////////////////////////////////////////////////////////////////////

////////////////////////// Splitting input address ////////////////////////////////
                                                                                 //   
logic [TAG_SIZE - 1:0]    cpu_tag;                                               //
logic [INDEX_SIZE - 1:0]  cpu_index;                                             //
logic [OFFSET_SIZE -1:0]  cpu_offset;                                            //
                                                                                 //
assign {cpu_tag, cpu_index, cpu_offset} = cpu_addr_i;                            //
                                                                                 //
///////////////////////////////////////////////////////////////////////////////////

//////// Output flip-flops ////////

logic [DATA_WIDTH - 1:0] cpu_rdata_ff;
logic [ADDR_WIDTH - 1:0] mem_addr_ff;
//logic [DATA_WIDTH - 1:0] mem_wdata_ff;

assign cpu_rdata_o = cpu_rdata_ff;
assign mem_addr_o  = mem_addr_ff;
// assign mem_wdata_o = mem_wdata_ff;

////// States finish signals //////

logic cpu_write_done;
logic cpu_read_done;
logic mem_read_done;

logic mem_rdy;    // Temp name for this variable - used to check are there any free place in current set

///////////////////////////////////

logic hit;
logic miss;

logic [HIT_ADDR_SIZE - 1:0] hit_addr_reg; // register to save address of hited word
logic [TAG_SIZE - 1:0]      lru_tags_reg [0:SET_NUMBER - 1];

logic [$clog2( WORDS_NUMBER ) - 1:0] free_addr [0:SET_NUMBER - 1];
logic [SET_NUMBER - 1:0]             set_full;
// logic [SET_NUMBER - 1:0] set_empty;
logic mem_valid;

always_comb begin: switch_logic
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
      if ( cpu_we_i ) begin
        next_state = CACHE_CPU_WRITE;
      end

      else begin
        if ( hit ) begin
          next_state = CACHE_CPU_READ;
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

    default:
      next_state = CACHE_IDLE;
  endcase
end: switch_logic

always_ff @( posedge clk_i or negedge rstn_i ) begin: hit_check
  if ( ~rstn_i ) begin
    hit <= 1'b0;
  end

  else begin
    if ( cur_state == CACHE_CHECK_TAG ) begin
      for ( int w = 0; w < WORDS_NUMBER; w = w + 1 ) begin
        if ( ( tag_cache_mem[cpu_index][w] == cpu_tag ) && ( valid_cache_mem[cpu_index][w] ) )
          hit          <= 1'b1;
          hit_addr_reg <= w;
      end
    end
    else begin
      hit <= 1'b0;  // if valid but tag wrong should be send to replace state
    end
  end
end: hit_check

assign miss = ~hit;

always_ff @( posedge clk_i or negedge rstn_i ) begin: mem_write_stage

  if ( ~rstn_i ) begin
    for ( int s = 0; s < SET_NUMBER; s = s + 1 ) begin
      for ( int w = 0; w < WORDS_NUMBER; w = w + 1 ) begin
        valid_cache_mem[s][w] <= 1'b0;
        tag_cache_mem  [s][w] <= TAG_SIZE'(0);
      end
    end
    cpu_write_done  <= 1'b0;
    cpu_read_done   <= 1'b0;
  end

  else begin
    cpu_write_done  <= 1'b0;
    cpu_read_done   <= 1'b0;

    if ( cur_state == CACHE_CPU_WRITE ) begin
      if ( hit ) begin
        data_cache_mem [cpu_index][hit_addr_reg] <= cpu_wdata_i;
        tag_cache_mem  [cpu_index][hit_addr_reg] <= cpu_tag;
        valid_cache_mem[cpu_index][hit_addr_reg] <= 1'b1;
        cpu_write_done                           <= 1'b1;
      end else if ( ~set_full[cpu_index] ) begin
        data_cache_mem [cpu_index][free_addr[cpu_index]] <= cpu_wdata_i;
        tag_cache_mem  [cpu_index][free_addr[cpu_index]] <= cpu_tag;
        valid_cache_mem[cpu_index][free_addr[cpu_index]] <= 1'b1;
        cpu_write_done                                   <= 1'b1;
      end else begin
        data_cache_mem [cpu_index][lru_tags_reg[cpu_index]] <= cpu_wdata_i; // problem is that we need to wait 1 cycle
        tag_cache_mem  [cpu_index][lru_tags_reg[cpu_index]] <= cpu_tag;
        valid_cache_mem[cpu_index][lru_tags_reg[cpu_index]] <= 1'b1;
        cpu_write_done                                      <= 1'b1;
      end
    end

    else if ( cur_state == CACHE_CPU_READ ) begin
      cpu_rdata_ff  <= data_cache_mem[cpu_index][hit_addr_reg];
      cpu_read_done <= 1'b1;
    end

    else if ( cur_state == CACHE_MEM_READ ) begin
      if ( ~mem_read_done ) begin
        mem_addr_ff <= cpu_addr_i;
        mem_req_o   <= 1'b1;
        mem_we_o    <= 1'b0;
      end else begin
        data_cache_mem [cpu_index][lru_tags_reg[cpu_index]] <= mem_rdata_i;
        tag_cache_mem  [cpu_index][lru_tags_reg[cpu_index]] <= cpu_tag;
        valid_cache_mem[cpu_index][lru_tags_reg[cpu_index]] <= 1'b1;
        cpu_rdata_ff                                        <= mem_rdata_i;
      end
    end
  end
end: mem_write_stage



always_ff @( posedge clk_i or negedge rstn_i ) begin: state_switcher
  if ( ~rstn_i ) begin
    cur_state <= CACHE_IDLE;
  end

  else begin
    cur_state <= next_state;
  end
end: state_switcher

lru_addr_block lru_addr_block_inst [SET_NUMBER - 1:0] (
  .clk_i          ( clk_i ),
  .rstn_i         ( rstn_i ),
  .cpu_req_i      ( cpu_req_i ),
  .cpu_tag_i      ( cpu_tag   ),
  .replace_tag_o  ( lru_tags_reg )
);
  
onehot_decoder onehot_decoder_inst [SET_NUMBER - 1:0] (
  .data_i     ( valid_cache_mem ),
  .data_o     ( free_addr       ),
  .set_full_o ( set_full        )
);


assign hit_o  = hit;
assign miss_o = miss;


endmodule

