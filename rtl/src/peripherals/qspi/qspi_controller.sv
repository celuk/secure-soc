// qspi_controller.v
`timescale 1ps / 1ps

//`define QSPI_CCR_INST 7:0
//`define QSPI_CCR_DATA_MOD 9:8
//`define QSPI_CCR_WR 10
//`define QSPI_CCR_DUMMY_CYC 15:11
//`define QSPI_CCR_DATA_SIZE 24:16
//`define QSPI_CCR_PRESCALER 30:25
//`define QSPI_CCR_CLEAR_STA 31

`define CMD_READ    'h03
`define CMD_DOR     'h3B
`define CMD_QOR     'h6B
`define CMD_PP      'h02
`define CMD_QPP     'h32
`define CMD_SE      'hD8
`define CMD_READ_ID 'h90
`define CMD_RDID    'h9F
`define CMD_RES     'hAB
`define CMD_RDSR1   'h05
`define CMD_RDSR2   'h07
`define CMD_RDCR    'h35
`define CMD_WRR     'h01
`define CMD_WRDI    'h04
`define CMD_WREN    'h06
`define CMD_CLSR    'h30
`define CMD_RESET   'hF0

`define MAX_BIT 256
`define INSTRUCTION_SIZE 8
`define ADDRESS_SIZE 24

module qspi_controller (
   input clk_i,
   input rst_i,
   // wishbone interface
   input  [ 7:0] wb_adr_i,
   input  [31:0] wb_dat_i,
   input         wb_we_i,
   input         wb_stb_i,
   input  [ 3:0] wb_sel_i,
   input         wb_cyc_i,
   output        wb_ack_o,
   output [31:0] wb_dat_o,

   // QSPI i/o
   //inout [3:0] io_qspi_data,
   input [3:0] qspi_data_i,
   output [3:0] qspi_data_o,
   output [1:0] qspi_out_mod_o,

   output qspi_cs_n_o,
   output qspi_sck_o
);
   
   reg wb_ack_r;
   reg wb_ack_next_r;
   assign wb_ack_o = wb_ack_r;

   reg [31:0] wb_read_data_r;
   reg [31:0] wb_read_data_next_r;
   assign wb_dat_o = wb_read_data_r;

   // CONTROL REGISTERS
   reg [31:0] QSPI_CCR;
   reg [23:0] QSPI_ADR;
   reg [31:0] QSPI_DR0;
   reg [31:0] QSPI_DR1;
   reg [31:0] QSPI_DR2;
   reg [31:0] QSPI_DR3;
   reg [31:0] QSPI_DR4;
   reg [31:0] QSPI_DR5;
   reg [31:0] QSPI_DR6;
   reg [31:0] QSPI_DR7;
   reg [1:0]  QSPI_STA;

   reg [31:0] QSPI_CCR_next;
   reg [23:0] QSPI_ADR_next;
   reg [31:0] QSPI_DR0_next;
   reg [31:0] QSPI_DR1_next;
   reg [31:0] QSPI_DR2_next;
   reg [31:0] QSPI_DR3_next;
   reg [31:0] QSPI_DR4_next;
   reg [31:0] QSPI_DR5_next;
   reg [31:0] QSPI_DR6_next;
   reg [31:0] QSPI_DR7_next;
   reg [1:0]  QSPI_STA_next;

   wire [`MAX_BIT-1:0] QSPI_DRs = {QSPI_DR7, QSPI_DR6, QSPI_DR5, QSPI_DR4, QSPI_DR3, QSPI_DR2, QSPI_DR1, QSPI_DR0};

   wire [7:0] QSPI_CCR_INST = QSPI_CCR[7:0];
   wire [1:0] QSPI_CCR_DATA_MOD = QSPI_CCR[9:8];
   wire QSPI_CCR_WR = QSPI_CCR[10];
   wire [4:0] QSPI_CCR_DUMMY_CYC = QSPI_CCR[15:11];
   wire [4:0] QSPI_CCR_DATA_SIZE = QSPI_CCR[20:16];
   wire [5:0] QSPI_CCR_PRESCALER = QSPI_CCR[30:25];
   wire QSPI_CCR_CLEAR_STA = QSPI_CCR[31];

   localparam X1 = 2'b01,
              X2 = 2'b10,
              X4 = 2'b11;
   wire [2:0] data_rate = (QSPI_CCR_DATA_MOD==X4) ? 4 : QSPI_CCR_DATA_MOD;

   reg [2:0] state;
   reg [2:0] state_next;
   localparam IDLE = 0,
              SELECT_DEVICE = 1,
              SEND_COMMAND = 2,
              SEND_ADDRESS = 3,
              DUMMY_CYCLES = 4,
              TRANSFER_DATA = 5,
              TRANSFERRING = 6,
              END_TRANSFER = 7;

   reg [31:0] bit_counter;
   reg [31:0] bit_counter_next;

   reg qspi_cs_r;
   reg qspi_cs_next_r;
   assign qspi_cs_n_o = (state == IDLE); //qspi_cs_r;

   reg [`MAX_BIT-1:0] buffer;
   reg [`MAX_BIT-1:0] buffer_next;

   //assign qspi_data_o = data_mod==X4 ? out_buffer[31:28] : 
   //                     data_mod==X2 ? {2'b00, out_buffer[31:30]} : 
   //                     data_mod==X1 ? {3'b000, out_buffer[31]} : 4'b0000;

   reg [3:0] data_out;
   reg [3:0] data_out_next;

   reg [3:0] data_out_enable;
   reg [3:0] data_out_enable_next;

   assign qspi_data_o = data_out;
   assign qspi_out_mod_o = data_out_enable == 4'b1111 ? 2'b11 :
                           data_out_enable == 4'b0011 ? 2'b10 :
                           data_out_enable == 4'b0001 ? 2'b01 :
                           2'b00;

   // if there is a write to CCR, new instruction is coming
   //wire new_instruction = (wb_cyc_i & wb_stb_i & wb_we_i & !wb_ack_o & (|wb_sel_i) & wb_adr_i == 8'h00);

   reg new_instruction;
   reg new_instruction_next;

   wire addr_enable;
   wire data_enable;

   assign addr_enable = (QSPI_CCR_INST == `CMD_READ)    ||
                        (QSPI_CCR_INST == `CMD_DOR )    ||
                        (QSPI_CCR_INST == `CMD_QOR )    ||
                        (QSPI_CCR_INST == `CMD_PP  )    ||
                        (QSPI_CCR_INST == `CMD_QPP )    ||
                        (QSPI_CCR_INST == `CMD_SE  )    ||
                        (QSPI_CCR_INST == `CMD_READ_ID)
                        ;

   // when data write or read
   // also if DATA_MOD is 0
   assign data_enable = (QSPI_CCR_INST == `CMD_READ)    ||
                        (QSPI_CCR_INST == `CMD_DOR )    ||
                        (QSPI_CCR_INST == `CMD_QOR )    ||
                        (QSPI_CCR_INST == `CMD_PP  )    ||
                        (QSPI_CCR_INST == `CMD_QPP )    ||
                        (QSPI_CCR_INST == `CMD_READ_ID) ||
                        (QSPI_CCR_INST == `CMD_RDID)    ||
                        (QSPI_CCR_INST == `CMD_RES )    ||
                        (QSPI_CCR_INST == `CMD_RDSR1)   ||
                        (QSPI_CCR_INST == `CMD_RDSR2)   ||
                        (QSPI_CCR_INST == `CMD_RDCR)    ||
                        (QSPI_CCR_INST == `CMD_WRR )
                        ;

   reg sclk;
   reg sclk_next;
   //assign qspi_sck_o = sclk;

   reg sck_r;

   reg [2:0] bit_rate;
   reg [2:0] bit_rate_next;

   integer i;

   always @(negedge qspi_sck_o) begin
      if(rst_i) begin
         data_out <= 0;
      end
      else begin
         data_out[3:0] = data_out_enable==4'b1111 ? buffer[`MAX_BIT-1:`MAX_BIT-4]          :
                         data_out_enable==4'b0011 ? {2'b00, buffer[`MAX_BIT-1:`MAX_BIT-2]} :
                         data_out_enable==4'b0001 ? {3'b000, buffer[`MAX_BIT-1]}           : 4'b0000;
      end
   end

   always @* begin
      wb_ack_next_r = 1'b0;
      wb_read_data_next_r = wb_read_data_r;

      QSPI_CCR_next = QSPI_CCR;
      QSPI_ADR_next = QSPI_ADR;
      QSPI_DR0_next = QSPI_DR0;
      QSPI_DR1_next = QSPI_DR1;
      QSPI_DR2_next = QSPI_DR2;
      QSPI_DR3_next = QSPI_DR3;
      QSPI_DR4_next = QSPI_DR4;
      QSPI_DR5_next = QSPI_DR5;
      QSPI_DR6_next = QSPI_DR6;
      QSPI_DR7_next = QSPI_DR7;
      // TODO: which one?
      QSPI_STA_next[0] = QSPI_STA[0]; //0;
      QSPI_STA_next[1] = QSPI_STA[1];

      bit_counter_next = bit_counter;

      state_next = state;

      qspi_cs_next_r = qspi_cs_r;

      data_out_next = data_out;
      data_out_enable_next = data_out_enable;

      buffer_next = buffer;

      sclk_next = sclk;
      
      bit_rate_next = bit_rate;

      new_instruction_next = (wb_cyc_i & wb_stb_i & wb_we_i & !wb_ack_o & (|wb_sel_i) & wb_adr_i == 8'h00); // if there is a write to CCR

      if(|bit_counter) begin // if bit_counter is not 0
         // commands and addresses sending just from IO0
         
                              //QSPI_CCR_DATA_MOD==X4 ? buffer[`MAX_BIT-1:`MAX_BIT-4] : 
                              //QSPI_CCR_DATA_MOD==X2 ? {2'b00, buffer[`MAX_BIT-1:`MAX_BIT-2]} :
                              //QSPI_CCR_DATA_MOD==X1 ? {3'b000, buffer[`MAX_BIT-1]}   : 4'b0000;

         //if (sclk) begin
         //   sclk_next = 1'b0;
         //end 
         //else begin
         //   sclk_next = 1'b1;
         if(~qspi_sck_o) begin
            buffer_next = bit_rate==4 ? {buffer[`MAX_BIT-5:0], qspi_data_i[3:0]} : 
                          bit_rate==2 ? {buffer[`MAX_BIT-3:0], qspi_data_i[1:0]} : 
                          bit_rate==1 ? {buffer[`MAX_BIT-2:0], qspi_data_i[1]}   : 0; // if single SO bit is 1 not 0 (SI)

            bit_counter_next = bit_counter - bit_rate;
            //if((state==TRANSFER_DATA || state==END_TRANSFER) && (QSPI_CCR_DUMMY_CYC > 0))
            //   bit_counter_next = bit_counter - 1;
            //else if(QSPI_CCR_WR)
            //   bit_counter_next = bit_counter - data_out_enable; // -4 -2 -1
            //else
            //   bit_counter_next = bit_counter - data_rate; // -4 -2 -1
            
         end
         QSPI_STA_next[1] = 1; // busy
      end
      else begin
         case(state)
            IDLE: begin
               qspi_cs_next_r = 1'b1;
               data_out_enable_next = 4'b0000;
               bit_counter_next = 0;
               bit_rate_next = 0;
               QSPI_STA_next[1] = 0; // not busy

               state_next = IDLE;

               if(new_instruction) begin
                  new_instruction_next = 1'b0;

                  state_next = SEND_COMMAND;
               end
            end

            /*
            SELECT_DEVICE: begin
               qspi_cs_next_r = 1'b0;
               bit_counter_next = 0;
               QSPI_STA_next[1] = 1; // busy

               state_next = SEND_COMMAND;
            end
            */

            SEND_COMMAND: begin
               qspi_cs_next_r = 1'b0;
               buffer_next[`MAX_BIT-1 -: `INSTRUCTION_SIZE] = QSPI_CCR_INST;
               bit_counter_next = `INSTRUCTION_SIZE;

               data_out_enable_next = 4'b0001;

               bit_rate_next = 1;

               QSPI_STA_next[1] = 1; // busy

               if(addr_enable) begin
                  state_next = SEND_ADDRESS;
               end
               else if(QSPI_CCR_DUMMY_CYC > 0) begin
                  state_next = DUMMY_CYCLES;
               end
               else if(data_enable) begin
                  state_next = TRANSFER_DATA;
               end
               else begin
                  state_next = END_TRANSFER;
               end
            end
            SEND_ADDRESS: begin
               buffer_next[`MAX_BIT-1 -: `ADDRESS_SIZE] = QSPI_ADR;
               bit_counter_next = `ADDRESS_SIZE;

               data_out_enable_next = 4'b0001;

               bit_rate_next = 1;
               
               QSPI_STA_next[1] = 1; // busy

               if(data_enable)
                  state_next = TRANSFER_DATA;
               else
                  state_next = END_TRANSFER;

               if(QSPI_CCR_DUMMY_CYC > 0) begin
                  state_next = DUMMY_CYCLES;
               end
            end
            DUMMY_CYCLES: begin
               bit_counter_next = QSPI_CCR_DUMMY_CYC;

               data_out_enable_next = 4'b0000;

               bit_rate_next = 1;

               QSPI_STA_next[1] = 1; // busy

               if(data_enable)
                  state_next = TRANSFER_DATA;
               else
                  state_next = END_TRANSFER;
            end
            TRANSFER_DATA: begin
               if(QSPI_CCR_WR) begin
                  data_out_enable_next = QSPI_CCR_DATA_MOD==X4 ? 4'b1111 :
                                         QSPI_CCR_DATA_MOD==X2 ? 4'b0011 :
                                         QSPI_CCR_DATA_MOD==X1 ? 4'b0001 :
                                         4'b0000;
                  
                  // at least one byte should be transferred
                  //buffer_next[31:24] = QSPI_DR0[7:0];
                  
                  // TODO: fix here
                  //buffer_next[`MAX_BIT-1 -: (QSPI_CCR_DATA_SIZE+1)*8] = QSPI_DRs[0 +: (QSPI_CCR_DATA_SIZE+1)*8];
                  for (i = 0; i < (QSPI_CCR_DATA_SIZE+1); i = i + 1) begin
                     //buffer_next[`MAX_BIT-1 - i] = QSPI_DRs[i];
                     buffer_next[`MAX_BIT-1 - i*8 -: 8] = QSPI_DRs[i*8 +: 8];
                  end
               end
               else begin
                  data_out_enable_next = 4'b0000;
                  //buffer_next[31:0] = 0;
               end

               bit_rate_next = data_rate;

               QSPI_STA_next[1] = 1; // busy

               bit_counter_next = 8*(QSPI_CCR_DATA_SIZE+1);

               state_next = TRANSFERRING;
            end
            TRANSFERRING: begin
               if(bit_counter == 0) begin
                  state_next = END_TRANSFER;
               end
               QSPI_STA_next[1] = 1; // busy
            end
            END_TRANSFER: begin // ACK
               bit_counter_next = 0;

               data_out_enable_next = 4'b0000;

               bit_rate_next = 0;

               QSPI_STA_next[0] = 1;
               QSPI_STA_next[1] = 0; // not busy

               state_next = IDLE;

               // TODO: make read parametric
               // to do it parametric, dr registers should be merged into one
               // read in just one cycle from buffer to DRs
               if(data_enable && ~QSPI_CCR_WR) begin
                  // if QSPI_CCR_DATA_SIZE is 0, then 1 byte
                  // 1 byte is always read if data_enable and read operation
                  QSPI_DR0_next[7:0] = buffer[7:0];
                  // if a byte is read to a register then clear the rest
                  QSPI_DR0_next[31:8] = 0;
               
                  if(QSPI_CCR_DATA_SIZE >= 1) begin
                     QSPI_DR0_next[7:0] = buffer[15:8];
                     QSPI_DR0_next[15:8] = buffer[7:0];
                  end
                  if(QSPI_CCR_DATA_SIZE >= 2) begin
                     QSPI_DR0_next[7:0] = buffer[23:16];
                     QSPI_DR0_next[15:8] = buffer[15:8];
                     QSPI_DR0_next[23:16] = buffer[7:0];
                  end
                  if(QSPI_CCR_DATA_SIZE >= 3) begin
                     QSPI_DR0_next[7:0] = buffer[31:24];
                     QSPI_DR0_next[15:8] = buffer[23:16];
                     QSPI_DR0_next[23:16] = buffer[15:8];
                     QSPI_DR0_next[31:24] = buffer[7:0];
                  end
               
                  if(QSPI_CCR_DATA_SIZE >= 4) begin
                     QSPI_DR0_next[7:0] = buffer[39:32];
                     QSPI_DR0_next[15:8] = buffer[31:24];
                     QSPI_DR0_next[23:16] = buffer[23:16];
                     QSPI_DR0_next[31:24] = buffer[15:8];
                     QSPI_DR1_next[7:0] = buffer[7:0];
                     QSPI_DR1_next[31:8] = 0;
                  end
                  if(QSPI_CCR_DATA_SIZE >= 5) begin
                     QSPI_DR0_next[7:0] = buffer[47:40];
                     QSPI_DR0_next[15:8] = buffer[39:32];
                     QSPI_DR0_next[23:16] = buffer[31:24];
                     QSPI_DR0_next[31:24] = buffer[23:16];
                     QSPI_DR1_next[7:0] = buffer[15:8];
                     QSPI_DR1_next[15:8] = buffer[7:0];
                  end
                  if(QSPI_CCR_DATA_SIZE >= 6) begin
                     QSPI_DR0_next[7:0] = buffer[55:48];
                     QSPI_DR0_next[15:8] = buffer[47:40];
                     QSPI_DR0_next[23:16] = buffer[39:32];
                     QSPI_DR0_next[31:24] = buffer[31:24];
                     QSPI_DR1_next[7:0] = buffer[23:16];
                     QSPI_DR1_next[15:8] = buffer[15:8];
                     QSPI_DR1_next[23:16] = buffer[7:0];
                  end
                  if(QSPI_CCR_DATA_SIZE >= 7) begin
                     QSPI_DR0_next[7:0] = buffer[63:56];
                     QSPI_DR0_next[15:8] = buffer[55:48];
                     QSPI_DR0_next[23:16] = buffer[47:40];
                     QSPI_DR0_next[31:24] = buffer[39:32];
                     QSPI_DR1_next[7:0] = buffer[31:24];
                     QSPI_DR1_next[15:8] = buffer[23:16];
                     QSPI_DR1_next[23:16] = buffer[15:8];
                     QSPI_DR1_next[31:24] = buffer[7:0];
                  end

                  if(QSPI_CCR_DATA_SIZE >= 8) begin
                     QSPI_DR0_next[7:0] = buffer[71:64];
                     QSPI_DR0_next[15:8] = buffer[63:56];
                     QSPI_DR0_next[23:16] = buffer[55:48];
                     QSPI_DR0_next[31:24] = buffer[47:40];
                     QSPI_DR1_next[7:0] = buffer[39:32];
                     QSPI_DR1_next[15:8] = buffer[31:24];
                     QSPI_DR1_next[23:16] = buffer[23:16];
                     QSPI_DR1_next[31:24] = buffer[15:8];
                     QSPI_DR2_next[7:0] = buffer[7:0];
                     QSPI_DR2_next[31:8] = 0;
                  end
                  if(QSPI_CCR_DATA_SIZE >= 9) begin
                     QSPI_DR0_next[7:0] = buffer[79:72];
                     QSPI_DR0_next[15:8] = buffer[71:64];
                     QSPI_DR0_next[23:16] = buffer[63:56];
                     QSPI_DR0_next[31:24] = buffer[55:48];
                     QSPI_DR1_next[7:0] = buffer[47:40];
                     QSPI_DR1_next[15:8] = buffer[39:32];
                     QSPI_DR1_next[23:16] = buffer[31:24];
                     QSPI_DR1_next[31:24] = buffer[23:16];
                     QSPI_DR2_next[7:0] = buffer[15:8];
                     QSPI_DR2_next[15:8] = buffer[7:0];
                  end
                  if(QSPI_CCR_DATA_SIZE >= 10) begin
                     QSPI_DR0_next[7:0] = buffer[87:80];
                     QSPI_DR0_next[15:8] = buffer[79:72];
                     QSPI_DR0_next[23:16] = buffer[71:64];
                     QSPI_DR0_next[31:24] = buffer[63:56];
                     QSPI_DR1_next[7:0] = buffer[55:48];
                     QSPI_DR1_next[15:8] = buffer[47:40];
                     QSPI_DR1_next[23:16] = buffer[39:32];
                     QSPI_DR1_next[31:24] = buffer[31:24];
                     QSPI_DR2_next[7:0] = buffer[23:16];
                     QSPI_DR2_next[15:8] = buffer[15:8];
                     QSPI_DR2_next[23:16] = buffer[7:0];
                  end
                  if(QSPI_CCR_DATA_SIZE >= 11) begin
                     QSPI_DR0_next[7:0] = buffer[95:88];
                     QSPI_DR0_next[15:8] = buffer[87:80];
                     QSPI_DR0_next[23:16] = buffer[79:72];
                     QSPI_DR0_next[31:24] = buffer[71:64];
                     QSPI_DR1_next[7:0] = buffer[63:56];
                     QSPI_DR1_next[15:8] = buffer[55:48];
                     QSPI_DR1_next[23:16] = buffer[47:40];
                     QSPI_DR1_next[31:24] = buffer[39:32];
                     QSPI_DR2_next[7:0] = buffer[31:24];
                     QSPI_DR2_next[15:8] = buffer[23:16];
                     QSPI_DR2_next[23:16] = buffer[15:8];
                     QSPI_DR2_next[31:24] = buffer[7:0];
                  end

                  if(QSPI_CCR_DATA_SIZE >= 12) begin
                     QSPI_DR0_next[7:0] = buffer[103:96];
                     QSPI_DR0_next[15:8] = buffer[95:88];
                     QSPI_DR0_next[23:16] = buffer[87:80];
                     QSPI_DR0_next[31:24] = buffer[79:72];
                     QSPI_DR1_next[7:0] = buffer[71:64];
                     QSPI_DR1_next[15:8] = buffer[63:56];
                     QSPI_DR1_next[23:16] = buffer[55:48];
                     QSPI_DR1_next[31:24] = buffer[47:40];
                     QSPI_DR2_next[7:0] = buffer[39:32];
                     QSPI_DR2_next[15:8] = buffer[31:24];
                     QSPI_DR2_next[23:16] = buffer[23:16];
                     QSPI_DR2_next[31:24] = buffer[15:8];
                     QSPI_DR3_next[7:0] = buffer[7:0];
                     QSPI_DR3_next[31:8] = 0;
                  end
                  if(QSPI_CCR_DATA_SIZE >= 13) begin
                     QSPI_DR0_next[7:0] = buffer[111:104];
                     QSPI_DR0_next[15:8] = buffer[103:96];
                     QSPI_DR0_next[23:16] = buffer[95:88];
                     QSPI_DR0_next[31:24] = buffer[87:80];
                     QSPI_DR1_next[7:0] = buffer[79:72];
                     QSPI_DR1_next[15:8] = buffer[71:64];
                     QSPI_DR1_next[23:16] = buffer[63:56];
                     QSPI_DR1_next[31:24] = buffer[55:48];
                     QSPI_DR2_next[7:0] = buffer[47:40];
                     QSPI_DR2_next[15:8] = buffer[39:32];
                     QSPI_DR2_next[23:16] = buffer[31:24];
                     QSPI_DR2_next[31:24] = buffer[23:16];
                     QSPI_DR3_next[7:0] = buffer[15:8];
                     QSPI_DR3_next[15:8] = buffer[7:0];
                  end
                  if(QSPI_CCR_DATA_SIZE >= 14) begin
                     QSPI_DR0_next[7:0] = buffer[119:112];
                     QSPI_DR0_next[15:8] = buffer[111:104];
                     QSPI_DR0_next[23:16] = buffer[103:96];
                     QSPI_DR0_next[31:24] = buffer[95:88];
                     QSPI_DR1_next[7:0] = buffer[87:80];
                     QSPI_DR1_next[15:8] = buffer[79:72];
                     QSPI_DR1_next[23:16] = buffer[71:64];
                     QSPI_DR1_next[31:24] = buffer[63:56];
                     QSPI_DR2_next[7:0] = buffer[55:48];
                     QSPI_DR2_next[15:8] = buffer[47:40];
                     QSPI_DR2_next[23:16] = buffer[39:32];
                     QSPI_DR2_next[31:24] = buffer[31:24];
                     QSPI_DR3_next[7:0] = buffer[23:16];
                     QSPI_DR3_next[15:8] = buffer[15:8];
                     QSPI_DR3_next[23:16] = buffer[7:0];
                  end
                  if(QSPI_CCR_DATA_SIZE >= 15) begin
                     QSPI_DR0_next[7:0] = buffer[127:120];
                     QSPI_DR0_next[15:8] = buffer[119:112];
                     QSPI_DR0_next[23:16] = buffer[111:104];
                     QSPI_DR0_next[31:24] = buffer[103:96];
                     QSPI_DR1_next[7:0] = buffer[95:88];
                     QSPI_DR1_next[15:8] = buffer[87:80];
                     QSPI_DR1_next[23:16] = buffer[79:72];
                     QSPI_DR1_next[31:24] = buffer[71:64];
                     QSPI_DR2_next[7:0] = buffer[63:56];
                     QSPI_DR2_next[15:8] = buffer[55:48];
                     QSPI_DR2_next[23:16] = buffer[47:40];
                     QSPI_DR2_next[31:24] = buffer[39:32];
                     QSPI_DR3_next[7:0] = buffer[31:24];
                     QSPI_DR3_next[15:8] = buffer[23:16];
                     QSPI_DR3_next[23:16] = buffer[15:8];
                     QSPI_DR3_next[31:24] = buffer[7:0];
                  end

                  if(QSPI_CCR_DATA_SIZE >= 16) begin
                     QSPI_DR0_next[7:0] = buffer[135:128];
                     QSPI_DR0_next[15:8] = buffer[127:120];
                     QSPI_DR0_next[23:16] = buffer[119:112];
                     QSPI_DR0_next[31:24] = buffer[111:104];
                     QSPI_DR1_next[7:0] = buffer[103:96];
                     QSPI_DR1_next[15:8] = buffer[95:88];
                     QSPI_DR1_next[23:16] = buffer[87:80];
                     QSPI_DR1_next[31:24] = buffer[79:72];
                     QSPI_DR2_next[7:0] = buffer[71:64];
                     QSPI_DR2_next[15:8] = buffer[63:56];
                     QSPI_DR2_next[23:16] = buffer[55:48];
                     QSPI_DR2_next[31:24] = buffer[47:40];
                     QSPI_DR3_next[7:0] = buffer[39:32];
                     QSPI_DR3_next[15:8] = buffer[31:24];
                     QSPI_DR3_next[23:16] = buffer[23:16];
                     QSPI_DR3_next[31:24] = buffer[15:8];
                     QSPI_DR4_next[7:0] = buffer[7:0];
                     QSPI_DR4_next[31:8] = 0;
                  end
                  if(QSPI_CCR_DATA_SIZE >= 17) begin
                     QSPI_DR0_next[7:0] = buffer[143:136];
                     QSPI_DR0_next[15:8] = buffer[135:128];
                     QSPI_DR0_next[23:16] = buffer[127:120];
                     QSPI_DR0_next[31:24] = buffer[119:112];
                     QSPI_DR1_next[7:0] = buffer[111:104];
                     QSPI_DR1_next[15:8] = buffer[103:96];
                     QSPI_DR1_next[23:16] = buffer[95:88];
                     QSPI_DR1_next[31:24] = buffer[87:80];
                     QSPI_DR2_next[7:0] = buffer[79:72];
                     QSPI_DR2_next[15:8] = buffer[71:64];
                     QSPI_DR2_next[23:16] = buffer[63:56];
                     QSPI_DR2_next[31:24] = buffer[55:48];
                     QSPI_DR3_next[7:0] = buffer[47:40];
                     QSPI_DR3_next[15:8] = buffer[39:32];
                     QSPI_DR3_next[23:16] = buffer[31:24];
                     QSPI_DR3_next[31:24] = buffer[23:16];
                     QSPI_DR4_next[7:0] = buffer[15:8];
                     QSPI_DR4_next[15:8] = buffer[7:0];
                  end
                  if(QSPI_CCR_DATA_SIZE >= 18) begin
                     QSPI_DR0_next[7:0] = buffer[151:144];
                     QSPI_DR0_next[15:8] = buffer[143:136];
                     QSPI_DR0_next[23:16] = buffer[135:128];
                     QSPI_DR0_next[31:24] = buffer[127:120];
                     QSPI_DR1_next[7:0] = buffer[119:112];
                     QSPI_DR1_next[15:8] = buffer[111:104];
                     QSPI_DR1_next[23:16] = buffer[103:96];
                     QSPI_DR1_next[31:24] = buffer[95:88];
                     QSPI_DR2_next[7:0] = buffer[87:80];
                     QSPI_DR2_next[15:8] = buffer[79:72];
                     QSPI_DR2_next[23:16] = buffer[71:64];
                     QSPI_DR2_next[31:24] = buffer[63:56];
                     QSPI_DR3_next[7:0] = buffer[55:48];
                     QSPI_DR3_next[15:8] = buffer[47:40];
                     QSPI_DR3_next[23:16] = buffer[39:32];
                     QSPI_DR3_next[31:24] = buffer[31:24];
                     QSPI_DR4_next[7:0] = buffer[23:16];
                     QSPI_DR4_next[15:8] = buffer[15:8];
                     QSPI_DR4_next[23:16] = buffer[7:0];
                  end
                  if(QSPI_CCR_DATA_SIZE >= 19) begin
                     QSPI_DR0_next[7:0] = buffer[159:152];
                     QSPI_DR0_next[15:8] = buffer[151:144];
                     QSPI_DR0_next[23:16] = buffer[143:136];
                     QSPI_DR0_next[31:24] = buffer[135:128];
                     QSPI_DR1_next[7:0] = buffer[127:120];
                     QSPI_DR1_next[15:8] = buffer[119:112];
                     QSPI_DR1_next[23:16] = buffer[111:104];
                     QSPI_DR1_next[31:24] = buffer[103:96];
                     QSPI_DR2_next[7:0] = buffer[95:88];
                     QSPI_DR2_next[15:8] = buffer[87:80];
                     QSPI_DR2_next[23:16] = buffer[79:72];
                     QSPI_DR2_next[31:24] = buffer[71:64];
                     QSPI_DR3_next[7:0] = buffer[63:56];
                     QSPI_DR3_next[15:8] = buffer[55:48];
                     QSPI_DR3_next[23:16] = buffer[47:40];
                     QSPI_DR3_next[31:24] = buffer[39:32];
                     QSPI_DR4_next[7:0] = buffer[31:24];
                     QSPI_DR4_next[15:8] = buffer[23:16];
                     QSPI_DR4_next[23:16] = buffer[15:8];
                     QSPI_DR4_next[31:24] = buffer[7:0];
                  end

                  if(QSPI_CCR_DATA_SIZE >= 20) begin
                     QSPI_DR0_next[7:0] = buffer[167:160];
                     QSPI_DR0_next[15:8] = buffer[159:152];
                     QSPI_DR0_next[23:16] = buffer[151:144];
                     QSPI_DR0_next[31:24] = buffer[143:136];
                     QSPI_DR1_next[7:0] = buffer[135:128];
                     QSPI_DR1_next[15:8] = buffer[127:120];
                     QSPI_DR1_next[23:16] = buffer[119:112];
                     QSPI_DR1_next[31:24] = buffer[111:104];
                     QSPI_DR2_next[7:0] = buffer[103:96];
                     QSPI_DR2_next[15:8] = buffer[95:88];
                     QSPI_DR2_next[23:16] = buffer[87:80];
                     QSPI_DR2_next[31:24] = buffer[79:72];
                     QSPI_DR3_next[7:0] = buffer[71:64];
                     QSPI_DR3_next[15:8] = buffer[63:56];
                     QSPI_DR3_next[23:16] = buffer[55:48];
                     QSPI_DR3_next[31:24] = buffer[47:40];
                     QSPI_DR4_next[7:0] = buffer[39:32];
                     QSPI_DR4_next[15:8] = buffer[31:24];
                     QSPI_DR4_next[23:16] = buffer[23:16];
                     QSPI_DR4_next[31:24] = buffer[15:8];
                     QSPI_DR5_next[7:0] = buffer[7:0];
                     QSPI_DR5_next[31:8] = 0;
                  end
                  if(QSPI_CCR_DATA_SIZE >= 21) begin
                     QSPI_DR0_next[7:0] = buffer[175:168];
                     QSPI_DR0_next[15:8] = buffer[167:160];
                     QSPI_DR0_next[23:16] = buffer[159:152];
                     QSPI_DR0_next[31:24] = buffer[151:144];
                     QSPI_DR1_next[7:0] = buffer[143:136];
                     QSPI_DR1_next[15:8] = buffer[135:128];
                     QSPI_DR1_next[23:16] = buffer[127:120];
                     QSPI_DR1_next[31:24] = buffer[119:112];
                     QSPI_DR2_next[7:0] = buffer[111:104];
                     QSPI_DR2_next[15:8] = buffer[103:96];
                     QSPI_DR2_next[23:16] = buffer[95:88];
                     QSPI_DR2_next[31:24] = buffer[87:80];
                     QSPI_DR3_next[7:0] = buffer[79:72];
                     QSPI_DR3_next[15:8] = buffer[71:64];
                     QSPI_DR3_next[23:16] = buffer[63:56];
                     QSPI_DR3_next[31:24] = buffer[55:48];
                     QSPI_DR4_next[7:0] = buffer[47:40];
                     QSPI_DR4_next[15:8] = buffer[39:32];
                     QSPI_DR4_next[23:16] = buffer[31:24];
                     QSPI_DR4_next[31:24] = buffer[23:16];
                     QSPI_DR5_next[7:0] = buffer[15:8];
                     QSPI_DR5_next[15:8] = buffer[7:0];
                  end
                  if(QSPI_CCR_DATA_SIZE >= 22) begin
                     QSPI_DR0_next[7:0] = buffer[183:176];
                     QSPI_DR0_next[15:8] = buffer[175:168];
                     QSPI_DR0_next[23:16] = buffer[167:160];
                     QSPI_DR0_next[31:24] = buffer[159:152];
                     QSPI_DR1_next[7:0] = buffer[151:144];
                     QSPI_DR1_next[15:8] = buffer[143:136];
                     QSPI_DR1_next[23:16] = buffer[135:128];
                     QSPI_DR1_next[31:24] = buffer[127:120];
                     QSPI_DR2_next[7:0] = buffer[119:112];
                     QSPI_DR2_next[15:8] = buffer[111:104];
                     QSPI_DR2_next[23:16] = buffer[103:96];
                     QSPI_DR2_next[31:24] = buffer[95:88];
                     QSPI_DR3_next[7:0] = buffer[87:80];
                     QSPI_DR3_next[15:8] = buffer[79:72];
                     QSPI_DR3_next[23:16] = buffer[71:64];
                     QSPI_DR3_next[31:24] = buffer[63:56];
                     QSPI_DR4_next[7:0] = buffer[55:48];
                     QSPI_DR4_next[15:8] = buffer[47:40];
                     QSPI_DR4_next[23:16] = buffer[39:32];
                     QSPI_DR4_next[31:24] = buffer[31:24];
                     QSPI_DR5_next[7:0] = buffer[23:16];
                     QSPI_DR5_next[15:8] = buffer[15:8];
                     QSPI_DR5_next[23:16] = buffer[7:0];
                  end
                  if(QSPI_CCR_DATA_SIZE >= 23) begin
                     QSPI_DR0_next[7:0] = buffer[191:184];
                     QSPI_DR0_next[15:8] = buffer[183:176];
                     QSPI_DR0_next[23:16] = buffer[175:168];
                     QSPI_DR0_next[31:24] = buffer[167:160];
                     QSPI_DR1_next[7:0] = buffer[159:152];
                     QSPI_DR1_next[15:8] = buffer[151:144];
                     QSPI_DR1_next[23:16] = buffer[143:136];
                     QSPI_DR1_next[31:24] = buffer[135:128];
                     QSPI_DR2_next[7:0] = buffer[127:120];
                     QSPI_DR2_next[15:8] = buffer[119:112];
                     QSPI_DR2_next[23:16] = buffer[111:104];
                     QSPI_DR2_next[31:24] = buffer[103:96];
                     QSPI_DR3_next[7:0] = buffer[95:88];
                     QSPI_DR3_next[15:8] = buffer[87:80];
                     QSPI_DR3_next[23:16] = buffer[79:72];
                     QSPI_DR3_next[31:24] = buffer[71:64];
                     QSPI_DR4_next[7:0] = buffer[63:56];
                     QSPI_DR4_next[15:8] = buffer[55:48];
                     QSPI_DR4_next[23:16] = buffer[47:40];
                     QSPI_DR4_next[31:24] = buffer[39:32];
                     QSPI_DR5_next[7:0] = buffer[31:24];
                     QSPI_DR5_next[15:8] = buffer[23:16];
                     QSPI_DR5_next[23:16] = buffer[15:8];
                     QSPI_DR5_next[31:24] = buffer[7:0];
                  end

                  if(QSPI_CCR_DATA_SIZE >= 24) begin
                     QSPI_DR0_next[7:0] = buffer[199:192];
                     QSPI_DR0_next[15:8] = buffer[191:184];
                     QSPI_DR0_next[23:16] = buffer[183:176];
                     QSPI_DR0_next[31:24] = buffer[175:168];
                     QSPI_DR1_next[7:0] = buffer[167:160];
                     QSPI_DR1_next[15:8] = buffer[159:152];
                     QSPI_DR1_next[23:16] = buffer[151:144];
                     QSPI_DR1_next[31:24] = buffer[143:136];
                     QSPI_DR2_next[7:0] = buffer[135:128];
                     QSPI_DR2_next[15:8] = buffer[127:120];
                     QSPI_DR2_next[23:16] = buffer[119:112];
                     QSPI_DR2_next[31:24] = buffer[111:104];
                     QSPI_DR3_next[7:0] = buffer[103:96];
                     QSPI_DR3_next[15:8] = buffer[95:88];
                     QSPI_DR3_next[23:16] = buffer[87:80];
                     QSPI_DR3_next[31:24] = buffer[79:72];
                     QSPI_DR4_next[7:0] = buffer[71:64];
                     QSPI_DR4_next[15:8] = buffer[63:56];
                     QSPI_DR4_next[23:16] = buffer[55:48];
                     QSPI_DR4_next[31:24] = buffer[47:40];
                     QSPI_DR5_next[7:0] = buffer[39:32];
                     QSPI_DR5_next[15:8] = buffer[31:24];
                     QSPI_DR5_next[23:16] = buffer[23:16];
                     QSPI_DR5_next[31:24] = buffer[15:8];
                     QSPI_DR6_next[7:0] = buffer[7:0];
                     QSPI_DR6_next[31:8] = 0;
                  end
                  if(QSPI_CCR_DATA_SIZE >= 25) begin
                     QSPI_DR0_next[7:0] = buffer[207:200];
                     QSPI_DR0_next[15:8] = buffer[199:192];
                     QSPI_DR0_next[23:16] = buffer[191:184];
                     QSPI_DR0_next[31:24] = buffer[183:176];
                     QSPI_DR1_next[7:0] = buffer[175:168];
                     QSPI_DR1_next[15:8] = buffer[167:160];
                     QSPI_DR1_next[23:16] = buffer[159:152];
                     QSPI_DR1_next[31:24] = buffer[151:144];
                     QSPI_DR2_next[7:0] = buffer[143:136];
                     QSPI_DR2_next[15:8] = buffer[135:128];
                     QSPI_DR2_next[23:16] = buffer[127:120];
                     QSPI_DR2_next[31:24] = buffer[119:112];
                     QSPI_DR3_next[7:0] = buffer[111:104];
                     QSPI_DR3_next[15:8] = buffer[103:96];
                     QSPI_DR3_next[23:16] = buffer[95:88];
                     QSPI_DR3_next[31:24] = buffer[87:80];
                     QSPI_DR4_next[7:0] = buffer[79:72];
                     QSPI_DR4_next[15:8] = buffer[71:64];
                     QSPI_DR4_next[23:16] = buffer[63:56];
                     QSPI_DR4_next[31:24] = buffer[55:48];
                     QSPI_DR5_next[7:0] = buffer[47:40];
                     QSPI_DR5_next[15:8] = buffer[39:32];
                     QSPI_DR5_next[23:16] = buffer[31:24];
                     QSPI_DR5_next[31:24] = buffer[23:16];
                     QSPI_DR6_next[7:0] = buffer[15:8];
                     QSPI_DR6_next[15:8] = buffer[7:0];
                  end
                  if(QSPI_CCR_DATA_SIZE >= 26) begin
                     QSPI_DR0_next[7:0] = buffer[215:208];
                     QSPI_DR0_next[15:8] = buffer[207:200];
                     QSPI_DR0_next[23:16] = buffer[199:192];
                     QSPI_DR0_next[31:24] = buffer[191:184];
                     QSPI_DR1_next[7:0] = buffer[183:176];
                     QSPI_DR1_next[15:8] = buffer[175:168];
                     QSPI_DR1_next[23:16] = buffer[167:160];
                     QSPI_DR1_next[31:24] = buffer[159:152];
                     QSPI_DR2_next[7:0] = buffer[151:144];
                     QSPI_DR2_next[15:8] = buffer[143:136];
                     QSPI_DR2_next[23:16] = buffer[135:128];
                     QSPI_DR2_next[31:24] = buffer[127:120];
                     QSPI_DR3_next[7:0] = buffer[119:112];
                     QSPI_DR3_next[15:8] = buffer[111:104];
                     QSPI_DR3_next[23:16] = buffer[103:96];
                     QSPI_DR3_next[31:24] = buffer[95:88];
                     QSPI_DR4_next[7:0] = buffer[87:80];
                     QSPI_DR4_next[15:8] = buffer[79:72];
                     QSPI_DR4_next[23:16] = buffer[71:64];
                     QSPI_DR4_next[31:24] = buffer[63:56];
                     QSPI_DR5_next[7:0] = buffer[55:48];
                     QSPI_DR5_next[15:8] = buffer[47:40];
                     QSPI_DR5_next[23:16] = buffer[39:32];
                     QSPI_DR5_next[31:24] = buffer[31:24];
                     QSPI_DR6_next[7:0] = buffer[23:16];
                     QSPI_DR6_next[15:8] = buffer[15:8];
                     QSPI_DR6_next[23:16] = buffer[7:0];
                  end
                  if(QSPI_CCR_DATA_SIZE >= 27) begin
                     QSPI_DR0_next[7:0] = buffer[223:216];
                     QSPI_DR0_next[15:8] = buffer[215:208];
                     QSPI_DR0_next[23:16] = buffer[207:200];
                     QSPI_DR0_next[31:24] = buffer[199:192];
                     QSPI_DR1_next[7:0] = buffer[191:184];
                     QSPI_DR1_next[15:8] = buffer[183:176];
                     QSPI_DR1_next[23:16] = buffer[175:168];
                     QSPI_DR1_next[31:24] = buffer[167:160];
                     QSPI_DR2_next[7:0] = buffer[159:152];
                     QSPI_DR2_next[15:8] = buffer[151:144];
                     QSPI_DR2_next[23:16] = buffer[143:136];
                     QSPI_DR2_next[31:24] = buffer[135:128];
                     QSPI_DR3_next[7:0] = buffer[127:120];
                     QSPI_DR3_next[15:8] = buffer[119:112];
                     QSPI_DR3_next[23:16] = buffer[111:104];
                     QSPI_DR3_next[31:24] = buffer[103:96];
                     QSPI_DR4_next[7:0] = buffer[95:88];
                     QSPI_DR4_next[15:8] = buffer[87:80];
                     QSPI_DR4_next[23:16] = buffer[79:72];
                     QSPI_DR4_next[31:24] = buffer[71:64];
                     QSPI_DR5_next[7:0] = buffer[63:56];
                     QSPI_DR5_next[15:8] = buffer[55:48];
                     QSPI_DR5_next[23:16] = buffer[47:40];
                     QSPI_DR5_next[31:24] = buffer[39:32];
                     QSPI_DR6_next[7:0] = buffer[31:24];
                     QSPI_DR6_next[15:8] = buffer[23:16];
                     QSPI_DR6_next[23:16] = buffer[15:8];
                     QSPI_DR6_next[31:24] = buffer[7:0];
                  end

                  if(QSPI_CCR_DATA_SIZE >= 28) begin
                     QSPI_DR0_next[7:0] = buffer[231:224];
                     QSPI_DR0_next[15:8] = buffer[223:216];
                     QSPI_DR0_next[23:16] = buffer[215:208];
                     QSPI_DR0_next[31:24] = buffer[207:200];
                     QSPI_DR1_next[7:0] = buffer[199:192];
                     QSPI_DR1_next[15:8] = buffer[191:184];
                     QSPI_DR1_next[23:16] = buffer[183:176];
                     QSPI_DR1_next[31:24] = buffer[175:168];
                     QSPI_DR2_next[7:0] = buffer[167:160];
                     QSPI_DR2_next[15:8] = buffer[159:152];
                     QSPI_DR2_next[23:16] = buffer[151:144];
                     QSPI_DR2_next[31:24] = buffer[143:136];
                     QSPI_DR3_next[7:0] = buffer[135:128];
                     QSPI_DR3_next[15:8] = buffer[127:120];
                     QSPI_DR3_next[23:16] = buffer[119:112];
                     QSPI_DR3_next[31:24] = buffer[111:104];
                     QSPI_DR4_next[7:0] = buffer[103:96];
                     QSPI_DR4_next[15:8] = buffer[95:88];
                     QSPI_DR4_next[23:16] = buffer[87:80];
                     QSPI_DR4_next[31:24] = buffer[79:72];
                     QSPI_DR5_next[7:0] = buffer[71:64];
                     QSPI_DR5_next[15:8] = buffer[63:56];
                     QSPI_DR5_next[23:16] = buffer[55:48];
                     QSPI_DR5_next[31:24] = buffer[47:40];
                     QSPI_DR6_next[7:0] = buffer[39:32];
                     QSPI_DR6_next[15:8] = buffer[31:24];
                     QSPI_DR6_next[23:16] = buffer[23:16];
                     QSPI_DR6_next[31:24] = buffer[15:8];
                     QSPI_DR7_next[7:0] = buffer[7:0];
                     QSPI_DR7_next[31:8] = 0;
                  end
                  if(QSPI_CCR_DATA_SIZE >= 29) begin
                     QSPI_DR0_next[7:0] = buffer[239:232];
                     QSPI_DR0_next[15:8] = buffer[231:224];
                     QSPI_DR0_next[23:16] = buffer[223:216];
                     QSPI_DR0_next[31:24] = buffer[215:208];
                     QSPI_DR1_next[7:0] = buffer[207:200];
                     QSPI_DR1_next[15:8] = buffer[199:192];
                     QSPI_DR1_next[23:16] = buffer[191:184];
                     QSPI_DR1_next[31:24] = buffer[183:176];
                     QSPI_DR2_next[7:0] = buffer[175:168];
                     QSPI_DR2_next[15:8] = buffer[167:160];
                     QSPI_DR2_next[23:16] = buffer[159:152];
                     QSPI_DR2_next[31:24] = buffer[151:144];
                     QSPI_DR3_next[7:0] = buffer[143:136];
                     QSPI_DR3_next[15:8] = buffer[135:128];
                     QSPI_DR3_next[23:16] = buffer[127:120];
                     QSPI_DR3_next[31:24] = buffer[119:112];
                     QSPI_DR4_next[7:0] = buffer[111:104];
                     QSPI_DR4_next[15:8] = buffer[103:96];
                     QSPI_DR4_next[23:16] = buffer[95:88];
                     QSPI_DR4_next[31:24] = buffer[87:80];
                     QSPI_DR5_next[7:0] = buffer[79:72];
                     QSPI_DR5_next[15:8] = buffer[71:64];
                     QSPI_DR5_next[23:16] = buffer[63:56];
                     QSPI_DR5_next[31:24] = buffer[55:48];
                     QSPI_DR6_next[7:0] = buffer[47:40];
                     QSPI_DR6_next[15:8] = buffer[39:32];
                     QSPI_DR6_next[23:16] = buffer[31:24];
                     QSPI_DR6_next[31:24] = buffer[23:16];
                     QSPI_DR7_next[7:0] = buffer[15:8];
                     QSPI_DR7_next[15:8] = buffer[7:0];
                  end
                  if(QSPI_CCR_DATA_SIZE >= 30) begin
                     QSPI_DR0_next[7:0] = buffer[247:240];
                     QSPI_DR0_next[15:8] = buffer[239:232];
                     QSPI_DR0_next[23:16] = buffer[231:224];
                     QSPI_DR0_next[31:24] = buffer[223:216];
                     QSPI_DR1_next[7:0] = buffer[215:208];
                     QSPI_DR1_next[15:8] = buffer[207:200];
                     QSPI_DR1_next[23:16] = buffer[199:192];
                     QSPI_DR1_next[31:24] = buffer[191:184];
                     QSPI_DR2_next[7:0] = buffer[183:176];
                     QSPI_DR2_next[15:8] = buffer[175:168];
                     QSPI_DR2_next[23:16] = buffer[167:160];
                     QSPI_DR2_next[31:24] = buffer[159:152];
                     QSPI_DR3_next[7:0] = buffer[151:144];
                     QSPI_DR3_next[15:8] = buffer[143:136];
                     QSPI_DR3_next[23:16] = buffer[135:128];
                     QSPI_DR3_next[31:24] = buffer[127:120];
                     QSPI_DR4_next[7:0] = buffer[119:112];
                     QSPI_DR4_next[15:8] = buffer[111:104];
                     QSPI_DR4_next[23:16] = buffer[103:96];
                     QSPI_DR4_next[31:24] = buffer[95:88];
                     QSPI_DR5_next[7:0] = buffer[87:80];
                     QSPI_DR5_next[15:8] = buffer[79:72];
                     QSPI_DR5_next[23:16] = buffer[71:64];
                     QSPI_DR5_next[31:24] = buffer[63:56];
                     QSPI_DR6_next[7:0] = buffer[55:48];
                     QSPI_DR6_next[15:8] = buffer[47:40];
                     QSPI_DR6_next[23:16] = buffer[39:32];
                     QSPI_DR6_next[31:24] = buffer[31:24];
                     QSPI_DR7_next[7:0] = buffer[23:16];
                     QSPI_DR7_next[15:8] = buffer[15:8];
                     QSPI_DR7_next[23:16] = buffer[7:0];
                  end
                  if(QSPI_CCR_DATA_SIZE >= 31) begin
                     QSPI_DR0_next[7:0] = buffer[255:248];
                     QSPI_DR0_next[15:8] = buffer[247:240];
                     QSPI_DR0_next[23:16] = buffer[239:232];
                     QSPI_DR0_next[31:24] = buffer[231:224];
                     QSPI_DR1_next[7:0] = buffer[223:216];
                     QSPI_DR1_next[15:8] = buffer[215:208];
                     QSPI_DR1_next[23:16] = buffer[207:200];
                     QSPI_DR1_next[31:24] = buffer[199:192];
                     QSPI_DR2_next[7:0] = buffer[191:184];
                     QSPI_DR2_next[15:8] = buffer[183:176];
                     QSPI_DR2_next[23:16] = buffer[175:168];
                     QSPI_DR2_next[31:24] = buffer[167:160];
                     QSPI_DR3_next[7:0] = buffer[159:152];
                     QSPI_DR3_next[15:8] = buffer[151:144];
                     QSPI_DR3_next[23:16] = buffer[143:136];
                     QSPI_DR3_next[31:24] = buffer[135:128];
                     QSPI_DR4_next[7:0] = buffer[127:120];
                     QSPI_DR4_next[15:8] = buffer[119:112];
                     QSPI_DR4_next[23:16] = buffer[111:104];
                     QSPI_DR4_next[31:24] = buffer[103:96];
                     QSPI_DR5_next[7:0] = buffer[95:88];
                     QSPI_DR5_next[15:8] = buffer[87:80];
                     QSPI_DR5_next[23:16] = buffer[79:72];
                     QSPI_DR5_next[31:24] = buffer[71:64];
                     QSPI_DR6_next[7:0] = buffer[63:56];
                     QSPI_DR6_next[15:8] = buffer[55:48];
                     QSPI_DR6_next[23:16] = buffer[47:40];
                     QSPI_DR6_next[31:24] = buffer[39:32];
                     QSPI_DR7_next[7:0] = buffer[31:24];
                     QSPI_DR7_next[15:8] = buffer[23:16];
                     QSPI_DR7_next[23:16] = buffer[15:8];
                     QSPI_DR7_next[31:24] = buffer[7:0];
                  end
               end
            end
         endcase
      end

      if(QSPI_CCR_CLEAR_STA) begin
         QSPI_STA_next[0] = 0;
      end

      if(wb_cyc_i) begin
         wb_ack_next_r = wb_stb_i & !wb_ack_r;
         // Write to control registers
         if(wb_stb_i & wb_we_i & !wb_ack_o) begin
            case(wb_adr_i)
               8'h00: begin
                  QSPI_CCR_next[ 7: 0] = wb_sel_i[0] ? wb_dat_i[ 7: 0] : QSPI_CCR[ 7: 0];
                  QSPI_CCR_next[15: 8] = wb_sel_i[1] ? wb_dat_i[15: 8] : QSPI_CCR[15: 8];
                  QSPI_CCR_next[23:16] = wb_sel_i[2] ? wb_dat_i[23:16] : QSPI_CCR[23:16];
                  QSPI_CCR_next[31:24] = wb_sel_i[3] ? wb_dat_i[31:24] : QSPI_CCR[31:24];
               end
               8'h04: begin
                  QSPI_ADR_next[ 7: 0] = wb_sel_i[0] ? wb_dat_i[ 7: 0] : QSPI_ADR[ 7: 0];
                  QSPI_ADR_next[15: 8] = wb_sel_i[1] ? wb_dat_i[15: 8] : QSPI_ADR[15: 8];
                  QSPI_ADR_next[23:16] = wb_sel_i[2] ? wb_dat_i[23:16] : QSPI_ADR[23:16];
                  //QSPI_ADR_next[31:24] = wb_sel_i[3] ? wb_dat_i[31:24] : QSPI_ADR[31:24];
               end
               8'h08: begin
                  QSPI_DR0_next[ 7: 0] = wb_sel_i[0] ? wb_dat_i[ 7: 0] : QSPI_DR0[ 7: 0];
                  QSPI_DR0_next[15: 8] = wb_sel_i[1] ? wb_dat_i[15: 8] : QSPI_DR0[15: 8];
                  QSPI_DR0_next[23:16] = wb_sel_i[2] ? wb_dat_i[23:16] : QSPI_DR0[23:16];
                  QSPI_DR0_next[31:24] = wb_sel_i[3] ? wb_dat_i[31:24] : QSPI_DR0[31:24];
               end
               8'h0C: begin
                  QSPI_DR1_next[ 7: 0] = wb_sel_i[0] ? wb_dat_i[ 7: 0] : QSPI_DR1[ 7: 0];
                  QSPI_DR1_next[15: 8] = wb_sel_i[1] ? wb_dat_i[15: 8] : QSPI_DR1[15: 8];
                  QSPI_DR1_next[23:16] = wb_sel_i[2] ? wb_dat_i[23:16] : QSPI_DR1[23:16];
                  QSPI_DR1_next[31:24] = wb_sel_i[3] ? wb_dat_i[31:24] : QSPI_DR1[31:24];
               end
               8'h10: begin
                  QSPI_DR2_next[ 7: 0] = wb_sel_i[0] ? wb_dat_i[ 7: 0] : QSPI_DR2[ 7: 0];
                  QSPI_DR2_next[15: 8] = wb_sel_i[1] ? wb_dat_i[15: 8] : QSPI_DR2[15: 8];
                  QSPI_DR2_next[23:16] = wb_sel_i[2] ? wb_dat_i[23:16] : QSPI_DR2[23:16];
                  QSPI_DR2_next[31:24] = wb_sel_i[3] ? wb_dat_i[31:24] : QSPI_DR2[31:24];
               end
               8'h14: begin
                  QSPI_DR3_next[ 7: 0] = wb_sel_i[0] ? wb_dat_i[ 7: 0] : QSPI_DR3[ 7: 0];
                  QSPI_DR3_next[15: 8] = wb_sel_i[1] ? wb_dat_i[15: 8] : QSPI_DR3[15: 8];
                  QSPI_DR3_next[23:16] = wb_sel_i[2] ? wb_dat_i[23:16] : QSPI_DR3[23:16];
                  QSPI_DR3_next[31:24] = wb_sel_i[3] ? wb_dat_i[31:24] : QSPI_DR3[31:24];
               end
               8'h18: begin
                  QSPI_DR4_next[ 7: 0] = wb_sel_i[0] ? wb_dat_i[ 7: 0] : QSPI_DR4[ 7: 0];
                  QSPI_DR4_next[15: 8] = wb_sel_i[1] ? wb_dat_i[15: 8] : QSPI_DR4[15: 8];
                  QSPI_DR4_next[23:16] = wb_sel_i[2] ? wb_dat_i[23:16] : QSPI_DR4[23:16];
                  QSPI_DR4_next[31:24] = wb_sel_i[3] ? wb_dat_i[31:24] : QSPI_DR4[31:24];
               end
               8'h1C: begin
                  QSPI_DR5_next[ 7: 0] = wb_sel_i[0] ? wb_dat_i[ 7: 0] : QSPI_DR5[ 7: 0];
                  QSPI_DR5_next[15: 8] = wb_sel_i[1] ? wb_dat_i[15: 8] : QSPI_DR5[15: 8];
                  QSPI_DR5_next[23:16] = wb_sel_i[2] ? wb_dat_i[23:16] : QSPI_DR5[23:16];
                  QSPI_DR5_next[31:24] = wb_sel_i[3] ? wb_dat_i[31:24] : QSPI_DR5[31:24];
               end
               8'h20: begin
                  QSPI_DR6_next[ 7: 0] = wb_sel_i[0] ? wb_dat_i[ 7: 0] : QSPI_DR6[ 7: 0];
                  QSPI_DR6_next[15: 8] = wb_sel_i[1] ? wb_dat_i[15: 8] : QSPI_DR6[15: 8];
                  QSPI_DR6_next[23:16] = wb_sel_i[2] ? wb_dat_i[23:16] : QSPI_DR6[23:16];
                  QSPI_DR6_next[31:24] = wb_sel_i[3] ? wb_dat_i[31:24] : QSPI_DR6[31:24];
               end
               8'h24: begin
                  QSPI_DR7_next[ 7: 0] = wb_sel_i[0] ? wb_dat_i[ 7: 0] : QSPI_DR7[ 7: 0];
                  QSPI_DR7_next[15: 8] = wb_sel_i[1] ? wb_dat_i[15: 8] : QSPI_DR7[15: 8];
                  QSPI_DR7_next[23:16] = wb_sel_i[2] ? wb_dat_i[23:16] : QSPI_DR7[23:16];
                  QSPI_DR7_next[31:24] = wb_sel_i[3] ? wb_dat_i[31:24] : QSPI_DR7[31:24];
               end

               // QSPI_STA --> Read only
            endcase
         end
         // Read from control registers
         else if(~wb_we_i) begin
            case(wb_adr_i)
               8'h00: begin wb_read_data_next_r = QSPI_CCR; end
               8'h04: begin wb_read_data_next_r = {8'h0, QSPI_ADR}; end
               8'h08: begin wb_read_data_next_r = QSPI_DR0; end
               8'h0C: begin wb_read_data_next_r = QSPI_DR1; end
               8'h10: begin wb_read_data_next_r = QSPI_DR2; end
               8'h14: begin wb_read_data_next_r = QSPI_DR3; end
               8'h18: begin wb_read_data_next_r = QSPI_DR4; end
               8'h1C: begin wb_read_data_next_r = QSPI_DR5; end
               8'h20: begin wb_read_data_next_r = QSPI_DR6; end
               8'h24: begin wb_read_data_next_r = QSPI_DR7; end
               8'h28: begin wb_read_data_next_r = {30'h0, QSPI_STA}; end
            endcase
         end
      end
   end

   always @(posedge clk_i) begin
      if(rst_i) begin
         wb_ack_r <= 1'b0;
         wb_read_data_r <= 32'h0;

         QSPI_CCR <= 0;
         QSPI_ADR <= 0;
         QSPI_DR0 <= 0;
         QSPI_DR1 <= 0;
         QSPI_DR2 <= 0;
         QSPI_DR3 <= 0;
         QSPI_DR4 <= 0;
         QSPI_DR5 <= 0;
         QSPI_DR6 <= 0;
         QSPI_DR7 <= 0;
         QSPI_STA <= 0;

         bit_counter <= 0;

         state <= IDLE;

         qspi_cs_r <= 1'b1;
         sclk <= 1'b0;

         //data_out <= 4'b0000;
         data_out_enable <= 4'b0000;

         buffer <= 0;

         bit_rate <= 0;

         new_instruction <= 1'b0;
      end
      else begin
         wb_ack_r <= wb_ack_next_r;
         wb_read_data_r <= wb_read_data_next_r;

         QSPI_CCR <= QSPI_CCR_next;
         QSPI_ADR <= QSPI_ADR_next;
         QSPI_DR0 <= QSPI_DR0_next;
         QSPI_DR1 <= QSPI_DR1_next;
         QSPI_DR2 <= QSPI_DR2_next;
         QSPI_DR3 <= QSPI_DR3_next;
         QSPI_DR4 <= QSPI_DR4_next;
         QSPI_DR5 <= QSPI_DR5_next;
         QSPI_DR6 <= QSPI_DR6_next;
         QSPI_DR7 <= QSPI_DR7_next;
         QSPI_STA <= QSPI_STA_next;

         bit_counter <= bit_counter_next;

         state <= state_next;

         qspi_cs_r <= qspi_cs_next_r;
         sclk <= sclk_next;

         //data_out <= data_out_next;
         data_out_enable <= data_out_enable_next;

         buffer <= buffer_next;

         bit_rate <= bit_rate_next;

         new_instruction <= new_instruction_next;
      end
   end

   /*
   always @(posedge clk_i) begin
      if(rst_i) begin
         qspi_data_o <= 4'b0000;
         qspi_out_mod_o <= 2'b00;
      end
      else begin
         case(data_rate)
            4: begin
               qspi_data_o <= out_buffer[31:28];
               qspi_out_mod_o <= 2'b11;
            end
            2: begin
               qspi_data_o <= {2'b00, out_buffer[31:30]};
               qspi_out_mod_o <= 2'b10;
            end
            1: begin
               qspi_data_o <= {3'b000, out_buffer[31]};
               qspi_out_mod_o <= 2'b01;
            end
         endcase
      end
   end
   */

   reg [5:0] prescaler_counter;
   wire [5:0] prescaler = (QSPI_CCR_PRESCALER > 0) ? QSPI_CCR_PRESCALER : 1;

   wire [6:0] n_total_cycles = prescaler + 1;
   wire [5:0] n_high_cycles = n_total_cycles / 2;
   wire [5:0] n_low_cycles = n_total_cycles - n_high_cycles;

   always @(posedge clk_i) begin
      if(rst_i) begin
         sck_r <= 1'b0;
         prescaler_counter <= 6'b0;
      end
      else begin
         if (sck_r == 1'b1) begin 
            if (prescaler_counter == n_high_cycles - 1) begin
               sck_r <= 1'b0;
               prescaler_counter <= 6'b0;
            end else begin
               prescaler_counter <= prescaler_counter + 1;
            end
         end else begin 
            if (prescaler_counter == n_low_cycles - 1) begin
               sck_r <= 1'b1;
               prescaler_counter <= 6'b0;
            end else begin
               prescaler_counter <= prescaler_counter + 1;
            end
         end
      end
   end

   wire system_clock_sck = ~|bit_counter | qspi_cs_n_o | clk_i;
   wire prescaled_sck = ~|bit_counter | qspi_cs_n_o | sck_r;

   assign qspi_sck_o = (QSPI_CCR_PRESCALER == 0) ? system_clock_sck : prescaled_sck; //sclk; //~qspi_cs_n_o & ~clk_i; //sck_r; //sclk; //(|bit_counter) ? ((QSPI_CCR_PRESCALER == 0) ? clk_i : sck_r) : 0; //sclk; //(state != IDLE) ? ((QSPI_CCR_PRESCALER == 0) ? clk_i : sck_r) : 0;

endmodule
