// secure_soc.sv
`timescale 1ns / 1ps

`include "header.vh"

`default_nettype none

`ifdef CORE_CVA6
`include "obi/typedef.svh"
`include "axi/typedef.svh"
`include "register_interface/typedef.svh"
`endif

module secure_soc (
   `ifdef ZC706
   input  wire clk_p,
   input  wire clk_n,
   `elsif DDR3_AXI
   input  wire clk_p,
   input  wire clk_n,
   `else
   input wire clk_i,
   `endif

   input wire rst_ni,

   //input  wire uart_rx_i,
   
   input  wire program_rx_i,
   output wire prog_mode_led_o,
   
   output wire uart_tx_o

   `ifndef ZC706
   `ifndef USE_SRAM
   `ifndef DDR3_AXI
   `ifndef QSPI_SIM
   ,output wire qspi_cs_n_o
   `ifdef EXT_FLASH
   ,output wire qspi_sck_o
   `endif
   ,inout wire [3:0] qspi_data_io
   `endif
   `endif
   `endif
   `endif

   `ifndef DRAM_SIM
   `ifdef ZC706
   ,output wire ddr3_reset_n
   ,output wire ddr3_cke
   ,output wire ddr3_ck_p
   ,output wire ddr3_ck_n
   ,output wire ddr3_cs_n
   ,output wire ddr3_ras_n
   ,output wire ddr3_cas_n
   ,output wire ddr3_we_n
   ,output wire [2:0] ddr3_ba
   ,output wire [13:0] ddr3_addr
   ,output wire ddr3_odt
   ,output wire [1:0] ddr3_dm
   ,inout wire [1:0] ddr3_dqs_p
   ,inout wire [1:0] ddr3_dqs_n
   ,inout wire [15:0] ddr3_dq
   `elsif DDR3_AXI
   `ifndef USE_SRAM
   ,output wire ddr3_reset_n
   ,output wire ddr3_cke
   ,output wire ddr3_ck_p
   ,output wire ddr3_ck_n
   ,output wire ddr3_cs_n
   ,output wire ddr3_ras_n
   ,output wire ddr3_cas_n
   ,output wire ddr3_we_n
   ,output wire [2:0] ddr3_ba
   ,output wire [13:0] ddr3_addr
   ,output wire ddr3_odt
   ,output wire [1:0] ddr3_dm
   ,inout wire [1:0] ddr3_dqs_p
   ,inout wire [1:0] ddr3_dqs_n
   ,inout wire [15:0] ddr3_dq
   `endif
   `endif
   `endif
);

// This part is common for the cores
   wire uart_rx_i;

   logic system_reset_o;
   logic uart_dram_write_rst;
   logic uart_dram_mode;
   `ifdef BASYS3
      wire clkwiz_o;
      wire clkwiz_locked;
      clk_wiz_0 dutclk (
         .clk_out1(clkwiz_o),
         .clk_in1(clk_i),
         .reset(~rst_ni),
         .locked(clkwiz_locked)
      );
      wire rst_n = rst_ni & system_reset_o & clkwiz_locked;
   `elsif ZC706
      wire pll_locked;
      wire clk100;
      wire clk_ddr;
      wire clk_ref;
      wire clk_ddr_dqs;
      wire clk_i;
      clk_wiz_0 u_pll
      //clk_wiz_1 u_pll
      (
         .clk_in1_p(clk_p),
         .clk_in1_n(clk_n)

         ,.reset(~rst_ni)

         // first values for 100mhz, second values for 50mhz
         ,.clk_out1(clk100)      // 100, 50
         ,.clk_out2(clk_ddr)     // 400, 200
         ,.clk_out3(clk_ref)     // 200, 200
         ,.clk_out4(clk_ddr_dqs) // 400, 200 (phase 90)
         ,.clk_out5(clk_i)       // 100, 50
         ,.locked(pll_locked)
      );

      wire clkwiz_o = clk_i;
      wire rst_n = rst_ni & system_reset_o & !uart_dram_mode & pll_locked;
   `elsif DDR3_AXI
      wire pll_locked;
      wire clk100;
      wire clk_ddr;
      wire clk_ref;
      wire clk_ddr_dqs;
      wire clk_i;
      clk_wiz_0 u_pll
      //clk_wiz_1 u_pll
      (
         .clk_in1_p(clk_p),
         .clk_in1_n(clk_n)

         ,.reset(~rst_ni)

         // first values for 100mhz, second values for 50mhz
         ,.clk_out1(clk100)      // 100, 50
         ,.clk_out2(clk_ddr)     // 400, 200
         ,.clk_out3(clk_ref)     // 200, 200
         ,.clk_out4(clk_ddr_dqs) // 400, 200 (phase 90)
         ,.clk_out5(clk_i)       // 100, 50
         ,.locked(pll_locked)
      );

      wire clkwiz_o = clk_i;
      wire rst_n = rst_ni & system_reset_o & pll_locked;
   `else
      wire clkwiz_o = clk_i;
      wire rst_n = rst_ni & system_reset_o;
   `endif

`ifdef CORE_CVA6
   localparam config_pkg::cva6_cfg_t CVA6Cfg = build_config_pkg::build_config(cva6_config_pkg::cva6_cfg);

   ariane_axi::req_t  cva6_axi_req;
   ariane_axi::resp_t cva6_axi_resp;

   logic [1:0] timer_irq;
   logic [1:0] ipi;

   cva6 #(
      .CVA6Cfg ( CVA6Cfg )
      ,.axi_ar_chan_t ( ariane_axi::ar_chan_t )
      ,.axi_aw_chan_t ( ariane_axi::aw_chan_t )
      ,.axi_w_chan_t  ( ariane_axi::w_chan_t  )
      ,.b_chan_t      ( ariane_axi::b_chan_t  )
      ,.r_chan_t      ( ariane_axi::r_chan_t  )
      ,.noc_req_t     ( ariane_axi::req_t )
      ,.noc_resp_t    ( ariane_axi::resp_t )
   ) i_cva6 (
      .clk_i                ( clkwiz_o                     ),
      .rst_ni               ( rst_n                        ),
      .boot_addr_i          ( `BOOT_ADDR                   ),
      .hart_id_i            ( `HART_ID                     ),
      .irq_i                ( '0                           ),
      .ipi_i                ( ipi[0]                         ),
      .time_irq_i           ( timer_irq[0]                         ),
      .debug_req_i          ( 1'b0                         ),
      .rvfi_probes_o        (                              ),
      .cvxif_req_o          (                              ),
      .cvxif_resp_i         ( '0                           ),
      .noc_req_o            ( cva6_axi_req                 ),
      .noc_resp_i           ( cva6_axi_resp                )
   );

   localparam int unsigned NUM_SLAVES_XBAR = 1; // CVA6
   `ifdef ZC706
   localparam int unsigned NUM_MASTERS_XBAR = 5; // RAM, UART, TIMER, DRAM, CLINT
   `elsif USE_SRAM
   localparam int unsigned NUM_MASTERS_XBAR = 5;
   `elsif DDR3_AXI
   localparam int unsigned NUM_MASTERS_XBAR = 5;
   `else
   localparam int unsigned NUM_MASTERS_XBAR = 4;
   `endif
   localparam int unsigned MASTER_RAM_IDX  = 0;
   localparam int unsigned MASTER_UART_IDX = 1;
   localparam int unsigned MASTER_TIMER_IDX = 2;
   localparam int unsigned MASTER_CLINT_IDX = 3;
   `ifdef ZC706 
   localparam int unsigned MASTER_DRAM_IDX = 4;
   `elsif USE_SRAM
   localparam int unsigned MASTER_DRAM_IDX = 4;
   `elsif DDR3_AXI
   localparam int unsigned MASTER_DRAM_IDX = 4;
   `endif

   localparam axi_pkg::xbar_cfg_t XbarCfg = '{
       NoSlvPorts:         NUM_SLAVES_XBAR,
       NoMstPorts:         NUM_MASTERS_XBAR,
       MaxSlvTrans:        1,
       MaxMstTrans:        1,
       FallThrough:        1'b0,
       LatencyMode:        axi_pkg::NO_LATENCY,
       AxiIdWidthSlvPorts: cva6_config_pkg::CVA6ConfigAxiIdWidth,
       AxiIdUsedSlvPorts:  cva6_config_pkg::CVA6ConfigAxiIdWidth,
       UniqueIds:          1'b0,
       AxiAddrWidth:       cva6_config_pkg::CVA6ConfigAxiAddrWidth,
       AxiDataWidth:       cva6_config_pkg::CVA6ConfigAxiDataWidth,
       NoAddrRules:        NUM_MASTERS_XBAR
       ,default: '0
   };

   localparam int unsigned AXI_ID_WIDTH_XBAR_MST = XbarCfg.AxiIdWidthSlvPorts;

   ariane_axi::req_t  xbar_slv_port0_req;
   ariane_axi::resp_t xbar_slv_port0_resp;

   ariane_axi::req_t     [NUM_MASTERS_XBAR-1:0] xbar_mst_ports_req;
   ariane_axi::resp_t    [NUM_MASTERS_XBAR-1:0] xbar_mst_ports_resp;

   localparam axi_pkg::xbar_rule_32_t [XbarCfg.NoAddrRules-1:0] ADDR_MAP_XBAR = '{
      '{ start_addr: `MEM_BASE_ADDR,   end_addr: `MEM_BASE_ADDR  + `MEM_RANGE,   idx: MASTER_RAM_IDX  },
      '{ start_addr: `UART_BASE_ADDR,  end_addr: `UART_BASE_ADDR + `UART_RANGE,  idx: MASTER_UART_IDX },
      '{ start_addr: `TIMER_BASE_ADDR, end_addr: `TIMER_BASE_ADDR+ `TIMER_RANGE, idx: MASTER_TIMER_IDX },
      '{ start_addr: `CLINT_BASE_ADDR, end_addr: `CLINT_BASE_ADDR + `CLINT_RANGE, idx: MASTER_CLINT_IDX }
      `ifdef ZC706 
      ,'{ start_addr: `DRAM_BASE_ADDR, end_addr: `DRAM_BASE_ADDR+ `DRAM_RANGE, idx: MASTER_DRAM_IDX }
      `elsif USE_SRAM
      ,'{ start_addr: `DDR3_AXI_BASE_ADDR, end_addr: `DDR3_AXI_BASE_ADDR+ `DDR3_AXI_RANGE, idx: MASTER_DRAM_IDX }
      `elsif DDR3_AXI
      ,'{ start_addr: `DDR3_AXI_BASE_ADDR, end_addr: `DDR3_AXI_BASE_ADDR+ `DDR3_AXI_RANGE, idx: MASTER_DRAM_IDX }
      `endif
   };

   axi_xbar #(
      .Cfg          ( XbarCfg ),
      .ATOPs        ( 1'b1 ),

      .slv_aw_chan_t( ariane_axi::aw_chan_t ),
      .slv_ar_chan_t( ariane_axi::ar_chan_t ),
      .w_chan_t     ( ariane_axi::w_chan_t  ),
      .slv_b_chan_t ( ariane_axi::b_chan_t  ),
      .slv_r_chan_t ( ariane_axi::r_chan_t  ),
      .slv_req_t    ( ariane_axi::req_t     ),
      .slv_resp_t   ( ariane_axi::resp_t    ),

      .mst_aw_chan_t( ariane_axi::aw_chan_t ),
      .mst_ar_chan_t( ariane_axi::ar_chan_t ),
      .mst_b_chan_t ( ariane_axi::b_chan_t  ),
      .mst_r_chan_t ( ariane_axi::r_chan_t  ),
      .mst_req_t    ( ariane_axi::req_t     ),
      .mst_resp_t   ( ariane_axi::resp_t    ),

      .rule_t       ( axi_pkg::xbar_rule_32_t   )
   ) i_axi_xbar (
      .clk_i        ( clkwiz_o                      ),
      .rst_ni       ( rst_n                         ),
      .test_i       ( 1'b0                          ),

      .slv_ports_req_i  ( {xbar_slv_port0_req}      ),
      .slv_ports_resp_o ( {xbar_slv_port0_resp}     ),

      .mst_ports_req_o  ( xbar_mst_ports_req        ),
      .mst_ports_resp_i ( xbar_mst_ports_resp       ),

      .addr_map_i       ( ADDR_MAP_XBAR             ),
      .en_default_mst_port_i( {NUM_SLAVES_XBAR{1'b0}} ),
      .default_mst_port_i ( '0                      )
   );

   assign xbar_slv_port0_req = cva6_axi_req;
   assign cva6_axi_resp      = xbar_slv_port0_resp;
 
   `REG_BUS_TYPEDEF_ALL(reg, logic[XbarCfg.AxiAddrWidth-1:0], logic[XbarCfg.AxiDataWidth-1:0], logic[XbarCfg.AxiDataWidth/8-1:0])
 
   reg_req_t clint_reg_req;
   reg_rsp_t clint_reg_rsp;
 
   axi_to_reg_v2 #(
     .AxiAddrWidth(XbarCfg.AxiAddrWidth),
     .AxiDataWidth(XbarCfg.AxiDataWidth),
     .AxiIdWidth(AXI_ID_WIDTH_XBAR_MST),
     .RegDataWidth(XbarCfg.AxiDataWidth),
     .axi_req_t(ariane_axi::req_t),
     .axi_rsp_t(ariane_axi::resp_t),
     .reg_req_t(reg_req_t),
     .reg_rsp_t(reg_rsp_t)
   ) i_axi_to_reg_v2 (
     .clk_i(clkwiz_o),
     .rst_ni(rst_n),
     .axi_req_i(xbar_mst_ports_req[MASTER_CLINT_IDX]),
     .axi_rsp_o(xbar_mst_ports_resp[MASTER_CLINT_IDX]),
     .reg_req_o(clint_reg_req),
     .reg_rsp_i(clint_reg_rsp)
   );

   reg [5:0] count;
   reg clk_rtc;
   always @(posedge clkwiz_o or negedge rst_n) begin
       if (!rst_n) begin
           count   <= 0;
           clk_rtc <= 0;
       end
       else begin
           if (count == 50/2 - 1) begin // 50 MHz to 1MHz
               clk_rtc <= ~clk_rtc;
               count   <= 0;
           end
           else begin
               count <= count + 1;
           end
       end
   end

   clint #(
     .reg_req_t(reg_req_t),
     .reg_rsp_t(reg_rsp_t)
   ) i_clint (
     .clk_i(clkwiz_o),
     .rst_ni(rst_n),
     .testmode_i(1'b0),
     .reg_req_i(clint_reg_req),
     .reg_rsp_o(clint_reg_rsp),
     .rtc_i(clk_rtc),
     .timer_irq_o(timer_irq),
     .ipi_o(ipi)
   );
 
   import obi_pkg::*;
   localparam obi_pkg::obi_cfg_t AdapterObiCfg = '{
       AddrWidth: XbarCfg.AxiAddrWidth,
       DataWidth: `MEM_W,
       IdWidth:   AXI_ID_WIDTH_XBAR_MST,
       UseRReady: 1'b0,
       CombGnt:   1'b0,
       Integrity: 1'b0,
       BeFull:    1'b1,
       OptionalCfg: '{ UseAtop: 1'b1, UseProt: 1'b0, UseMemtype: 1'b0, UseDbg: 1'b0,
                      AUserWidth: 0, WUserWidth: 0, RUserWidth: 1,
                      MidWidth: 0, AChkWidth: 0, RChkWidth: 0 }
   };

   `OBI_TYPEDEF_ATOP_A_OPTIONAL(adapter_obi_a_optional_t)
   `OBI_TYPEDEF_ALL_R_OPTIONAL(adapter_obi_r_optional_t, AdapterObiCfg.OptionalCfg.RUserWidth, AdapterObiCfg.OptionalCfg.RChkWidth)

   `OBI_TYPEDEF_A_CHAN_T(adapter_obi_a_chan_t, AdapterObiCfg.AddrWidth, AdapterObiCfg.DataWidth, AdapterObiCfg.IdWidth, adapter_obi_a_optional_t)
   `OBI_TYPEDEF_R_CHAN_T(adapter_obi_r_chan_t, AdapterObiCfg.DataWidth, AdapterObiCfg.IdWidth, adapter_obi_r_optional_t)

   `OBI_TYPEDEF_DEFAULT_REQ_T(adapter_obi_req_t, adapter_obi_a_chan_t)
   `OBI_TYPEDEF_RSP_T(adapter_obi_rsp_t, adapter_obi_r_chan_t)

   localparam int unsigned AXI_MAX_TRANS = XbarCfg.MaxMstTrans;

   adapter_obi_req_t mem_obi_req;
   adapter_obi_rsp_t mem_obi_rsp;

   axi_to_obi #(
      .ObiCfg         ( AdapterObiCfg          ),
      .obi_req_t      ( adapter_obi_req_t      ), .obi_rsp_t      ( adapter_obi_rsp_t      ),
      .obi_a_chan_t   ( adapter_obi_a_chan_t   ), .obi_r_chan_t   ( adapter_obi_r_chan_t   ),
      .AxiAddrWidth   ( XbarCfg.AxiAddrWidth   ),
      .AxiDataWidth   ( XbarCfg.AxiDataWidth   ),
      .AxiIdWidth     ( AXI_ID_WIDTH_XBAR_MST  ),
      .AxiUserWidth   ( cva6_config_pkg::CVA6ConfigDataUserWidth),
      .MaxTrans       ( AXI_MAX_TRANS          ),
      .axi_req_t      ( ariane_axi::req_t         ),
      .axi_rsp_t      ( ariane_axi::resp_t        )
   ) i_axi_to_obi_mem (
      .clk_i        ( clkwiz_o                              ),
      .rst_ni       ( rst_n                                 ),
      .testmode_i   ( 1'b0                                  ),

      .axi_req_i    ( xbar_mst_ports_req[MASTER_RAM_IDX]    ),
      .axi_rsp_o    ( xbar_mst_ports_resp[MASTER_RAM_IDX]   ),

      .obi_req_o    ( mem_obi_req                           ),
      .obi_rsp_i    ( mem_obi_rsp                           ),

      .req_aw_id_o (), .req_aw_user_o (), .req_w_user_o (),
      .req_write_aid_i ('0),.req_write_auser_i ('0),.req_write_wuser_i ('0),
      .req_ar_id_o (), .req_ar_user_o (),
      .req_read_aid_i ('0),.req_read_auser_i ('0),
      .rsp_write_aw_user_o (), .rsp_write_w_user_o (), .rsp_write_bank_strb_o (),
      .rsp_write_rid_o (), .rsp_write_ruser_o (), .rsp_write_last_o (),
      .rsp_write_hs_o (), .rsp_b_user_i ('0),
      .rsp_read_ar_user_o (), .rsp_read_size_enable_o (), .rsp_read_rid_o (),
      .rsp_read_ruser_o (), .rsp_r_user_i ('0)
   );

   logic        ram_req_i;
   logic        ram_we_i;
   logic [AdapterObiCfg.DataWidth/8-1:0] ram_be_i;
   logic [AdapterObiCfg.AddrWidth-1:0] ram_addr_i;
   logic [AdapterObiCfg.DataWidth-1:0] ram_wdata_i;
   logic        ram_rvalid_o;
   logic [AdapterObiCfg.DataWidth-1:0] ram_rdata_o;

   assign ram_req_i   = mem_obi_req.req;
   assign ram_we_i    = mem_obi_req.a.we;
   assign ram_addr_i  = mem_obi_req.a.addr[31:0];
   assign ram_wdata_i = mem_obi_req.a.wdata;
   assign ram_be_i    = mem_obi_req.a.be;

   assign mem_obi_rsp.gnt    = 1;
   assign mem_obi_rsp.rvalid = ram_rvalid_o;
   assign mem_obi_rsp.r.rdata = ram_rdata_o;
   assign mem_obi_rsp.r.rid   = mem_obi_req.a.aid;
   assign mem_obi_rsp.r.err  = 1'b0;

   // TODO: Handle atomics with wrapper

   logic uart_dram_write_we;
   logic [31:0] uart_dram_write_addr;
   logic [31:0] uart_dram_write_data;

   ram32_dwr #(
      .SIZE     (`RAM_SIZE / 4),
      .INIT_FILE(`RAM_FPATH)
   ) main_memory (
      .clk_i   (clkwiz_o),
      .rst_ni  (rst_ni `ifdef BASYS3 & clkwiz_locked `endif), // pll_locked
      .req_i   ( ram_req_i      ),
      .we_i    ( ram_we_i       ),
      .be_i    ( ram_be_i       ),
      .addr_i  ( ram_addr_i     ),
      .wdata_i ( ram_wdata_i    ),
      .rvalid_o( ram_rvalid_o   ),
      .rdata_o ( ram_rdata_o    )

      ,.program_rx_i   ( program_rx_i   )
      ,.system_reset_o ( system_reset_o )
      ,.prog_mode_led_o( prog_mode_led_o)

      ,.dram_write_we_o(uart_dram_write_we)
      ,.dram_write_addr_o(uart_dram_write_addr)
      ,.dram_write_data_o(uart_dram_write_data)
      ,.dram_write_rst_o(uart_dram_write_rst)
      ,.dram_mode_o    ( uart_dram_mode )
   );

   logic                            uart_axi_awvalid;
   logic                            uart_axi_awready;
   logic [XbarCfg.AxiAddrWidth-1:0] uart_axi_awaddr;
   logic [AXI_ID_WIDTH_XBAR_MST-1:0]uart_axi_awid;
   logic [2:0]                      uart_axi_awprot;
   logic                            uart_axi_wvalid;
   logic                            uart_axi_wready;
   logic [XbarCfg.AxiDataWidth-1:0] uart_axi_wdata;
   logic [XbarCfg.AxiDataWidth/8-1:0] uart_axi_wstrb;
   logic                            uart_axi_bvalid;
   logic                            uart_axi_bready;
   logic [AXI_ID_WIDTH_XBAR_MST-1:0]uart_axi_bid;
   logic [1:0]                      uart_axi_bresp;
   logic                            uart_axi_arvalid;
   logic                            uart_axi_arready;
   logic [XbarCfg.AxiAddrWidth-1:0] uart_axi_araddr;
   logic [AXI_ID_WIDTH_XBAR_MST-1:0]uart_axi_arid;
   logic [2:0]                      uart_axi_arprot;
   logic                            uart_axi_rvalid;
   logic                            uart_axi_rready;
   logic [AXI_ID_WIDTH_XBAR_MST-1:0]uart_axi_rid;
   logic [XbarCfg.AxiDataWidth-1:0] uart_axi_rdata;
   logic [1:0]                      uart_axi_rresp;

   assign uart_axi_awvalid = xbar_mst_ports_req[MASTER_UART_IDX].aw_valid;
   assign uart_axi_awaddr  = xbar_mst_ports_req[MASTER_UART_IDX].aw.addr;
   assign uart_axi_awid    = xbar_mst_ports_req[MASTER_UART_IDX].aw.id;
   assign uart_axi_awprot  = xbar_mst_ports_req[MASTER_UART_IDX].aw.prot;

   assign uart_axi_wvalid  = xbar_mst_ports_req[MASTER_UART_IDX].w_valid;
   assign uart_axi_wdata   = xbar_mst_ports_req[MASTER_UART_IDX].w.data;
   assign uart_axi_wstrb   = xbar_mst_ports_req[MASTER_UART_IDX].w.strb;

   assign uart_axi_arvalid = xbar_mst_ports_req[MASTER_UART_IDX].ar_valid;
   assign uart_axi_araddr  = xbar_mst_ports_req[MASTER_UART_IDX].ar.addr;
   assign uart_axi_arid    = xbar_mst_ports_req[MASTER_UART_IDX].ar.id;
   assign uart_axi_arprot  = xbar_mst_ports_req[MASTER_UART_IDX].ar.prot;

   assign uart_axi_bready  = xbar_mst_ports_req[MASTER_UART_IDX].b_ready;
   assign uart_axi_rready  = xbar_mst_ports_req[MASTER_UART_IDX].r_ready;


   assign xbar_mst_ports_resp[MASTER_UART_IDX].aw_ready = uart_axi_awready;
   assign xbar_mst_ports_resp[MASTER_UART_IDX].w_ready  = uart_axi_wready;
   assign xbar_mst_ports_resp[MASTER_UART_IDX].ar_ready = uart_axi_arready;
   assign xbar_mst_ports_resp[MASTER_UART_IDX].b_valid  = uart_axi_bvalid;
   assign xbar_mst_ports_resp[MASTER_UART_IDX].b.id     = uart_axi_bid;
   assign xbar_mst_ports_resp[MASTER_UART_IDX].b.resp   = uart_axi_bresp;
   assign xbar_mst_ports_resp[MASTER_UART_IDX].r_valid  = uart_axi_rvalid;
   assign xbar_mst_ports_resp[MASTER_UART_IDX].r.id     = uart_axi_rid;
   assign xbar_mst_ports_resp[MASTER_UART_IDX].r.data   = uart_axi_rdata;
   assign xbar_mst_ports_resp[MASTER_UART_IDX].r.resp   = uart_axi_rresp;
   assign xbar_mst_ports_resp[MASTER_UART_IDX].r.last   = 1'b1; // AXI-Lite

   uart_controller_axi #(
       .AXI_ID_WIDTH  (AXI_ID_WIDTH_XBAR_MST),
       .AXI_ADDR_WIDTH(XbarCfg.AxiAddrWidth),
       .AXI_DATA_WIDTH(XbarCfg.AxiDataWidth)
   ) uart_dut (
       .clk_i   ( clkwiz_o      ), .rst_ni  ( rst_n         ),
       .s_axi_awvalid(uart_axi_awvalid), .s_axi_awready(uart_axi_awready),
       .s_axi_awaddr (uart_axi_awaddr),  .s_axi_awid   (uart_axi_awid),
       .s_axi_awprot (uart_axi_awprot),
       .s_axi_wvalid (uart_axi_wvalid),  .s_axi_wready (uart_axi_wready),
       .s_axi_wdata  (uart_axi_wdata),   .s_axi_wstrb  (uart_axi_wstrb),
       .s_axi_bvalid (uart_axi_bvalid),  .s_axi_bready (uart_axi_bready),
       .s_axi_bid    (uart_axi_bid),     .s_axi_bresp  (uart_axi_bresp),
       .s_axi_arvalid(uart_axi_arvalid), .s_axi_arready(uart_axi_arready),
       .s_axi_araddr (uart_axi_araddr),  .s_axi_arid   (uart_axi_arid),
       .s_axi_arprot (uart_axi_arprot),
       .s_axi_rvalid (uart_axi_rvalid),  .s_axi_rready (uart_axi_rready),
       .s_axi_rid    (uart_axi_rid),     .s_axi_rdata  (uart_axi_rdata),
       .s_axi_rresp  (uart_axi_rresp),
       .rx_i    ( uart_rx_i     ), .tx_o    ( uart_tx_o     )
   );

   logic                            timer_axi_awvalid;
   logic                            timer_axi_awready;
   logic [XbarCfg.AxiAddrWidth-1:0] timer_axi_awaddr;
   logic [AXI_ID_WIDTH_XBAR_MST-1:0]timer_axi_awid;
   logic [2:0]                      timer_axi_awprot;
   logic                            timer_axi_wvalid;
   logic                            timer_axi_wready;
   logic [XbarCfg.AxiDataWidth-1:0] timer_axi_wdata;
   logic [XbarCfg.AxiDataWidth/8-1:0] timer_axi_wstrb;
   logic                            timer_axi_bvalid;
   logic                            timer_axi_bready;
   logic [AXI_ID_WIDTH_XBAR_MST-1:0]timer_axi_bid;
   logic [1:0]                      timer_axi_bresp;
   logic                            timer_axi_arvalid;
   logic                            timer_axi_arready;
   logic [XbarCfg.AxiAddrWidth-1:0] timer_axi_araddr;
   logic [AXI_ID_WIDTH_XBAR_MST-1:0]timer_axi_arid;
   logic [2:0]                      timer_axi_arprot;
   logic                            timer_axi_rvalid;
   logic                            timer_axi_rready;
   logic [AXI_ID_WIDTH_XBAR_MST-1:0]timer_axi_rid;
   logic [XbarCfg.AxiDataWidth-1:0] timer_axi_rdata;
   logic [1:0]                      timer_axi_rresp;

   assign timer_axi_awvalid = xbar_mst_ports_req[MASTER_TIMER_IDX].aw_valid;
   assign timer_axi_awaddr  = xbar_mst_ports_req[MASTER_TIMER_IDX].aw.addr;
   assign timer_axi_awid    = xbar_mst_ports_req[MASTER_TIMER_IDX].aw.id;
   assign timer_axi_awprot  = xbar_mst_ports_req[MASTER_TIMER_IDX].aw.prot;
   assign timer_axi_wvalid  = xbar_mst_ports_req[MASTER_TIMER_IDX].w_valid;
   assign timer_axi_wdata   = xbar_mst_ports_req[MASTER_TIMER_IDX].w.data;
   assign timer_axi_wstrb   = xbar_mst_ports_req[MASTER_TIMER_IDX].w.strb;
   assign timer_axi_arvalid = xbar_mst_ports_req[MASTER_TIMER_IDX].ar_valid;
   assign timer_axi_araddr  = xbar_mst_ports_req[MASTER_TIMER_IDX].ar.addr;
   assign timer_axi_arid    = xbar_mst_ports_req[MASTER_TIMER_IDX].ar.id;
   assign timer_axi_arprot  = xbar_mst_ports_req[MASTER_TIMER_IDX].ar.prot;
   assign timer_axi_bready  = xbar_mst_ports_req[MASTER_TIMER_IDX].b_ready;
   assign timer_axi_rready  = xbar_mst_ports_req[MASTER_TIMER_IDX].r_ready;

   assign xbar_mst_ports_resp[MASTER_TIMER_IDX].aw_ready = timer_axi_awready;
   assign xbar_mst_ports_resp[MASTER_TIMER_IDX].w_ready  = timer_axi_wready;
   assign xbar_mst_ports_resp[MASTER_TIMER_IDX].ar_ready = timer_axi_arready;
   assign xbar_mst_ports_resp[MASTER_TIMER_IDX].b_valid  = timer_axi_bvalid;
   assign xbar_mst_ports_resp[MASTER_TIMER_IDX].b.id     = timer_axi_bid;
   assign xbar_mst_ports_resp[MASTER_TIMER_IDX].b.resp   = timer_axi_bresp;
   assign xbar_mst_ports_resp[MASTER_TIMER_IDX].r_valid  = timer_axi_rvalid;
   assign xbar_mst_ports_resp[MASTER_TIMER_IDX].r.id     = timer_axi_rid;
   assign xbar_mst_ports_resp[MASTER_TIMER_IDX].r.data   = timer_axi_rdata;
   assign xbar_mst_ports_resp[MASTER_TIMER_IDX].r.resp   = timer_axi_rresp;
   assign xbar_mst_ports_resp[MASTER_TIMER_IDX].r.last   = 1'b1;

   timer_controller_axi #(
       .AXI_ID_WIDTH  (AXI_ID_WIDTH_XBAR_MST),
       .AXI_ADDR_WIDTH(XbarCfg.AxiAddrWidth),
       .AXI_DATA_WIDTH(XbarCfg.AxiDataWidth)
   ) timer_dut (
       .clk_i   ( clkwiz_o      ),
       .rst_ni  ( rst_n         ),
       .s_axi_awvalid(timer_axi_awvalid),
       .s_axi_awready(timer_axi_awready),
       .s_axi_awaddr (timer_axi_awaddr),
       .s_axi_awid   (timer_axi_awid),
       .s_axi_awprot (timer_axi_awprot),
       .s_axi_wvalid (timer_axi_wvalid),
       .s_axi_wready (timer_axi_wready),
       .s_axi_wdata  (timer_axi_wdata),
       .s_axi_wstrb  (timer_axi_wstrb),
       .s_axi_bvalid (timer_axi_bvalid),
       .s_axi_bready (timer_axi_bready),
       .s_axi_bid    (timer_axi_bid),
       .s_axi_bresp  (timer_axi_bresp),
       .s_axi_arvalid(timer_axi_arvalid),
       .s_axi_arready(timer_axi_arready),
       .s_axi_araddr (timer_axi_araddr),
       .s_axi_arid   (timer_axi_arid),
       .s_axi_arprot (timer_axi_arprot),
       .s_axi_rvalid (timer_axi_rvalid),
       .s_axi_rready (timer_axi_rready),
       .s_axi_rid    (timer_axi_rid),
       .s_axi_rdata  (timer_axi_rdata),
       .s_axi_rresp  (timer_axi_rresp)
   );

   `ifdef DRAM_SIM
   wire ddr3_reset_n;
   wire ddr3_cke;
   wire ddr3_ck_p;
   wire ddr3_ck_n;
   wire ddr3_cs_n;
   wire ddr3_ras_n;
   wire ddr3_cas_n;
   wire ddr3_we_n;
   wire [2:0] ddr3_ba;
   wire [13:0] ddr3_addr;
   wire ddr3_odt;
   wire [1:0] ddr3_dm;
   wire [1:0] ddr3_dqs_p;
   wire [1:0] ddr3_dqs_n;
   wire [15:0] ddr3_dq;

   //`define den1024Mb
   //`include "1024Mb_ddr3_parameters.vh"

   ddr3 ddr3_dut (
      .rst_n  (ddr3_reset_n),
      .ck     (ddr3_ck_p),
      .ck_n   (ddr3_ck_n),
      .cke    (ddr3_cke),
      .cs_n   (ddr3_cs_n),
      .ras_n  (ddr3_ras_n),
      .cas_n  (ddr3_cas_n),
      .we_n   (ddr3_we_n),
      .dm_tdqs(ddr3_dm),
      .ba     (ddr3_ba),
      .addr   (ddr3_addr),
      .dq     (ddr3_dq),
      .dqs    (ddr3_dqs_p),
      .dqs_n  (ddr3_dqs_n),
      .tdqs_n (),
      .odt    (ddr3_odt)
   );
   `endif

   `ifdef ZC706
   logic                            dram_axi_awvalid;
   logic                            dram_axi_awready;
   logic [XbarCfg.AxiAddrWidth-1:0] dram_axi_awaddr;
   logic [AXI_ID_WIDTH_XBAR_MST-1:0]dram_axi_awid;
   logic [7:0]                      dram_axi_awlen;
   logic [2:0]                      dram_axi_awsize;
   logic [1:0]                      dram_axi_awburst;
   logic [2:0]                      dram_axi_awprot;
   logic [5:0]                      dram_axi_awatop;
   logic                            dram_axi_awlock;
   logic                            dram_axi_wvalid;
   logic                            dram_axi_wready;
   logic [XbarCfg.AxiDataWidth-1:0] dram_axi_wdata;
   logic [XbarCfg.AxiDataWidth/8-1:0] dram_axi_wstrb;
   logic                            dram_axi_wlast;
   logic                            dram_axi_bvalid;
   logic                            dram_axi_bready;
   logic [AXI_ID_WIDTH_XBAR_MST-1:0]dram_axi_bid;
   logic [1:0]                      dram_axi_bresp;
   logic                            dram_axi_arvalid;
   logic                            dram_axi_arready;
   logic [XbarCfg.AxiAddrWidth-1:0] dram_axi_araddr;
   logic [AXI_ID_WIDTH_XBAR_MST-1:0]dram_axi_arid;
   logic [7:0]                      dram_axi_arlen;
   logic [2:0]                      dram_axi_arsize;
   logic [1:0]                      dram_axi_arburst;
   logic [2:0]                      dram_axi_arprot;
   logic                            dram_axi_arlock;
   logic                            dram_axi_rvalid;
   logic                            dram_axi_rready;
   logic [AXI_ID_WIDTH_XBAR_MST-1:0]dram_axi_rid;
   logic [XbarCfg.AxiDataWidth-1:0] dram_axi_rdata;
   logic [1:0]                      dram_axi_rresp;
   logic                            dram_axi_rlast;

   logic                            atomics_mst_awvalid;
   logic                            atomics_mst_awready;
   logic [XbarCfg.AxiAddrWidth-1:0] atomics_mst_awaddr;
   logic [AXI_ID_WIDTH_XBAR_MST-1:0]atomics_mst_awid;
   logic [7:0]                      atomics_mst_awlen;
   logic [2:0]                      atomics_mst_awsize;
   logic [1:0]                      atomics_mst_awburst;
   logic [2:0]                      atomics_mst_awprot;
   logic [5:0]                      atomics_mst_awatop;
   logic                            atomics_mst_awlock;
   logic [3:0]                      atomics_mst_awcache;
   logic [3:0]                      atomics_mst_awqos;
   logic [3:0]                      atomics_mst_awregion;
   logic [0:0]                      atomics_mst_awuser;
   logic                            atomics_mst_wvalid;
   logic                            atomics_mst_wready;
   logic [XbarCfg.AxiDataWidth-1:0] atomics_mst_wdata;
   logic [XbarCfg.AxiDataWidth/8-1:0] atomics_mst_wstrb;
   logic                            atomics_mst_wlast;
   logic [0:0]                      atomics_mst_wuser;
   logic                            atomics_mst_bvalid;
   logic                            atomics_mst_bready;
   logic [AXI_ID_WIDTH_XBAR_MST-1:0]atomics_mst_bid;
   logic [1:0]                      atomics_mst_bresp;
   logic [0:0]                      atomics_mst_buser;
   logic                            atomics_mst_arvalid;
   logic                            atomics_mst_arready;
   logic [XbarCfg.AxiAddrWidth-1:0] atomics_mst_araddr;
   logic [AXI_ID_WIDTH_XBAR_MST-1:0]atomics_mst_arid;
   logic [7:0]                      atomics_mst_arlen;
   logic [2:0]                      atomics_mst_arsize;
   logic [1:0]                      atomics_mst_arburst;
   logic [2:0]                      atomics_mst_arprot;
   logic                            atomics_mst_arlock;
   logic [3:0]                      atomics_mst_arcache;
   logic [3:0]                      atomics_mst_arqos;
   logic [3:0]                      atomics_mst_arregion;
   logic [0:0]                      atomics_mst_aruser;
   logic                            atomics_mst_rvalid;
   logic                            atomics_mst_rready;
   logic [AXI_ID_WIDTH_XBAR_MST-1:0]atomics_mst_rid;
   logic [XbarCfg.AxiDataWidth-1:0] atomics_mst_rdata;
   logic [1:0]                      atomics_mst_rresp;
   logic                            atomics_mst_rlast;
   logic [0:0]                      atomics_mst_ruser;

   logic                            encrypted_axi_awvalid;
   logic                            encrypted_axi_awready;
   logic [XbarCfg.AxiAddrWidth-1:0] encrypted_axi_awaddr;
   logic [AXI_ID_WIDTH_XBAR_MST-1:0]encrypted_axi_awid;
   logic [7:0]                      encrypted_axi_awlen;
   logic [2:0]                      encrypted_axi_awsize;
   logic [1:0]                      encrypted_axi_awburst;
   logic [2:0]                      encrypted_axi_awprot;
   logic                            encrypted_axi_wvalid;
   logic                            encrypted_axi_wready;
   logic [XbarCfg.AxiDataWidth-1:0] encrypted_axi_wdata;
   logic [XbarCfg.AxiDataWidth/8-1:0] encrypted_axi_wstrb;
   logic                            encrypted_axi_wlast;
   logic                            encrypted_axi_bvalid;
   logic                            encrypted_axi_bready;
   logic [AXI_ID_WIDTH_XBAR_MST-1:0]encrypted_axi_bid;
   logic [1:0]                      encrypted_axi_bresp;
   logic                            encrypted_axi_arvalid;
   logic                            encrypted_axi_arready;
   logic [XbarCfg.AxiAddrWidth-1:0] encrypted_axi_araddr;
   logic [AXI_ID_WIDTH_XBAR_MST-1:0]encrypted_axi_arid;
   logic [7:0]                      encrypted_axi_arlen;
   logic [2:0]                      encrypted_axi_arsize;
   logic [1:0]                      encrypted_axi_arburst;
   logic [2:0]                      encrypted_axi_arprot;
   logic                            encrypted_axi_rvalid;
   logic                            encrypted_axi_rready;
   logic [AXI_ID_WIDTH_XBAR_MST-1:0]encrypted_axi_rid;
   logic [XbarCfg.AxiDataWidth-1:0] encrypted_axi_rdata;
   logic [1:0]                      encrypted_axi_rresp;
   logic                            encrypted_axi_rlast;

   assign dram_axi_awvalid = xbar_mst_ports_req[MASTER_DRAM_IDX].aw_valid;
   assign dram_axi_awaddr  = xbar_mst_ports_req[MASTER_DRAM_IDX].aw.addr;
   assign dram_axi_awid    = xbar_mst_ports_req[MASTER_DRAM_IDX].aw.id;
   assign dram_axi_awlen   = xbar_mst_ports_req[MASTER_DRAM_IDX].aw.len;
   assign dram_axi_awsize  = xbar_mst_ports_req[MASTER_DRAM_IDX].aw.size;
   assign dram_axi_awburst = xbar_mst_ports_req[MASTER_DRAM_IDX].aw.burst;
   assign dram_axi_awprot  = xbar_mst_ports_req[MASTER_DRAM_IDX].aw.prot;
   assign dram_axi_awatop  = xbar_mst_ports_req[MASTER_DRAM_IDX].aw.atop;
   assign dram_axi_awlock  = xbar_mst_ports_req[MASTER_DRAM_IDX].aw.lock;
   assign dram_axi_wvalid  = xbar_mst_ports_req[MASTER_DRAM_IDX].w_valid;
   assign dram_axi_wdata   = xbar_mst_ports_req[MASTER_DRAM_IDX].w.data;
   assign dram_axi_wstrb   = xbar_mst_ports_req[MASTER_DRAM_IDX].w.strb;
   assign dram_axi_wlast   = xbar_mst_ports_req[MASTER_DRAM_IDX].w.last;
   assign dram_axi_arvalid = xbar_mst_ports_req[MASTER_DRAM_IDX].ar_valid;
   assign dram_axi_araddr  = xbar_mst_ports_req[MASTER_DRAM_IDX].ar.addr;
   assign dram_axi_arid    = xbar_mst_ports_req[MASTER_DRAM_IDX].ar.id;
   assign dram_axi_arlen   = xbar_mst_ports_req[MASTER_DRAM_IDX].ar.len;
   assign dram_axi_arsize  = xbar_mst_ports_req[MASTER_DRAM_IDX].ar.size;
   assign dram_axi_arburst = xbar_mst_ports_req[MASTER_DRAM_IDX].ar.burst;
   assign dram_axi_arprot  = xbar_mst_ports_req[MASTER_DRAM_IDX].ar.prot;
   assign dram_axi_arlock  = xbar_mst_ports_req[MASTER_DRAM_IDX].ar.lock;
   assign dram_axi_bready  = xbar_mst_ports_req[MASTER_DRAM_IDX].b_ready;
   assign dram_axi_rready  = xbar_mst_ports_req[MASTER_DRAM_IDX].r_ready;

   assign xbar_mst_ports_resp[MASTER_DRAM_IDX].aw_ready = dram_axi_awready;
   assign xbar_mst_ports_resp[MASTER_DRAM_IDX].w_ready  = dram_axi_wready;
   assign xbar_mst_ports_resp[MASTER_DRAM_IDX].ar_ready = dram_axi_arready;
   assign xbar_mst_ports_resp[MASTER_DRAM_IDX].b_valid  = dram_axi_bvalid;
   assign xbar_mst_ports_resp[MASTER_DRAM_IDX].b.id     = dram_axi_bid;
   assign xbar_mst_ports_resp[MASTER_DRAM_IDX].b.resp   = dram_axi_bresp;
   assign xbar_mst_ports_resp[MASTER_DRAM_IDX].r_valid  = dram_axi_rvalid;
   assign xbar_mst_ports_resp[MASTER_DRAM_IDX].r.id     = dram_axi_rid;
   assign xbar_mst_ports_resp[MASTER_DRAM_IDX].r.data   = dram_axi_rdata;
   assign xbar_mst_ports_resp[MASTER_DRAM_IDX].r.resp   = dram_axi_rresp;
   assign xbar_mst_ports_resp[MASTER_DRAM_IDX].r.last   = dram_axi_rlast;

   axi_riscv_atomics #(
       .AXI_ADDR_WIDTH     (XbarCfg.AxiAddrWidth),
       .AXI_DATA_WIDTH     (XbarCfg.AxiDataWidth),
       .AXI_ID_WIDTH       (AXI_ID_WIDTH_XBAR_MST),
       .AXI_USER_WIDTH     (1),
       .AXI_MAX_WRITE_TXNS (1),
       .RISCV_WORD_WIDTH   (32)
   ) i_axi_atomics (
       .clk_i             (clkwiz_o),
       .rst_ni            ((rst_ni & system_reset_o & pll_locked) || uart_dram_mode),
       .slv_aw_addr_i     (dram_axi_awaddr),
       .slv_aw_prot_i     (dram_axi_awprot),
       .slv_aw_region_i   ('0),
       .slv_aw_atop_i     ({2'b0, dram_axi_awatop}),
       .slv_aw_len_i      (dram_axi_awlen),
       .slv_aw_size_i     (dram_axi_awsize),
       .slv_aw_burst_i    (dram_axi_awburst),
       .slv_aw_lock_i     (dram_axi_awlock),
       .slv_aw_cache_i    ('0),
       .slv_aw_qos_i      ('0),
       .slv_aw_id_i       (dram_axi_awid),
       .slv_aw_user_i     ('0),
       .slv_aw_ready_o    (dram_axi_awready),
       .slv_aw_valid_i    (dram_axi_awvalid),
       .slv_ar_addr_i     (dram_axi_araddr),
       .slv_ar_prot_i     (dram_axi_arprot),
       .slv_ar_region_i   ('0),
       .slv_ar_len_i      (dram_axi_arlen),
       .slv_ar_size_i     (dram_axi_arsize),
       .slv_ar_burst_i    (dram_axi_arburst),
       .slv_ar_lock_i     (dram_axi_arlock),
       .slv_ar_cache_i    ('0),
       .slv_ar_qos_i      ('0),
       .slv_ar_id_i       (dram_axi_arid),
       .slv_ar_user_i     ('0),
       .slv_ar_ready_o    (dram_axi_arready),
       .slv_ar_valid_i    (dram_axi_arvalid),
       .slv_w_data_i      (dram_axi_wdata),
       .slv_w_strb_i      (dram_axi_wstrb),
       .slv_w_user_i      ('0),
       .slv_w_last_i      (dram_axi_wlast),
       .slv_w_ready_o     (dram_axi_wready),
       .slv_w_valid_i     (dram_axi_wvalid),
       .slv_r_data_o      (dram_axi_rdata),
       .slv_r_resp_o      (dram_axi_rresp),
       .slv_r_last_o      (dram_axi_rlast),
       .slv_r_id_o        (dram_axi_rid),
       .slv_r_user_o      (),
       .slv_r_ready_i     (dram_axi_rready),
       .slv_r_valid_o     (dram_axi_rvalid),
       .slv_b_resp_o      (dram_axi_bresp),
       .slv_b_id_o        (dram_axi_bid),
       .slv_b_user_o      (),
       .slv_b_ready_i     (dram_axi_bready),
       .slv_b_valid_o     (dram_axi_bvalid),
       .mst_aw_addr_o     (atomics_mst_awaddr),
       .mst_aw_prot_o     (atomics_mst_awprot),
       .mst_aw_region_o   (atomics_mst_awregion),
       .mst_aw_atop_o     (atomics_mst_awatop),
       .mst_aw_len_o      (atomics_mst_awlen),
       .mst_aw_size_o     (atomics_mst_awsize),
       .mst_aw_burst_o    (atomics_mst_awburst),
       .mst_aw_lock_o     (atomics_mst_awlock),
       .mst_aw_cache_o    (atomics_mst_awcache),
       .mst_aw_qos_o      (atomics_mst_awqos),
       .mst_aw_id_o       (atomics_mst_awid),
       .mst_aw_user_o     (atomics_mst_awuser),
       .mst_aw_ready_i    (atomics_mst_awready),
       .mst_aw_valid_o    (atomics_mst_awvalid),
       .mst_ar_addr_o     (atomics_mst_araddr),
       .mst_ar_prot_o     (atomics_mst_arprot),
       .mst_ar_region_o   (atomics_mst_arregion),
       .mst_ar_len_o      (atomics_mst_arlen),
       .mst_ar_size_o     (atomics_mst_arsize),
       .mst_ar_burst_o    (atomics_mst_arburst),
       .mst_ar_lock_o     (atomics_mst_arlock),
       .mst_ar_cache_o    (atomics_mst_arcache),
       .mst_ar_qos_o      (atomics_mst_arqos),
       .mst_ar_id_o       (atomics_mst_arid),
       .mst_ar_user_o     (atomics_mst_aruser),
       .mst_ar_ready_i    (atomics_mst_arready),
       .mst_ar_valid_o    (atomics_mst_arvalid),
       .mst_w_data_o      (atomics_mst_wdata),
       .mst_w_strb_o      (atomics_mst_wstrb),
       .mst_w_user_o      (atomics_mst_wuser),
       .mst_w_last_o      (atomics_mst_wlast),
       .mst_w_ready_i     (atomics_mst_wready),
       .mst_w_valid_o     (atomics_mst_wvalid),
       .mst_r_data_i      (atomics_mst_rdata),
       .mst_r_resp_i      (atomics_mst_rresp),
       .mst_r_last_i      (atomics_mst_rlast),
       .mst_r_id_i        (atomics_mst_rid),
       .mst_r_user_i      (atomics_mst_ruser),
       .mst_r_ready_o     (atomics_mst_rready),
       .mst_r_valid_i     (atomics_mst_rvalid),
       .mst_b_resp_i      (atomics_mst_bresp),
       .mst_b_id_i        (atomics_mst_bid),
       .mst_b_user_i      (atomics_mst_buser),
       .mst_b_ready_o     (atomics_mst_bready),
       .mst_b_valid_i     (atomics_mst_bvalid)
   );

   logic [XbarCfg.AxiDataWidth-1:0] ddr3_wdata_encrypted;
   logic [XbarCfg.AxiDataWidth-1:0] ddr3_rdata_decrypted;

   `ifdef SECURE_LAYER2
   localparam DDR3_CTR_KEY = 256'hDEADBEEFCAFEF00DBAADF00D1234567887654321ABCDEF01FEDCBA9876543210;

   logic w_addr_fifo_push, w_addr_fifo_pop, w_addr_fifo_empty, w_addr_fifo_full;
   logic [XbarCfg.AxiAddrWidth-1:0] w_addr_fifo_data_i, w_addr_fifo_data_o, write_addr_for_enc;
   logic write_burst_active;

   assign w_addr_fifo_push = atomics_mst_awvalid && atomics_mst_awready;
   assign w_addr_fifo_data_i = atomics_mst_awaddr;
   assign w_addr_fifo_pop = atomics_mst_wvalid && atomics_mst_wready && !write_burst_active;

   wire rst_n_dram = (rst_ni & system_reset_o & pll_locked) || uart_dram_mode;

   always_ff @(posedge clkwiz_o or negedge rst_n_dram) begin
      if (~rst_n_dram) write_burst_active <= 1'b0;
      else if (atomics_mst_wvalid && atomics_mst_wready) write_burst_active <= !atomics_mst_wlast;
   end

   always_ff @(posedge clkwiz_o or negedge rst_n_dram) begin
      if (~rst_n_dram) write_addr_for_enc <= '0;
      else if (w_addr_fifo_pop) write_addr_for_enc <= w_addr_fifo_data_o;
      else if (atomics_mst_wvalid && atomics_mst_wready && write_burst_active) write_addr_for_enc <= write_addr_for_enc + (XbarCfg.AxiDataWidth / 8);
   end

   fifo_v3 #(
       .DATA_WIDTH(XbarCfg.AxiAddrWidth),
       .DEPTH(16)
   ) w_addr_fifo (
       .clk_i      (clkwiz_o),
       .rst_ni     (rst_n_dram),
       .flush_i    (1'b0),
       .testmode_i (1'b0),
       .full_o     (w_addr_fifo_full),
       .empty_o    (w_addr_fifo_empty),
       .usage_o    (),
       .data_i     (w_addr_fifo_data_i),
       .push_i     (w_addr_fifo_push),
       .data_o     (w_addr_fifo_data_o),
       .pop_i      (w_addr_fifo_pop)
   );

   ctr_encoder_decoder #(
       .KEY(DDR3_CTR_KEY)
   ) ddr3_ctr_enc (
       .row_number (write_addr_for_enc),
       .data_in    (atomics_mst_wdata),
       .data_out   (ddr3_wdata_encrypted)
   );

   logic r_addr_fifo_push, r_addr_fifo_pop, r_addr_fifo_empty, r_addr_fifo_full;
   logic [XbarCfg.AxiAddrWidth-1:0] r_addr_fifo_data_i, r_addr_fifo_data_o, read_addr_for_dec;
   logic read_burst_active;

   assign r_addr_fifo_push = atomics_mst_arvalid && atomics_mst_arready;
   assign r_addr_fifo_data_i = atomics_mst_araddr;
   assign r_addr_fifo_pop = encrypted_axi_rvalid && encrypted_axi_rready && !read_burst_active;

   always_ff @(posedge clkwiz_o or negedge rst_n_dram) begin
      if (~rst_n_dram) read_burst_active <= 1'b0;
      else if (encrypted_axi_rvalid && encrypted_axi_rready) read_burst_active <= !encrypted_axi_rlast;
   end

   always_ff @(posedge clkwiz_o or negedge rst_n_dram) begin
      if (~rst_n_dram) read_addr_for_dec <= '0;
      else if (r_addr_fifo_pop) read_addr_for_dec <= r_addr_fifo_data_o;
      else if (encrypted_axi_rvalid && encrypted_axi_rready && read_burst_active) read_addr_for_dec <= read_addr_for_dec + (XbarCfg.AxiDataWidth / 8);
   end

   fifo_v3 #(
       .DATA_WIDTH(XbarCfg.AxiAddrWidth),
       .DEPTH(16)
   ) r_addr_fifo (
       .clk_i      (clkwiz_o),
       .rst_ni     (rst_n_dram),
       .flush_i    (1'b0),
       .testmode_i (1'b0),
       .full_o     (r_addr_fifo_full),
       .empty_o    (r_addr_fifo_empty),
       .usage_o    (),
       .data_i     (r_addr_fifo_data_i),
       .push_i     (r_addr_fifo_push),
       .data_o     (r_addr_fifo_data_o),
       .pop_i      (r_addr_fifo_pop)
   );

   ctr_encoder_decoder #(
       .KEY(DDR3_CTR_KEY)
   ) ddr3_ctr_dec (
       .row_number (read_addr_for_dec),
       .data_in    (encrypted_axi_rdata),
       .data_out   (ddr3_rdata_decrypted)
   );
   `else
   assign ddr3_wdata_encrypted = atomics_mst_wdata;
   assign ddr3_rdata_decrypted = encrypted_axi_rdata;
   `endif

   assign encrypted_axi_awvalid = atomics_mst_awvalid;
   assign atomics_mst_awready   = encrypted_axi_awready;
   assign encrypted_axi_awaddr  = atomics_mst_awaddr;
   assign encrypted_axi_awid    = atomics_mst_awid;
   assign encrypted_axi_awlen   = atomics_mst_awlen;
   assign encrypted_axi_awsize  = atomics_mst_awsize;
   assign encrypted_axi_awburst = atomics_mst_awburst;
   assign encrypted_axi_awprot  = atomics_mst_awprot;
   assign encrypted_axi_wvalid  = atomics_mst_wvalid;
   assign atomics_mst_wready    = encrypted_axi_wready;
   assign encrypted_axi_wdata   = ddr3_wdata_encrypted;
   assign encrypted_axi_wstrb   = atomics_mst_wstrb;
   assign encrypted_axi_wlast   = atomics_mst_wlast;
   assign atomics_mst_bvalid    = encrypted_axi_bvalid;
   assign encrypted_axi_bready  = atomics_mst_bready;
   assign atomics_mst_bid       = encrypted_axi_bid;
   assign atomics_mst_bresp     = encrypted_axi_bresp;
   assign encrypted_axi_arvalid = atomics_mst_arvalid;
   assign atomics_mst_arready   = encrypted_axi_arready;
   assign encrypted_axi_araddr  = atomics_mst_araddr;
   assign encrypted_axi_arid    = atomics_mst_arid;
   assign encrypted_axi_arlen   = atomics_mst_arlen;
   assign encrypted_axi_arsize  = atomics_mst_arsize;
   assign encrypted_axi_arburst = atomics_mst_arburst;
   assign encrypted_axi_arprot  = atomics_mst_arprot;
   assign atomics_mst_rvalid    = encrypted_axi_rvalid;
   assign encrypted_axi_rready  = atomics_mst_rready;
   assign atomics_mst_rid       = encrypted_axi_rid;
   assign atomics_mst_rdata     = ddr3_rdata_decrypted;
   assign atomics_mst_rresp     = encrypted_axi_rresp;
   assign atomics_mst_rlast     = encrypted_axi_rlast;

   dram_controller_axi #(
       .AXI_ID_WIDTH  (AXI_ID_WIDTH_XBAR_MST),
       .AXI_ADDR_WIDTH(XbarCfg.AxiAddrWidth),
       .AXI_DATA_WIDTH(XbarCfg.AxiDataWidth)
   ) dram_dut (
       .clk_i        (clkwiz_o),
       .rst_ni       ((rst_ni & system_reset_o & pll_locked) || uart_dram_mode),
       .s_axi_awvalid(encrypted_axi_awvalid),
       .s_axi_awready(encrypted_axi_awready),
       .s_axi_awaddr (encrypted_axi_awaddr),
       .s_axi_awid   (encrypted_axi_awid),
       .s_axi_awlen  (encrypted_axi_awlen),
       .s_axi_awsize (encrypted_axi_awsize),
       .s_axi_awburst(encrypted_axi_awburst),
       .s_axi_awprot (encrypted_axi_awprot),
       .s_axi_wvalid (encrypted_axi_wvalid),
       .s_axi_wready (encrypted_axi_wready),
       .s_axi_wdata  (encrypted_axi_wdata),
       .s_axi_wstrb  (encrypted_axi_wstrb),
       .s_axi_wlast  (encrypted_axi_wlast),
       .s_axi_bvalid (encrypted_axi_bvalid),
       .s_axi_bready (encrypted_axi_bready),
       .s_axi_bid    (encrypted_axi_bid),
       .s_axi_bresp  (encrypted_axi_bresp),
       .s_axi_arvalid(encrypted_axi_arvalid),
       .s_axi_arready(encrypted_axi_arready),
       .s_axi_araddr (encrypted_axi_araddr),
       .s_axi_arid   (encrypted_axi_arid),
       .s_axi_arlen  (encrypted_axi_arlen),
       .s_axi_arsize (encrypted_axi_arsize),
       .s_axi_arburst(encrypted_axi_arburst),
       .s_axi_arprot (encrypted_axi_arprot),
       .s_axi_rvalid (encrypted_axi_rvalid),
       .s_axi_rready (encrypted_axi_rready),
       .s_axi_rid    (encrypted_axi_rid),
       .s_axi_rdata  (encrypted_axi_rdata),
       .s_axi_rresp  (encrypted_axi_rresp),
       .s_axi_rlast  (encrypted_axi_rlast),
       .ddr3_reset_n (ddr3_reset_n),
       .ddr3_cke     (ddr3_cke),
       .ddr3_ck_p    (ddr3_ck_p),
       .ddr3_ck_n    (ddr3_ck_n),
       .ddr3_cs_n    (ddr3_cs_n),
       .ddr3_ras_n   (ddr3_ras_n),
       .ddr3_cas_n   (ddr3_cas_n),
       .ddr3_we_n    (ddr3_we_n),
       .ddr3_ba      (ddr3_ba),
       .ddr3_addr    (ddr3_addr),
       .ddr3_odt     (ddr3_odt),
       .ddr3_dm      (ddr3_dm),
       .ddr3_dqs_p   (ddr3_dqs_p),
       .ddr3_dqs_n   (ddr3_dqs_n),
       .ddr3_dq      (ddr3_dq),
       .clk100       (clk100),
       .clk_ddr      (clk_ddr),
       .clk_ref      (clk_ref),
       .clk_ddr_dqs  (clk_ddr_dqs),
       .uart_dram_write_we_i   (uart_dram_write_we),
       .uart_dram_write_addr_i (uart_dram_write_addr),
       .uart_dram_write_data_i (uart_dram_write_data),
       .uart_dram_write_rst_i  (0)
   );
   `elsif USE_SRAM
   logic        ram8_req_i;
   logic        ram8_we_i;
   logic [AdapterObiCfg.DataWidth/8-1:0] ram8_be_i;
   logic [AdapterObiCfg.AddrWidth-1:0] ram8_addr_i;
   logic [AdapterObiCfg.DataWidth-1:0] ram8_wdata_i;
   logic        ram8_rvalid_o;
   logic [AdapterObiCfg.DataWidth-1:0] ram8_rdata_o;

   logic [AdapterObiCfg.DataWidth-1:0] sram_wdata_encrypted;
   logic [AdapterObiCfg.DataWidth-1:0] sram_rdata_decrypted;

   `ifdef SECURE_LAYER2
   // On-The-Fly Encryption/Decryption
   reg [AdapterObiCfg.AddrWidth-1:0] sram_addr_holder;
   always_ff @(posedge clkwiz_o or negedge rst_n) begin
      if (~rst_n) begin
         sram_addr_holder <= '0;
      end
      else if (mem8_obi_req.req && !mem8_obi_req.a.we) begin
         sram_addr_holder <= mem8_obi_req.a.addr;
      end
   end

   localparam SRAM_CTR_KEY = 256'hDEADBEEFCAFEF00DBAADF00D1234567887654321ABCDEF01FEDCBA9876543210;

   ctr_encoder_decoder #(.KEY(SRAM_CTR_KEY)) sram_ctr_enc (
      .row_number(mem8_obi_req.a.addr),
      .data_in(mem8_obi_req.a.wdata),
      .data_out(sram_wdata_encrypted)
   );

   ctr_encoder_decoder #(.KEY(SRAM_CTR_KEY)) sram_ctr_dec (
      .row_number(sram_addr_holder),
      .data_in(ram8_rdata_o),
      .data_out(sram_rdata_decrypted)
   );
   `else
   assign sram_wdata_encrypted = mem8_obi_req.a.wdata;
   assign sram_rdata_decrypted = ram8_rdata_o;
   `endif

   adapter_obi_req_t mem8_obi_req;
   adapter_obi_rsp_t mem8_obi_rsp;

   axi_to_obi #(
      .ObiCfg         ( AdapterObiCfg          ),
      .obi_req_t      ( adapter_obi_req_t      ),
      .obi_rsp_t      ( adapter_obi_rsp_t      ),
      .obi_a_chan_t   ( adapter_obi_a_chan_t   ),
      .obi_r_chan_t   ( adapter_obi_r_chan_t   ),
      .AxiAddrWidth   ( XbarCfg.AxiAddrWidth   ),
      .AxiDataWidth   ( XbarCfg.AxiDataWidth   ),
      .AxiIdWidth     ( AXI_ID_WIDTH_XBAR_MST  ),
      .AxiUserWidth   ( cva6_config_pkg::CVA6ConfigDataUserWidth ),
      .MaxTrans       ( AXI_MAX_TRANS          ),
      .axi_req_t      ( ariane_axi::req_t      ),
      .axi_rsp_t      ( ariane_axi::resp_t     )
   ) i_axi_to_obi_mem8 (
      .clk_i        ( clkwiz_o                            ),
      .rst_ni       ( rst_n                               ),
      .testmode_i   ( 1'b0                                ),
      .axi_req_i    ( xbar_mst_ports_req[MASTER_DRAM_IDX]  ),
      .axi_rsp_o    ( xbar_mst_ports_resp[MASTER_DRAM_IDX] ),
      .obi_req_o    ( mem8_obi_req                         ),
      .obi_rsp_i    ( mem8_obi_rsp                         ),
      .req_aw_id_o (), .req_aw_user_o (), .req_w_user_o (),
      .req_write_aid_i ('0),.req_write_auser_i ('0),.req_write_wuser_i ('0),
      .req_ar_id_o (), .req_ar_user_o (),
      .req_read_aid_i ('0),.req_read_auser_i ('0),
      .rsp_write_aw_user_o (), .rsp_write_w_user_o (), .rsp_write_bank_strb_o (),
      .rsp_write_rid_o (), .rsp_write_ruser_o (), .rsp_write_last_o (),
      .rsp_write_hs_o (), .rsp_b_user_i ('0),
      .rsp_read_ar_user_o (), .rsp_read_size_enable_o (), .rsp_read_rid_o (),
      .rsp_read_ruser_o (), .rsp_r_user_i ('0)
   );

   assign ram8_req_i   = mem8_obi_req.req;
   assign ram8_we_i    = mem8_obi_req.a.we;
   assign ram8_addr_i  = mem8_obi_req.a.addr[30:0];
   assign ram8_wdata_i = sram_wdata_encrypted;
   assign ram8_be_i    = mem8_obi_req.a.be;

   assign mem8_obi_rsp.gnt    = 1;
   assign mem8_obi_rsp.rvalid = ram8_rvalid_o;
   assign mem8_obi_rsp.r.rdata = sram_rdata_decrypted;
   assign mem8_obi_rsp.r.rid   = mem8_obi_req.a.aid;
   assign mem8_obi_rsp.r.err  = 1'b0;

   ram32 #(
      .SIZE     ('h40000/4),
      .INIT_FILE(`RAM_FPATH), //("/home/shc/projects/riscv-linux-boot/opensbi/build/platform/template/firmware/fw_dynamic.hex"),
      .USE_BOOTROM(0)
   ) main_memory8 (
      .clk_i   (clkwiz_o),
      .rst_ni  (rst_n),
      .req_i   ( ram8_req_i      ),
      .we_i    ( ram8_we_i       ),
      .be_i    ( ram8_be_i       ),
      .addr_i  ( ram8_addr_i     ),
      .wdata_i ( ram8_wdata_i    ),
      .rvalid_o( ram8_rvalid_o   ),
      .rdata_o ( ram8_rdata_o    )

      ,.program_rx_i   (    )
      ,.system_reset_o (  )
      ,.prog_mode_led_o( )
   );
   `elsif DDR3_AXI
   logic                            dram_axi_awvalid;
   logic                            dram_axi_awready;
   logic [XbarCfg.AxiAddrWidth-1:0] dram_axi_awaddr;
   logic [AXI_ID_WIDTH_XBAR_MST-1:0]dram_axi_awid;
   logic [7:0]                      dram_axi_awlen;
   logic [1:0]                      dram_axi_awburst;
   logic [2:0]                      dram_axi_awprot;
   logic                            dram_axi_wvalid;
   logic                            dram_axi_wready;
   logic [XbarCfg.AxiDataWidth-1:0] dram_axi_wdata;
   logic [XbarCfg.AxiDataWidth/8-1:0] dram_axi_wstrb;
   logic                            dram_axi_wlast;
   logic                            dram_axi_bvalid;
   logic                            dram_axi_bready;
   logic [AXI_ID_WIDTH_XBAR_MST-1:0]dram_axi_bid;
   logic [1:0]                      dram_axi_bresp;
   logic                            dram_axi_arvalid;
   logic                            dram_axi_arready;
   logic [XbarCfg.AxiAddrWidth-1:0] dram_axi_araddr;
   logic [AXI_ID_WIDTH_XBAR_MST-1:0]dram_axi_arid;
   logic [7:0]                      dram_axi_arlen;
   logic [1:0]                      dram_axi_arburst;
   logic [2:0]                      dram_axi_arprot;
   logic                            dram_axi_rvalid;
   logic                            dram_axi_rready;
   logic [AXI_ID_WIDTH_XBAR_MST-1:0]dram_axi_rid;
   logic [XbarCfg.AxiDataWidth-1:0] dram_axi_rdata;
   logic [1:0]                      dram_axi_rresp;
   logic                            dram_axi_rlast;

   logic [XbarCfg.AxiDataWidth-1:0] ddr3_wdata_encrypted;
   logic [XbarCfg.AxiDataWidth-1:0] ddr3_rdata_decrypted;

   `ifdef SECURE_LAYER2
   // On-The-Fly Encryption/Decryption
   localparam DDR3_CTR_KEY = 256'hDEADBEEFCAFEF00DBAADF00D1234567887654321ABCDEF01FEDCBA9876543210;

   // Write Path Address Management for CTR
   logic                               w_addr_fifo_push;
   logic                               w_addr_fifo_pop;
   logic [XbarCfg.AxiAddrWidth-1:0]    w_addr_fifo_data_i;
   logic [XbarCfg.AxiAddrWidth-1:0]    w_addr_fifo_data_o;
   logic                               w_addr_fifo_empty;
   logic                               w_addr_fifo_full;
   logic [XbarCfg.AxiAddrWidth-1:0]    write_addr_for_enc;
   logic                               write_burst_active;

   assign w_addr_fifo_push = xbar_mst_ports_req[MASTER_DRAM_IDX].aw_valid && dram_axi_awready;
   assign w_addr_fifo_data_i = xbar_mst_ports_req[MASTER_DRAM_IDX].aw.addr;
   // Pop address from FIFO only on the first beat of a transaction.
   assign w_addr_fifo_pop = xbar_mst_ports_req[MASTER_DRAM_IDX].w_valid && dram_axi_wready && !write_burst_active;

   // Track if a write burst is in progress
   always_ff @(posedge clkwiz_o or negedge rst_n) begin
       if (~rst_n) begin
           write_burst_active <= 1'b0;
       end else if (xbar_mst_ports_req[MASTER_DRAM_IDX].w_valid && dram_axi_wready) begin
           write_burst_active <= !xbar_mst_ports_req[MASTER_DRAM_IDX].w.last;
       end
   end

   // Increment address for each beat of the burst
   always_ff @(posedge clkwiz_o or negedge rst_n) begin
       if (~rst_n) begin
           write_addr_for_enc <= '0;
       end else if (w_addr_fifo_pop) begin // Load base address for the first beat
           write_addr_for_enc <= w_addr_fifo_data_o;
       // For subsequent beats, increment the address
       end else if (xbar_mst_ports_req[MASTER_DRAM_IDX].w_valid && dram_axi_wready && write_burst_active) begin
           write_addr_for_enc <= write_addr_for_enc + (XbarCfg.AxiDataWidth / 8);
       end
   end

   fifo_v3 #(
       .DATA_WIDTH(XbarCfg.AxiAddrWidth),
       .DEPTH(16)
   ) w_addr_fifo (
       .clk_i(clkwiz_o),
       .rst_ni(rst_n),
       .flush_i(1'b0),
       .testmode_i(1'b0),
       .full_o(w_addr_fifo_full),
       .empty_o(w_addr_fifo_empty),
       .usage_o(),
       .data_i(w_addr_fifo_data_i),
       .push_i(w_addr_fifo_push),
       .data_o(w_addr_fifo_data_o),
       .pop_i(w_addr_fifo_pop)
   );

   ctr_encoder_decoder #(.KEY(DDR3_CTR_KEY)) ddr3_ctr_enc (
       .row_number(write_addr_for_enc),
       .data_in(xbar_mst_ports_req[MASTER_DRAM_IDX].w.data),
       .data_out(ddr3_wdata_encrypted)
   );

   // Read Path Address Management for CTR
   logic                               r_addr_fifo_push;
   logic                               r_addr_fifo_pop;
   logic [XbarCfg.AxiAddrWidth-1:0]    r_addr_fifo_data_i;
   logic [XbarCfg.AxiAddrWidth-1:0]    r_addr_fifo_data_o;
   logic                               r_addr_fifo_empty;
   logic                               r_addr_fifo_full;
   logic [XbarCfg.AxiAddrWidth-1:0]    read_addr_for_dec;
   logic                               read_burst_active;

   assign r_addr_fifo_push = xbar_mst_ports_req[MASTER_DRAM_IDX].ar_valid && dram_axi_arready;
   assign r_addr_fifo_data_i = xbar_mst_ports_req[MASTER_DRAM_IDX].ar.addr;
   // Pop address from FIFO only on the first beat of a transaction.
   assign r_addr_fifo_pop = dram_axi_rvalid && dram_axi_rready && !read_burst_active;

   // Track if a read burst is in progress
   always_ff @(posedge clkwiz_o or negedge rst_n) begin
       if (~rst_n) begin
           read_burst_active <= 1'b0;
       end else if (dram_axi_rvalid && dram_axi_rready) begin
           read_burst_active <= !dram_axi_rlast;
       end
   end

   // Increment address for each beat of the burst
   always_ff @(posedge clkwiz_o or negedge rst_n) begin
       if (~rst_n) begin
           read_addr_for_dec <= '0;
       end else if (r_addr_fifo_pop) begin // Load base address for the first beat
           read_addr_for_dec <= r_addr_fifo_data_o;
       // For subsequent beats, increment the address
       end else if (dram_axi_rvalid && dram_axi_rready && read_burst_active) begin
           read_addr_for_dec <= read_addr_for_dec + (XbarCfg.AxiDataWidth / 8);
       end
   end

   fifo_v3 #(
       .DATA_WIDTH(XbarCfg.AxiAddrWidth),
       .DEPTH(16)
   ) r_addr_fifo (
       .clk_i(clkwiz_o),
       .rst_ni(rst_n),
       .flush_i(1'b0),
       .testmode_i(1'b0),
       .full_o(r_addr_fifo_full),
       .empty_o(r_addr_fifo_empty),
       .usage_o(),
       .data_i(r_addr_fifo_data_i),
       .push_i(r_addr_fifo_push),
       .data_o(r_addr_fifo_data_o),
       .pop_i(r_addr_fifo_pop)
   );

   ctr_encoder_decoder #(.KEY(DDR3_CTR_KEY)) ddr3_ctr_dec (
       .row_number(read_addr_for_dec),
       .data_in(dram_axi_rdata),
       .data_out(ddr3_rdata_decrypted)
   );
   `else
   assign ddr3_wdata_encrypted = xbar_mst_ports_req[MASTER_DRAM_IDX].w.data;
   assign ddr3_rdata_decrypted = dram_axi_rdata;
   `endif
   
   assign dram_axi_awvalid = xbar_mst_ports_req[MASTER_DRAM_IDX].aw_valid;
   assign dram_axi_awaddr  = xbar_mst_ports_req[MASTER_DRAM_IDX].aw.addr;
   assign dram_axi_awid    = xbar_mst_ports_req[MASTER_DRAM_IDX].aw.id;
   assign dram_axi_awlen   = xbar_mst_ports_req[MASTER_DRAM_IDX].aw.len;
   assign dram_axi_awburst = xbar_mst_ports_req[MASTER_DRAM_IDX].aw.burst;
   assign dram_axi_awprot  = xbar_mst_ports_req[MASTER_DRAM_IDX].aw.prot;

   assign dram_axi_wvalid  = xbar_mst_ports_req[MASTER_DRAM_IDX].w_valid;
   assign dram_axi_wdata   = ddr3_wdata_encrypted;
   assign dram_axi_wstrb   = xbar_mst_ports_req[MASTER_DRAM_IDX].w.strb;
   assign dram_axi_wlast   = xbar_mst_ports_req[MASTER_DRAM_IDX].w.last;

   assign dram_axi_arvalid = xbar_mst_ports_req[MASTER_DRAM_IDX].ar_valid;
   assign dram_axi_araddr  = xbar_mst_ports_req[MASTER_DRAM_IDX].ar.addr;
   assign dram_axi_arid    = xbar_mst_ports_req[MASTER_DRAM_IDX].ar.id;
   assign dram_axi_arlen   = xbar_mst_ports_req[MASTER_DRAM_IDX].ar.len;
   assign dram_axi_arburst = xbar_mst_ports_req[MASTER_DRAM_IDX].ar.burst;
   assign dram_axi_arprot  = xbar_mst_ports_req[MASTER_DRAM_IDX].ar.prot;

   assign dram_axi_bready  = xbar_mst_ports_req[MASTER_DRAM_IDX].b_ready;
   assign dram_axi_rready  = xbar_mst_ports_req[MASTER_DRAM_IDX].r_ready;

   assign xbar_mst_ports_resp[MASTER_DRAM_IDX].aw_ready = dram_axi_awready;
   assign xbar_mst_ports_resp[MASTER_DRAM_IDX].w_ready  = dram_axi_wready;
   assign xbar_mst_ports_resp[MASTER_DRAM_IDX].ar_ready = dram_axi_arready;

   assign xbar_mst_ports_resp[MASTER_DRAM_IDX].b_valid  = dram_axi_bvalid;
   assign xbar_mst_ports_resp[MASTER_DRAM_IDX].b.id     = dram_axi_bid;
   assign xbar_mst_ports_resp[MASTER_DRAM_IDX].b.resp   = dram_axi_bresp;

   assign xbar_mst_ports_resp[MASTER_DRAM_IDX].r_valid  = dram_axi_rvalid;
   assign xbar_mst_ports_resp[MASTER_DRAM_IDX].r.id     = dram_axi_rid;
   assign xbar_mst_ports_resp[MASTER_DRAM_IDX].r.data   = ddr3_rdata_decrypted;
   assign xbar_mst_ports_resp[MASTER_DRAM_IDX].r.resp   = dram_axi_rresp;
   assign xbar_mst_ports_resp[MASTER_DRAM_IDX].r.last   = dram_axi_rlast;

   logic [14:0] dfi_address_to_phy_w;
   logic [2:0]  dfi_bank_to_phy_w;
   logic        dfi_cas_n_to_phy_w;
   logic        dfi_cke_to_phy_w;
   logic        dfi_cs_n_to_phy_w;
   logic        dfi_odt_to_phy_w;
   logic        dfi_ras_n_to_phy_w;
   logic        dfi_reset_n_to_phy_w;
   logic        dfi_we_n_to_phy_w;
   logic [XbarCfg.AxiDataWidth-1:0] dfi_wrdata_to_phy_w;
   logic        dfi_wrdata_en_to_phy_w;
   logic [XbarCfg.AxiDataWidth/8/2-1:0]  dfi_wrdata_mask_to_phy_w;
   logic        dfi_rddata_en_to_phy_w;

   logic [XbarCfg.AxiDataWidth-1:0] dfi_rddata_from_phy_w;
   logic        dfi_rddata_valid_from_phy_w;
   logic [XbarCfg.AxiDataWidth/32-1:0]  dfi_rddata_dnv_from_phy_w;

   ddr3_axi #(
       .DDR_MHZ          ( `DDR_MHZ ),
       .DDR_WRITE_LATENCY( `DDR_WRITE_LATENCY ),
       .DDR_READ_LATENCY ( `DDR_READ_LATENCY )
   ) i_ddr3_axi (
       .clk_i   ( clkwiz_o ),
       .rst_i   ( ~rst_n   ),

       .inport_awvalid_i ( dram_axi_awvalid ),
       .inport_awaddr_i  ( dram_axi_awaddr ),
       .inport_awid_i    ( dram_axi_awid    ),
       .inport_awlen_i   ( dram_axi_awlen        ),
       .inport_awburst_i ( dram_axi_awburst      ),
       .inport_awready_o ( dram_axi_awready      ),

       .inport_wvalid_i  ( dram_axi_wvalid  ),
       .inport_wdata_i   ( dram_axi_wdata   ),
       .inport_wstrb_i   ( dram_axi_wstrb   ),
       .inport_wlast_i   ( dram_axi_wlast   ),
       .inport_wready_o  ( dram_axi_wready  ),

       .inport_bready_i  ( dram_axi_bready  ),
       .inport_bvalid_o  ( dram_axi_bvalid  ),
       .inport_bresp_o   ( dram_axi_bresp   ),
       .inport_bid_o     ( dram_axi_bid     ),

       .inport_arvalid_i ( dram_axi_arvalid ),
       .inport_araddr_i  ( dram_axi_araddr ),
       .inport_arid_i    ( dram_axi_arid    ),
       .inport_arlen_i   ( dram_axi_arlen        ),
       .inport_arburst_i ( dram_axi_arburst      ),
       .inport_arready_o ( dram_axi_arready      ),

       .inport_rready_i  ( dram_axi_rready  ),
       .inport_rvalid_o  ( dram_axi_rvalid  ),
       .inport_rdata_o   ( dram_axi_rdata   ),
       .inport_rresp_o   ( dram_axi_rresp   ),
       .inport_rid_o     ( dram_axi_rid     ),
       .inport_rlast_o   ( dram_axi_rlast   ),

       .dfi_rddata_i       ( dfi_rddata_from_phy_w       ),
       .dfi_rddata_valid_i ( dfi_rddata_valid_from_phy_w ),
       .dfi_rddata_dnv_i   ( dfi_rddata_dnv_from_phy_w   ),

       .dfi_address_o     ( dfi_address_to_phy_w         ),
       .dfi_bank_o        ( dfi_bank_to_phy_w            ),
       .dfi_cas_n_o       ( dfi_cas_n_to_phy_w           ),
       .dfi_cke_o         ( dfi_cke_to_phy_w             ),
       .dfi_cs_n_o        ( dfi_cs_n_to_phy_w            ),
       .dfi_odt_o         ( dfi_odt_to_phy_w             ),
       .dfi_ras_n_o       ( dfi_ras_n_to_phy_w           ),
       .dfi_reset_n_o     ( dfi_reset_n_to_phy_w         ),
       .dfi_we_n_o        ( dfi_we_n_to_phy_w            ),
       .dfi_wrdata_o      ( dfi_wrdata_to_phy_w          ),
       .dfi_wrdata_en_o   ( dfi_wrdata_en_to_phy_w       ),
       .dfi_wrdata_mask_o ( dfi_wrdata_mask_to_phy_w     ),
       .dfi_rddata_en_o   ( dfi_rddata_en_to_phy_w       )
   );

   ddr3_dfi_phy
   #(
       .DQS_TAP_DELAY_INIT(27),
       .DQ_TAP_DELAY_INIT(0),
       .TPHY_RDLAT(5)
   )
   i_ddr3_dfi_phy (
       .clk_i         ( clk100      ),
       .clk_ddr_i     ( clk_ddr     ),
       .clk_ddr90_i   ( clk_ddr_dqs ),
       .clk_ref_i     ( clk_ref     ),
       .rst_i         ( ~rst_n      ),

       .cfg_valid_i   ( 1'b0 ),
       .cfg_i         ( '0   ),

       .dfi_address_i     ( dfi_address_to_phy_w         ),
       .dfi_bank_i        ( dfi_bank_to_phy_w            ),
       .dfi_cas_n_i       ( dfi_cas_n_to_phy_w           ),
       .dfi_cke_i         ( dfi_cke_to_phy_w             ),
       .dfi_cs_n_i        ( dfi_cs_n_to_phy_w            ),
       .dfi_odt_i         ( dfi_odt_to_phy_w             ),
       .dfi_ras_n_i       ( dfi_ras_n_to_phy_w           ),
       .dfi_reset_n_i     ( dfi_reset_n_to_phy_w         ),
       .dfi_we_n_i        ( dfi_we_n_to_phy_w            ),
       .dfi_wrdata_i      ( dfi_wrdata_to_phy_w          ),
       .dfi_wrdata_en_i   ( dfi_wrdata_en_to_phy_w       ),
       .dfi_wrdata_mask_i ( dfi_wrdata_mask_to_phy_w     ),
       .dfi_rddata_en_i   ( dfi_rddata_en_to_phy_w       ),

       .dfi_rddata_o       ( dfi_rddata_from_phy_w        ),
       .dfi_rddata_valid_o ( dfi_rddata_valid_from_phy_w  ),
       .dfi_rddata_dnv_o   ( dfi_rddata_dnv_from_phy_w    ),

       .ddr3_ck_p_o   ( ddr3_ck_p   ),
       .ddr3_ck_n_o   ( ddr3_ck_n   ),
       .ddr3_cke_o    ( ddr3_cke    ),
       .ddr3_reset_n_o( ddr3_reset_n),
       .ddr3_ras_n_o  ( ddr3_ras_n  ),
       .ddr3_cas_n_o  ( ddr3_cas_n  ),
       .ddr3_we_n_o   ( ddr3_we_n   ),
       .ddr3_cs_n_o   ( ddr3_cs_n   ),
       .ddr3_ba_o     ( ddr3_ba     ),
       .ddr3_addr_o   ( ddr3_addr   ),
       .ddr3_odt_o    ( ddr3_odt    ),
       .ddr3_dm_o     ( ddr3_dm     ),
       .ddr3_dqs_p_io ( ddr3_dqs_p  ),
       .ddr3_dqs_n_io ( ddr3_dqs_n  ),
       .ddr3_dq_io    ( ddr3_dq     )
   );
   `endif

`else // END of CORE_CVA6
// CORE_CV32E40P or CORE_IBEX
logic               mem_req;
   logic [       31:0] mem_addr;
   logic               mem_we;
   logic [        3:0] mem_be;
   logic [       31:0] mem_wdata;
   logic               mem_rvalid;
   logic [       31:0] mem_rdata;

   // Instruction fetch interface
   logic               instr_req;
   logic [       31:0] instr_addr;
   logic               instr_gnt;
   logic               instr_rvalid;
   logic [       31:0] instr_rdata;

   // Data arbiter for main core
   logic                data_req;
   logic [       31:0]  data_addr;
   logic                data_we;
   logic [`MEM_W/8-1:0] data_be;
   logic [`MEM_W  -1:0] data_wdata;
   logic                data_gnt;
   logic                data_rvalid;
   logic [`MEM_W  -1:0] data_rdata;

   logic                cache_req;
   logic [       31:0]  cache_addr;
   logic                cache_we;
   logic [`MEM_W/8-1:0] cache_be;
   logic [`MEM_W  -1:0] cache_wdata;
   logic                cache_gnt;
   logic                cache_rvalid;
   logic [`MEM_W  -1:0] cache_rdata;

   logic                uart_req;
   logic [       31:0]  uart_addr;
   logic                uart_we;
   logic [`MEM_W/8-1:0] uart_be;
   logic [`MEM_W  -1:0] uart_wdata;
   logic                uart_gnt;
   logic                uart_rvalid;
   logic [`MEM_W  -1:0] uart_rdata;

   logic                timer_req;
   logic [       31:0]  timer_addr;
   logic                timer_we;
   logic [`MEM_W/8-1:0] timer_be;
   logic [`MEM_W  -1:0] timer_wdata;
   logic                timer_gnt;
   logic                timer_rvalid;
   logic [`MEM_W  -1:0] timer_rdata;

   logic                qspi_req;
   logic [       31:0]  qspi_addr;
   logic                qspi_we;
   logic [`MEM_W/8-1:0] qspi_be;
   logic [`MEM_W  -1:0] qspi_wdata;
   logic                qspi_gnt;
   logic                qspi_rvalid;
   logic [`MEM_W  -1:0] qspi_rdata;

   `ifdef ZC706
   logic                dram_req;
   logic [       31:0]  dram_addr;
   logic                dram_we;
   logic [`MEM_W/8-1:0] dram_be;
   logic [`MEM_W  -1:0] dram_wdata;
   logic                dram_gnt;
   logic                dram_rvalid;
   logic [`MEM_W  -1:0] dram_rdata;
   `endif

   // instruction cache
   logic               imem_req;
   logic               imem_gnt;
   logic [       31:0] imem_addr;
   logic               imem_rvalid;
   logic [ `MEM_W-1:0] imem_rdata;

   // data cache
   logic                dmem_req;
   logic                dmem_gnt;
   logic [       31:0]  dmem_addr;
   logic                dmem_we;
   logic [         3:0] dmem_be;
   logic [`MEM_W  -1:0] dmem_wdata;
   logic                dmem_rvalid;
   logic                dmem_wvalid;
   logic [`MEM_W  -1:0] dmem_rdata;

   `ifdef SECOND_SRAM
   logic                mem_req2000;
   logic [       31:0] mem_addr2000;
   logic                mem_we2000;
   logic [        3:0] mem_be2000;
   logic [`MEM_W  -1:0] mem_wdata2000;
   logic [`MEM_W  -1:0] mem_wdata2000_encrypted;
   logic                mem_rvalid2000;
   logic [`MEM_W  -1:0] mem_rdata2000;
   logic [`MEM_W  -1:0] mem_rdata2000_decrypted;
   `endif

   `ifdef CORE_CV32E40P
   cv32e40p_top #(
       .COREV_PULP               ( `COREV_PULP ),
       .COREV_CLUSTER            ( `COREV_CLUSTER ),
       .FPU                      ( `FPU ),
       .FPU_ADDMUL_LAT           ( `FPU_ADDMUL_LAT ),
       .FPU_OTHERS_LAT           ( `FPU_OTHERS_LAT ),
       .ZFINX                    ( `ZFINX ),
       .NUM_MHPMCOUNTERS         ( `NUM_MHPMCOUNTERS )
   )
   cv32e40p_core_ip (
       .clk_i                    (clkwiz_o),
       .rst_ni                   (rst_n),

       .pulp_clock_en_i          (`PULP_CLOCK_EN), // PULP clock enable (only used if COREV_CLUSTER = 1)
       .scan_cg_en_i             (`SCAN_CG_EN), // Enable all clock gates for testing

       // Configuration
       .boot_addr_i              (`BOOT_ADDR),
       .mtvec_addr_i             (`MTVEC_ADDR),
       .dm_halt_addr_i           (`DM_HALT_ADDR),
       .hart_id_i                (`HART_ID),
       .dm_exception_addr_i      (`DM_EXCEPTION_ADDR),

       // Instruction memory interface
       .instr_req_o              (instr_req),
       .instr_gnt_i              (instr_gnt),
       .instr_rvalid_i           (instr_rvalid),
       .instr_addr_o             (instr_addr),
       .instr_rdata_i            (instr_rdata),

       // Data memory interface
       .data_req_o               (data_req),
       .data_gnt_i               (data_gnt),
       .data_rvalid_i            (data_rvalid),
       .data_we_o                (data_we),
       .data_be_o                (data_be),
       .data_addr_o              (data_addr),
       .data_wdata_o             (data_wdata),
       .data_rdata_i             (data_rdata),

       // TODO: Interrupt instead of polling peripherals
       // Interrupt interface
       .irq_i                    (32'h0), //({14'b0, timer_bus.irq, gpio_bus.irq, 16'b0}), //4'b0, 0, 3'b0, 0, 3'b0, 0, 3'b0}),
       .irq_ack_o                (),
       .irq_id_o                 (),

       // TODO: JTAG Integration
       // Debug interface
       .debug_req_i              (1'b0),
       .debug_havereset_o        (),
       .debug_running_o          (),
       .debug_halted_o           (),

       // CPU Control Signals
       .fetch_enable_i           (1'b1),
       .core_sleep_o             ()
   );
   `elsif CORE_IBEX
   ibex_top #(
       //.PMPEnable                    (PMPEnable),
       //.PMPGranularity               (PMPGranularity),
       //.PMPNumRegions                (PMPNumRegions),
       //.MHPMCounterNum               (NUM_MHPMCOUNTERS),
       //.MHPMCounterWidth             (MHPMCounterWidth),
       //.PMPRstCfg                    (PMPRstCfg),
       //.PMPRstAddr                   (PMPRstAddr),
       //.PMPRstMsecCfg                (PMPRstMsecCfg),
       //.RV32E                        (RV32E),
       //.RV32M                        (RV32M),
       //.RV32B                        (RV32B),
       //.RegFile                      (RegFile),
       //.BranchTargetALU              (BranchTargetALU),
       //.WritebackStage               (WritebackStage),
       //.ICache                       (ICache),
       //.ICacheECC                    (ICacheECC),
       //.BranchPredictor              (BranchPredictor),
       //.DbgTriggerEn                 (DbgTriggerEn),
       //.DbgHwBreakNum                (DbgHwBreakNum),
       //.SecureIbex                   (SecureIbex),
       //.ICacheScramble               (ICacheScramble),
       //.ICacheScrNumPrinceRoundsHalf (ICacheScrNumPrinceRoundsHalf),
       //.RndCnstLfsrSeed              (RndCnstLfsrSeed),
       //.RndCnstLfsrPerm              (RndCnstLfsrPerm),
       .DmBaseAddr                   (0),
       //.DmAddrMask                   (DmAddrMask),
       .DmHaltAddr                   (`DM_HALT_ADDR),
       .DmExceptionAddr              (`DM_EXCEPTION_ADDR)
       //,.RndCnstIbexKey               (RndCnstIbexKey),
       //.RndCnstIbexNonce             (RndCnstIbexNonce),
       //.CsrMvendorId                 (CsrMvendorId),
       //.CsrMimpId                    (CsrMimpId)
   ) ibex_core_ip (
       .clk_i                        (clkwiz_o),
       .rst_ni                       (rst_n),
       .test_en_i                    (`SCAN_CG_EN),
       .ram_cfg_i                    (prim_ram_1p_pkg::ram_1p_cfg_t'('0)),
       .hart_id_i                    (`HART_ID),
       .boot_addr_i                  (`BOOT_ADDR - 'h80), // ibex always assume there is a vector table until 0x80
       .instr_req_o                  (instr_req),
       .instr_gnt_i                  (instr_gnt),
       .instr_rvalid_i               (instr_rvalid),
       .instr_addr_o                 (instr_addr),
       .instr_rdata_i                (instr_rdata),
       .instr_rdata_intg_i           (0),
       .instr_err_i                  (0),
       .data_req_o                   (data_req),
       .data_gnt_i                   (data_gnt),
       .data_rvalid_i                (data_rvalid),
       .data_we_o                    (data_we),
       .data_be_o                    (data_be),
       .data_addr_o                  (data_addr),
       .data_wdata_o                 (data_wdata),
       .data_wdata_intg_o            (),
       .data_rdata_i                 (data_rdata),
       .data_rdata_intg_i            (0),
       .data_err_i                   (0),
       .irq_software_i               (0),
       .irq_timer_i                  (0),
       .irq_external_i               (0),
       .irq_fast_i                   (0),
       .irq_nm_i                     (0),
       .scramble_key_valid_i         (0),
       .scramble_key_i               (0),
       .scramble_nonce_i             (0),
       .scramble_req_o               (),
       .debug_req_i                  (1'b0),
       .crash_dump_o                 (),
       .double_fault_seen_o          (),
       .fetch_enable_i               (1'b1),
       .alert_minor_o                (),
       .alert_major_internal_o       (),
       .alert_major_bus_o            (),
       .core_sleep_o                 (),
       .scan_rst_ni                  (1'b1)
   );
   `endif

   generate
      if(`ICACHE_SZ > 0) begin
         cache #(
            .ADDR_BIT_W (32),
            .CPU_BYTE_W (4),
            .MEM_BYTE_W (`MEM_W / 8),
            .LINE_BYTE_W(`ICACHE_LINE_W / 8),
            .WAY_LEN    (`ICACHE_WAY_LEN)
         ) icache (
            .clk_i       (clkwiz_o),
            .rst_ni      (rst_n),
            .hold_mem_i  (1'b0),
            .cpu_req_i   (instr_req),
            .cpu_addr_i  (instr_addr),
            .cpu_we_i    ('0),
            .cpu_be_i    ('0),
            .cpu_wdata_i ('0),
            .cpu_gnt_o   (instr_gnt),
            .cpu_rvalid_o(instr_rvalid),
            .cpu_rdata_o (instr_rdata),
            .mem_req_o   (imem_req),
            .mem_addr_o  (imem_addr),
            .mem_we_o    (),
            .mem_wdata_o (),
            .mem_gnt_i   (imem_gnt),
            .mem_rvalid_i(imem_rvalid),
            .mem_rdata_i (imem_rdata)
         );
      end
      else begin
         assign instr_gnt    = imem_gnt;
         assign instr_rvalid = imem_rvalid;
         assign instr_rdata  = imem_rdata[31:0];
         assign imem_req     = instr_req;
         assign imem_addr    = instr_addr;
      end
   endgenerate

   generate
      if(`DCACHE_SZ > 0) begin
         cache #(
            .ADDR_BIT_W (32),
            .CPU_BYTE_W (`MEM_W / 8),
            .MEM_BYTE_W (`MEM_W / 8),
            .LINE_BYTE_W(`DCACHE_LINE_W / 8),
            .WAY_LEN    (`DCACHE_WAY_LEN)
         ) dcache (
            .clk_i     (clkwiz_o),
            .rst_ni    (rst_n),
            .hold_mem_i(1'b0),

            .cpu_req_i   (cache_req),
            .cpu_addr_i  (cache_addr),
            .cpu_we_i    (cache_we),
            .cpu_be_i    (cache_be),
            .cpu_wdata_i (cache_wdata),
            .cpu_gnt_o   (cache_gnt),
            .cpu_rvalid_o(cache_rvalid),
            .cpu_rdata_o (cache_rdata),

            .mem_req_o   (dmem_req),
            .mem_we_o    (dmem_we),
            .mem_addr_o  (dmem_addr),
            .mem_wdata_o (dmem_wdata),
            .mem_gnt_i   (dmem_gnt),
            .mem_rvalid_i(dmem_rvalid),
            .mem_rdata_i (dmem_rdata)
         );
         assign dmem_be = 4'b1111;
      end
      else begin
         assign dmem_req     = cache_req;
         assign dmem_we      = cache_we;
         assign dmem_be      = cache_be;
         assign dmem_addr    = cache_addr;
         assign dmem_wdata   = cache_wdata;
         assign cache_gnt    = 1'b1; //dmem_gnt;
         assign cache_rvalid = dmem_rvalid | dmem_wvalid;
         assign cache_rdata  = dmem_rdata;
      end
   endgenerate

   ///////////////////////////////////////////////////////////////////////////
   // MEMORY ARBITER
   generate
   `ifdef SECOND_SRAM
      logic mem_rvalid_combined;
      logic [`MEM_W-1:0] mem_rdata_combined;
      logic [31:0] combined_mem_addr;

      always_comb begin
         if (dmem_req) begin
            combined_mem_addr = dmem_addr;
            if (dmem_addr >= `CODE_RAM_BASE_ADDR) begin
               mem_req2000   = dmem_req;
               mem_addr2000  = dmem_addr;
               mem_we2000    = dmem_we;
               mem_be2000    = dmem_be;
               mem_wdata2000 = dmem_wdata;
               mem_req   = 1'b0;
               mem_addr  = 32'h0;
               mem_we    = 1'b0;
               mem_be    = 4'b0;
               mem_wdata = 32'h0;
            end else begin
               mem_req   = dmem_req;
               mem_addr  = dmem_addr;
               mem_we    = dmem_we;
               mem_be    = dmem_be;
               mem_wdata = dmem_wdata;
               mem_req2000   = 1'b0;
               mem_addr2000  = 32'h0;
               mem_we2000    = 1'b0;
               mem_be2000    = 4'b0;
               mem_wdata2000 = 32'h0;
            end
         end else if (imem_req) begin
            combined_mem_addr = imem_addr;
            if (imem_addr >= `CODE_RAM_BASE_ADDR) begin
               mem_req2000   = imem_req;
               mem_addr2000  = imem_addr;
               mem_we2000    = 1'b0;
               mem_be2000    = 4'b0;
               mem_wdata2000 = 32'h0;
               mem_req   = 1'b0;
               mem_addr  = 32'h0;
               mem_we    = 1'b0;
               mem_be    = 4'b0;
               mem_wdata = 32'h0;
            end else begin
               mem_req   = imem_req;
               mem_addr  = imem_addr;
               mem_req2000   = 1'b0;
               mem_addr2000  = 32'h0;
               mem_we2000    = 1'b0;
               mem_be2000    = 4'b0;
               mem_wdata2000 = 32'h0;
               mem_we    = 1'b0;
               mem_be    = 4'b0;
               mem_wdata = 32'h0;
            end
         end else begin
            mem_req   = 1'b0;
            mem_addr  = 32'h0;
            mem_we    = 1'b0;
            mem_be    = 4'b0;
            mem_wdata = 32'h0;
            mem_req2000   = 1'b0;
            mem_addr2000  = 32'h0;
            mem_we2000    = 1'b0;
            mem_be2000    = 4'b0;
            mem_wdata2000 = 32'h0;
            combined_mem_addr = 32'h0;
         end
      end

      assign imem_gnt = imem_req & ~dmem_req;
      assign dmem_gnt = dmem_req;

      assign mem_rvalid_combined = mem_rvalid | mem_rvalid2000;
      assign mem_rdata_combined  = mem_rvalid ? mem_rdata : mem_rdata2000_decrypted;

      logic        req_sources  [32];
      logic        req_write    [32];
      logic [31:0] imem_req_addr[32];
      logic [ 4:0] req_count;
      always_ff @(posedge clkwiz_o or negedge rst_n) begin
         if (~rst_n) begin
            req_count <= '0;
         end else begin
            if (mem_rvalid_combined) begin
               for (int i = 0; i < 31; i++) begin
                  req_sources[i]   <= req_sources[i+1];
                  req_write[i]     <= req_write[i+1];
                  imem_req_addr[i] <= imem_req_addr[i+1];
               end
               if (~imem_gnt & ~dmem_gnt) begin
                  req_count <= req_count - 1;
               end else begin
                  req_sources[req_count-1]   <= dmem_gnt;
                  req_write[req_count-1]     <= dmem_we | mem_we2000;
                  imem_req_addr[req_count-1] <= combined_mem_addr;
               end
            end else if (imem_gnt | dmem_gnt) begin
               req_sources[req_count]   <= dmem_gnt;
               req_write[req_count]     <= dmem_we | mem_we2000;
               imem_req_addr[req_count] <= combined_mem_addr;
               req_count                <= req_count + 1;
            end
         end
      end
      assign imem_rvalid = mem_rvalid_combined & ~req_sources[0];
      assign dmem_rvalid = mem_rvalid_combined & req_sources[0] & ~req_write[0];
      assign dmem_wvalid = mem_rvalid_combined & req_sources[0] & req_write[0];
      assign imem_rdata  = (`ICACHE_SZ > 0) ? mem_rdata_combined : mem_rdata_combined[(imem_req_addr[0][$clog2(`MEM_W)-1:0] & {3'b000, {($clog2(`MEM_W/8)-2){1'b1}}, 2'b00})*8 +: 32];
      assign dmem_rdata  = mem_rdata_combined;

   `else
      always_comb begin
         mem_req   = imem_req | dmem_req;
         mem_addr  = imem_addr;
         mem_we    = 1'b0;
         mem_be    = dmem_be;
         mem_wdata = dmem_wdata;
         if (dmem_req) begin
            mem_we   = dmem_we;
            mem_addr = dmem_addr;
         end
      end
      assign imem_gnt = imem_req & ~dmem_req;
      assign dmem_gnt = dmem_req;

      logic        req_sources  [32];
      logic        req_write    [32];
      logic [31:0] imem_req_addr[32];
      logic [ 4:0] req_count;
      always_ff @(posedge clkwiz_o or negedge rst_n) begin
         if (~rst_n) begin
            req_count <= '0;
         end else begin
            if (mem_rvalid) begin
               for (int i = 0; i < 31; i++) begin
                  req_sources[i]   <= req_sources[i+1];
                  req_write[i]     <= req_write[i+1];
                  imem_req_addr[i] <= imem_req_addr[i+1];
               end
               if (~imem_gnt & ~dmem_gnt) begin
                  req_count <= req_count - 1;
               end else begin
                  req_sources[req_count-1]   <= dmem_gnt;
                  req_write[req_count-1]     <= dmem_we;
                  imem_req_addr[req_count-1] <= imem_addr;
               end
            end else if (imem_gnt | dmem_gnt) begin
               req_sources[req_count]   <= dmem_gnt;
               req_write[req_count]     <= dmem_we;
               imem_req_addr[req_count] <= imem_addr;
               req_count                <= req_count + 1;
            end
         end
      end
      assign imem_rvalid = mem_rvalid & ~req_sources[0];
      assign dmem_rvalid = mem_rvalid & req_sources[0] & ~req_write[0];
      assign dmem_wvalid = mem_rvalid & req_sources[0] & req_write[0];
      assign imem_rdata  = (`ICACHE_SZ > 0) ? mem_rdata : mem_rdata[(imem_req_addr[0][$clog2(`MEM_W)-1:0] & {3'b000, {($clog2(`MEM_W/8)-2){1'b1}}, 2'b00})*8 +: 32];
      assign dmem_rdata  = mem_rdata;
   `endif
   endgenerate

   ram32 #(
      .SIZE     (`RAM_SIZE / 4),
      .INIT_FILE(`RAM_FPATH)
   ) main_memory (
      .clk_i   (clkwiz_o),
      .rst_ni  (rst_ni),
      .req_i   (mem_req),
      .we_i    (mem_req & mem_we),
      .be_i    (mem_be),
      .addr_i  (mem_addr),
      .wdata_i (mem_wdata),
      .rvalid_o(mem_rvalid),
      .rdata_o (mem_rdata)

      ,.program_rx_i(program_rx_i)
      ,.system_reset_o(system_reset_o)
      ,.prog_mode_led_o(prog_mode_led_o)
   );

   `ifdef SECOND_SRAM
   // On-The-Fly Encryption/Decryption
   // hold address for one cycle to meet timing of sram for decryption
   reg [31:0] addr_holder;
   always_ff @(posedge clkwiz_o or negedge rst_n) begin
      if (~rst_n) begin
         addr_holder <= 32'h0;
      end
      else begin
         addr_holder <= mem_addr2000 - `CODE_RAM_BASE_ADDR;
      end
   end

   `ifdef SECURE_LAYER2
   localparam CTR_KEY = 256'hDEADBEEFCAFEF00DBAADF00D1234567887654321ABCDEF01FEDCBA9876543210;

   ctr_encoder_decoder #(.KEY(CTR_KEY)) ctr_dec (
      .row_number(addr_holder),
      .data_in(mem_rdata2000),
      .data_out(mem_rdata2000_decrypted)
   );

   ctr_encoder_decoder #(.KEY(CTR_KEY)) ctr_enc (
      .row_number(mem_addr2000 - `CODE_RAM_BASE_ADDR),
      .data_in(mem_wdata2000),
      .data_out(mem_wdata2000_encrypted)
   );
   `else
   assign mem_rdata2000_decrypted = mem_rdata2000;
   assign mem_wdata2000_encrypted = mem_wdata2000;
   `endif

   ram32 #(
      .SIZE     (`RAM_SIZE / 4),
      .INIT_FILE(""),
      .USE_BOOTROM(0)
   ) main_memory2000 (
      .clk_i   (clkwiz_o),
      .rst_ni  (rst_n),
      .req_i   (mem_req2000),
      .we_i    (mem_req2000 & mem_we2000),
      .be_i    (mem_be2000),
      .addr_i  (mem_addr2000 - `CODE_RAM_BASE_ADDR),
      .wdata_i (mem_wdata2000_encrypted),
      .rvalid_o(mem_rvalid2000),
      .rdata_o (mem_rdata2000)

      ,.program_rx_i()
      ,.system_reset_o()
      ,.prog_mode_led_o()
   );
   `endif

   obi_demux_custom obi_demux_dut (
      .clk_i (clkwiz_o),
      .rst_ni(rst_n),

      .data_req_i   (data_req),
      .data_gnt_o   (data_gnt),
      .data_rvalid_o(data_rvalid),
      .data_we_i    (data_we),
      .data_be_i    (data_be),
      .data_addr_i  (data_addr),
      .data_wdata_i (data_wdata),
      .data_rdata_o (data_rdata),

      .cache_req_o   (cache_req),
      .cache_addr_o  (cache_addr),
      .cache_we_o    (cache_we),
      .cache_be_o    (cache_be),
      .cache_wdata_o (cache_wdata),
      .cache_gnt_i   (cache_gnt),
      .cache_rvalid_i(cache_rvalid),
      .cache_rdata_i (cache_rdata),

      .uart_req_o   (uart_req),
      .uart_addr_o  (uart_addr),
      .uart_we_o    (uart_we),
      .uart_be_o    (uart_be),
      .uart_wdata_o (uart_wdata),
      .uart_gnt_i   (uart_gnt),
      .uart_rvalid_i(uart_rvalid),
      .uart_rdata_i (uart_rdata),

      .timer_req_o   (timer_req),
      .timer_addr_o  (timer_addr),
      .timer_we_o    (timer_we),
      .timer_be_o    (timer_be),
      .timer_wdata_o (timer_wdata),
      .timer_gnt_i   (timer_gnt),
      .timer_rvalid_i(timer_rvalid),
      .timer_rdata_i (timer_rdata)

      ,.qspi_req_o   (qspi_req)
      ,.qspi_addr_o  (qspi_addr)
      ,.qspi_we_o    (qspi_we)
      ,.qspi_be_o    (qspi_be)
      ,.qspi_wdata_o (qspi_wdata)
      ,.qspi_gnt_i   (qspi_gnt)
      ,.qspi_rvalid_i(qspi_rvalid)
      ,.qspi_rdata_i (qspi_rdata)

      `ifdef ZC706
      ,.dram_req_o   (dram_req)
      ,.dram_addr_o  (dram_addr)
      ,.dram_we_o    (dram_we)
      ,.dram_be_o    (dram_be)
      ,.dram_wdata_o (dram_wdata)
      ,.dram_gnt_i   (dram_gnt)
      ,.dram_rvalid_i(dram_rvalid)
      ,.dram_rdata_i (dram_rdata)
      `endif
   );

   uart_controller_obi uart_dut (
      .clk_i   (clkwiz_o),
      .rst_ni  (rst_n),
      .req_i   (uart_req),
      .we_i    (uart_we),
      .be_i    (uart_be),
      .addr_i  (uart_addr),
      .wdata_i (uart_wdata),
      .gnt_o   (uart_gnt),
      .rvalid_o(uart_rvalid),
      .rdata_o (uart_rdata),
      .rx_i    (uart_rx_i),
      .tx_o    (uart_tx_o)
   );

   timer_controller_obi timer_dut (
      .clk_i   (clkwiz_o),
      .rst_ni  (rst_n),
      .req_i   (timer_req),
      .we_i    (timer_we),
      .be_i    (timer_be),
      .addr_i  (timer_addr),
      .wdata_i (timer_wdata),
      .gnt_o   (timer_gnt),
      .rvalid_o(timer_rvalid),
      .rdata_o (timer_rdata)
   );

   `ifndef ZC706
   `ifdef QSPI_SIM
   wire qspi_cs_n_o;
   wire qspi_sck_o;
   wire [3:0] qspi_data_io;

   s25fl128s #(
      //.mem_file_name("../../../tests/demo/demo.vmem"),
      .mem_file_name("../../../tests/demo/demo_secure.vmem"),
      //.mem_file_name("../../../rtl/sim/s25fl128s.mem"),
      //.mem_file_name("none"),
      .otp_file_name("none"),
      .AddrRANGE(24'h00FFFF)
      
      //,.TimingModel   ( "S25FS128SAGMFI000_F_30pF" )
      ,.TimingModel   ( "S25FL128SAGMFI000_F_30pF" )
      ,.UserPreload   (1)
   ) flash (
      // Data Inputs/Outputs
      .SI(qspi_data_io[0]),
      .SO(qspi_data_io[1]),
      // Controls
      .SCK(qspi_sck_o),
      .CSNeg(qspi_cs_n_o),
      //.RSTNeg(1),
      .WPNeg(qspi_data_io[2]),
      .HOLDNeg(qspi_data_io[3])
   );
   `endif

   wire [3:0] qspi_data_i;
   wire [3:0] qspi_data_o;
   wire [1:0] qspi_out_mod_o;
   `ifdef BASYS3
   IOBUF
   io_buf0
   (
        .I(qspi_data_o[0])
       ,.O(qspi_data_i[0])
       ,.T(~(|qspi_out_mod_o))
       ,.IO(qspi_data_io[0])
   );
      
   IOBUF
   io_buf1
   (
        .I(qspi_data_o[1])
       ,.O(qspi_data_i[1])
       ,.T(~qspi_out_mod_o[1])
       ,.IO(qspi_data_io[1])
      );
      
   IOBUF
   io_buf2
   (
        .I(qspi_data_o[2])
       ,.O(qspi_data_i[2])
       ,.T(~(&qspi_out_mod_o))
       ,.IO(qspi_data_io[2])
      );
      
   IOBUF
   io_buf3
   (
        .I(qspi_data_o[3])
       ,.O(qspi_data_i[3])
       ,.T(~(&qspi_out_mod_o))
       ,.IO(qspi_data_io[3])
   );

   `ifndef EXT_FLASH
   logic qspi_sck_o;
   STARTUPE2 #(
		.PROG_USR("FALSE"),
		.SIM_CCLK_FREQ(0.0)
	) STARTUPE2_inst (
	   .CFGCLK(),
	   .CFGMCLK(),
	   .EOS(),
	   .PREQ(),
	   .CLK(1'b0),
	   .GSR(1'b0),
	   .GTS(1'b0),
	   .KEYCLEARB(1'b0),
	   .PACK(1'b0),
	   .USRCCLKO(qspi_sck_o),
	   .USRCCLKTS(1'b0),
	   .USRDONEO(1'b1),
	   .USRDONETS(1'b1)
	);
   `endif
   `else
   assign qspi_data_io[0] = |qspi_out_mod_o   ? qspi_data_o[0] : 1'bZ;
   assign qspi_data_io[1] = qspi_out_mod_o[1] ? qspi_data_o[1] : 1'bZ;
   assign qspi_data_io[2] = &qspi_out_mod_o   ? qspi_data_o[2] : 1'bZ;
   assign qspi_data_io[3] = &qspi_out_mod_o   ? qspi_data_o[3] : 1'bZ;
   assign qspi_data_i = qspi_data_io;
   `endif

   qspi_controller_obi qspi (
      .clk_i         (clkwiz_o),
      .rst_ni        (rst_n),
      .req_i         (qspi_req),
      .we_i          (qspi_we),
      .be_i          (qspi_be),
      .addr_i        (qspi_addr),
      .wdata_i       (qspi_wdata),
      .gnt_o         (qspi_gnt),
      .rvalid_o      (qspi_rvalid),
      .rdata_o       (qspi_rdata),
      .qspi_data_i   (qspi_data_i),
      .qspi_data_o   (qspi_data_o),
      .qspi_out_mod_o(qspi_out_mod_o),
      .qspi_cs_n_o   (qspi_cs_n_o),
      .qspi_sck_o    (qspi_sck_o)
   );
   `endif

   `ifdef DRAM_SIM
   wire ddr3_reset_n;
   wire ddr3_cke;
   wire ddr3_ck_p;
   wire ddr3_ck_n;
   wire ddr3_cs_n;
   wire ddr3_ras_n;
   wire ddr3_cas_n;
   wire ddr3_we_n;
   wire [2:0] ddr3_ba;
   wire [13:0] ddr3_addr;
   wire ddr3_odt;
   wire [1:0] ddr3_dm;
   wire [1:0] ddr3_dqs_p;
   wire [1:0] ddr3_dqs_n;
   wire [15:0] ddr3_dq;

   //`define den1024Mb
   //`include "1024Mb_ddr3_parameters.vh"

   ddr3 ddr3_dut (
      .rst_n  (ddr3_reset_n),
      .ck     (ddr3_ck_p),
      .ck_n   (ddr3_ck_n),
      .cke    (ddr3_cke),
      .cs_n   (ddr3_cs_n),
      .ras_n  (ddr3_ras_n),
      .cas_n  (ddr3_cas_n),
      .we_n   (ddr3_we_n),
      .dm_tdqs(ddr3_dm),
      .ba     (ddr3_ba),
      .addr   (ddr3_addr),
      .dq     (ddr3_dq),
      .dqs    (ddr3_dqs_p),
      .dqs_n  (ddr3_dqs_n),
      .tdqs_n (),
      .odt    (ddr3_odt)
   );
   `endif

   `ifdef ZC706
   dram_controller_obi dram_dut (
      .clk_i   (clkwiz_o),
      .rst_ni  (rst_n),
      .req_i   (dram_req),
      .we_i    (dram_we),
      .be_i    (dram_be),
      .addr_i  (dram_addr),
      .wdata_i (dram_wdata),
      .gnt_o   (dram_gnt),
      .rvalid_o(dram_rvalid),
      .rdata_o (dram_rdata)

      ,.ddr3_reset_n(ddr3_reset_n)
      ,.ddr3_cke(ddr3_cke)
      ,.ddr3_ck_p(ddr3_ck_p)
      ,.ddr3_ck_n(ddr3_ck_n)
      ,.ddr3_cs_n(ddr3_cs_n)
      ,.ddr3_ras_n(ddr3_ras_n)
      ,.ddr3_cas_n(ddr3_cas_n)
      ,.ddr3_we_n(ddr3_we_n)
      ,.ddr3_ba(ddr3_ba)
      ,.ddr3_addr(ddr3_addr)
      ,.ddr3_odt(ddr3_odt)
      ,.ddr3_dm(ddr3_dm)
      ,.ddr3_dqs_p(ddr3_dqs_p)
      ,.ddr3_dqs_n(ddr3_dqs_n)
      ,.ddr3_dq(ddr3_dq)

      ,.clk100(clk100)
      ,.clk_ddr(clk_ddr)
      ,.clk_ref(clk_ref)
      ,.clk_ddr_dqs(clk_ddr_dqs)
   );
   `endif
`endif // END of CORE_CV32E40P or CORE_IBEX

endmodule
