//--------------------------------------------------------------------------------------------------
//
//  SPI to AXI4-Lite Bridge
//
//  Description:  
//    An SPI to AXI4-Lite Bridge to allow accessing AXI4-Lite register banks 
//    over SPI. See https://airhdl.com for a popular, web-based AXI4 register 
//    generator.
//
//  Author(s):
//    Guy Eschemann, guy@airhdl.com
//
//--------------------------------------------------------------------------------------------------
//
// Copyright (c) 2022 Guy Eschemann
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//     http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
//--------------------------------------------------------------------------------------------------

`default_nettype none

module spi2axi #( // @suppress "File contains multiple design units"
    parameter SPI_CPOL       = 0, // SPI clock polarity
    parameter SPI_CPHA       = 0, // SPI clock phase
    parameter AXI_ADDR_WIDTH = 32 // AXI address bus width, in bits
) (
    // SPI interface
    input wire spi_sck, // SPI clock
    input wire spi_ss_n, // SPI slave select (low active)
    input wire spi_mosi, // SPI master-out-slave-in
    output wire spi_miso, // SPI master-in-slave-out
    // Clock and Reset
    input wire axi_aclk,
    input wire axi_aresetn,
    // AXI Write Address Channel
    output wire [AXI_ADDR_WIDTH - 1:0] s_axi_awaddr,
    output wire [2:0] s_axi_awprot, // sigasi @suppress "Unused port"
    output wire s_axi_awvalid,
    input wire s_axi_awready,
    // AXI Write Data Channel
    output wire [31:0] s_axi_wdata,
    output wire [3:0] s_axi_wstrb,
    output wire s_axi_wvalid,
    input wire s_axi_wready,
    // AXI Read Address Channel
    output wire [AXI_ADDR_WIDTH - 1:0] s_axi_araddr,
    output wire [2:0] s_axi_arprot, // sigasi @suppress "Unused port"
    output wire s_axi_arvalid,
    input wire s_axi_arready,
    // AXI Read Data Channel
    input wire [31:0] s_axi_rdata,
    input wire [1:0] s_axi_rresp,
    input wire s_axi_rvalid,
    output wire s_axi_rready,
    // AXI Write Response Channel
    input wire [1:0] s_axi_bresp,
    input wire s_axi_bvalid,
    output wire s_axi_bready
);

    //----------------------------------------------------------------------------------------------
    // Constants
    //----------------------------------------------------------------------------------------------

    localparam logic[7:0] CMD_WRITE  = 8'h00;
    localparam logic[7:0] CMD_READ = 8'h01;
    localparam int SPI_FRAME_LENGTH_BYTES = 11;


    //----------------------------------------------------------------------------------------------
    // Types
    //----------------------------------------------------------------------------------------------

    typedef enum {
        SPI_RECEIVE, SPI_PROCESS_RX_BYTE, SPI_LOAD_TX_BYTE
    } spi_state_t;

    typedef enum {
        AXI_IDLE, AXI_WRITE_ACK, AXI_WRITE_BRESP, AXI_READ_ADDR_ACK, AXI_READ_DATA
    } axi_state_t;

    //----------------------------------------------------------------------------------------------
    // Signals
    //----------------------------------------------------------------------------------------------

    // Registered signals with initial values
    spi_state_t spi_state = SPI_RECEIVE;
    axi_state_t axi_state = AXI_IDLE;
    logic spi_sck_sync_old = SPI_CPOL;
    logic [7:0] spi_rx_shreg = '0;
    logic [7:0] spi_tx_shreg = '0;
    logic axi_bresp_valid = 1'b0;
    logic [1:0] axi_bresp = '0;
    logic [1:0] axi_rresp = '0;
    logic axi_rdata_valid = 1'b0;
    logic [31:0]axi_rdata = '0;
    logic [7:0]spi_rx_cmd =  '0;
    logic [31:0]spi_rx_addr = '0;
    logic [31:0]spi_rx_wdata = '0;
    logic spi_rx_valid = 1'b0;
    logic s_axi_awvalid_int = 1'b0;
    logic s_axi_wvalid_int = 1'b0;
    logic axi_fsm_reset = 1'b1;
    logic [AXI_ADDR_WIDTH - 1:0] s_axi_awaddr_int = '0;
    logic [2:0] s_axi_awprot_int = '0;
    logic [31:0] s_axi_wdata_int = '0;
    logic [3:0] s_axi_wstrb_int = '0;
    logic [AXI_ADDR_WIDTH - 1:0] s_axi_araddr_int = '0;
    logic [2:0] s_axi_arprot_int = '0;
    logic s_axi_arvalid_int = 1'b0;
    logic s_axi_rready_int  = 1'b0;
    logic s_axi_bready_int = 1'b0;

    // Unregistered signals
    logic  spi_sck_sync;
    logic  spi_ss_n_sync;
    logic  axi_areset;

    //----------------------------------------------------------------------------------------------

    assign axi_areset = ~axi_aresetn;

    //----------------------------------------------------------------------------------------------
    // SPI SCK synchronizer
    //----------------------------------------------------------------------------------------------

    synchronizer
    # (
    .G_INIT_VALUE(SPI_CPOL),
    .G_NUM_GUARD_FFS(1)
    )
    spi_sck_sync_inst (
        .i_reset(axi_areset),
        .i_clk  (axi_aclk),
        .i_data (spi_sck),
        .o_data (spi_sck_sync)
    );

    synchronizer
    # (
    .G_INIT_VALUE(SPI_CPOL),
    .G_NUM_GUARD_FFS(1)
    )
    spi_ss_sync_inst(
        .i_reset (axi_areset),
        .i_clk   (axi_aclk),
        .i_data  (spi_ss_n),
        .o_data  (spi_ss_n_sync)
    );

    //----------------------------------------------------------------------------------------------
    // SPI receive/transmit state machine
    //----------------------------------------------------------------------------------------------

    always_ff@(posedge axi_aclk) begin: spi_fsm
        logic [2:0] spi_rx_bit_idx = 0;
        logic [$clog2(SPI_FRAME_LENGTH_BYTES):0] spi_rx_byte_idx = 0;
        logic [2:0] spi_tx_bit_idx = 0;
        logic [$clog2(SPI_FRAME_LENGTH_BYTES):0] spi_tx_byte_idx = 0;
        logic spi_sck_re;
        logic spi_sck_fe;
        logic [2:0] spi_tx_byte;

        if (~axi_aresetn) begin
            spi_rx_bit_idx   = 0;
            spi_rx_byte_idx  = 0;
            spi_tx_bit_idx   = 0;
            spi_tx_byte_idx  = 0;
            spi_tx_byte      = '0;
            spi_sck_sync_old <= SPI_CPOL;
            spi_rx_valid     <= 1'b0;
            spi_rx_cmd       <= '0;
            spi_rx_addr      <= '0;
            spi_rx_wdata     <= '0;
            spi_rx_shreg     <= '0;
            spi_tx_shreg     <= '0;
            axi_fsm_reset    <= 1'b1;
            spi_state        <= SPI_RECEIVE;
        end else begin
            // defaults:
            spi_rx_valid     <= 1'b0;
            spi_sck_sync_old <= spi_sck_sync;

            case (spi_state) // @suppress "Default clause missing from case statement"

                //----------------------------------------------------------------------------------
                // Receive the 11-byte SPI frame
                //  * SPI bytes are received MSB-first
                //----------------------------------------------------------------------------------
                SPI_RECEIVE : begin
                    if (spi_ss_n_sync == 1'b0) begin
                        axi_fsm_reset <= 1'b0;

                        spi_sck_re = (spi_sck_sync == 1'b1 && spi_sck_sync_old == 1'b0);
                        spi_sck_fe = (spi_sck_sync == 1'b0 && spi_sck_sync_old == 1'b1);

                        // SPI clock sample edge
                        if ((SPI_CPOL == 0 && SPI_CPHA == 0 && spi_sck_re) ||
                        (SPI_CPOL == 0 && SPI_CPHA == 1 && spi_sck_fe) ||
                        (SPI_CPOL == 1 && SPI_CPHA == 0 && spi_sck_fe) ||
                        (SPI_CPOL == 1 && SPI_CPHA == 1 && spi_sck_re)) begin
                            spi_rx_shreg <= { spi_rx_shreg[$bits(spi_rx_shreg) - 2 : 0], spi_mosi }; // assuming `spi_mosi` is steady and does not need a synchronizer
                            //
                            if (spi_rx_bit_idx == 7) begin
                                spi_rx_bit_idx = 0;
                                //
                                if (spi_rx_byte_idx < SPI_FRAME_LENGTH_BYTES) begin // in case of SPI overrun, stop processing receive bytes
                                    spi_state <= SPI_PROCESS_RX_BYTE;
                                end
                            end else begin
                                spi_rx_bit_idx = spi_rx_bit_idx + 1;
                            end

                            // SPI clock drive edge
                        end else if ((SPI_CPOL == 0 && SPI_CPHA == 0 && spi_sck_fe) ||
                        (SPI_CPOL == 0 && SPI_CPHA == 1 && spi_sck_re) ||
                        (SPI_CPOL == 1 && SPI_CPHA == 0 && spi_sck_re) ||
                        (SPI_CPOL == 1 && SPI_CPHA == 1 && spi_sck_fe)) begin
                            if (SPI_CPHA == 1 && spi_tx_bit_idx == 0) begin
                                spi_tx_shreg   <= spi_tx_byte;
                                spi_tx_bit_idx = spi_tx_bit_idx + 1;
                            end else begin
                                spi_tx_shreg <= { spi_tx_shreg[$bits(spi_tx_shreg) - 2 : 0], 1'b0 };
                                //
                                if (spi_tx_bit_idx == 7) begin
                                    spi_tx_bit_idx = 0;
                                    //
                                    if (spi_tx_byte_idx < SPI_FRAME_LENGTH_BYTES - 1) begin // in case of SPI overrun, stop loading transmit bytes
                                        spi_tx_byte_idx = spi_tx_byte_idx + 1;
                                        spi_state       <= SPI_LOAD_TX_BYTE;
                                    end
                                end else begin
                                    spi_tx_bit_idx = spi_tx_bit_idx + 1;
                                end
                            end
                        end
                    end else begin
                        spi_rx_bit_idx  = 0;
                        spi_rx_byte_idx = 0;
                        spi_tx_bit_idx  = 0;
                        spi_tx_byte_idx = 0;
                        spi_tx_byte     = '0;
                        axi_fsm_reset   <= 1'b1;
                    end
                end

                //----------------------------------------------------------------------------------
                // Process the last received SPI byte
                //----------------------------------------------------------------------------------

                SPI_PROCESS_RX_BYTE : begin
                    if (spi_rx_byte_idx == 0) begin
                        spi_rx_cmd <= spi_rx_shreg;
                    end else begin
                        if (spi_rx_cmd == CMD_WRITE) begin
                            if (spi_rx_byte_idx <= 4) begin
                                spi_rx_addr <= spi_rx_addr[23:0] & spi_rx_shreg;
                            end else if (spi_rx_byte_idx <= 8) begin
                                spi_rx_wdata <= spi_rx_wdata[23:0] & spi_rx_shreg;
                                //
                                if (spi_rx_byte_idx == 8) begin
                                    // Write data complete -> trigger the AXI write access 
                                    spi_rx_valid <= 1'b1;
                                end
                            end else begin
                                // null; // don't care
                            end
                        end else begin // CMD_READ
                            assert(spi_rx_cmd == CMD_READ);
                            if (spi_rx_byte_idx <= 4) begin
                                spi_rx_addr <= { spi_rx_addr[23:0], spi_rx_shreg };
                                //
                                if (spi_rx_byte_idx == 4) begin
                                    // Read address complete -> trigger the AXI read access 
                                    spi_rx_valid <= 1'b1;
                                end
                            end else begin
                                // null; // don't care
                            end
                        end
                    end
                    //
                    spi_rx_byte_idx = spi_rx_byte_idx + 1;
                    spi_state       <= SPI_RECEIVE;
                end

                //----------------------------------------------------------------------------------
                // Load the next SPI transmit byte
                //----------------------------------------------------------------------------------

                SPI_LOAD_TX_BYTE: begin
                    spi_tx_byte = '0; // default
                    //
                    if (spi_rx_cmd == CMD_WRITE) begin
                        if (spi_tx_byte_idx == 10) begin
                            // Write status byte:
                            // [7:3] reserved
                            // [2]   timeout
                            // [1:0] BRESP                                
                            spi_tx_byte      = '0;
                            spi_tx_byte[2]   = ~axi_bresp_valid;
                            spi_tx_byte[1:0] = axi_bresp;
                        end
                    end else begin // CMD_READ
                        if (spi_tx_byte_idx <= 5) begin
                            // null;
                        end else if (spi_tx_byte_idx == 6) begin
                            spi_tx_byte = axi_rdata[31:24];
                        end else if (spi_tx_byte_idx == 7) begin
                            spi_tx_byte = axi_rdata[23:16];
                        end else if (spi_tx_byte_idx == 8) begin
                            spi_tx_byte = axi_rdata[15:8];
                        end else if (spi_tx_byte_idx == 9) begin
                            spi_tx_byte = axi_rdata[7:0];
                        end else begin
                            // Read status byte:
                            // [7:3] reserved
                            // [2]   timeout
                            // [1:0] RRESP
                            spi_tx_byte      = '0;;
                            spi_tx_byte[2]   = ~axi_rdata_valid;
                            spi_tx_byte[1:0] = axi_rresp;
                        end
                    end
                    //
                    if (SPI_CPHA == 0) begin
                        spi_tx_shreg <= spi_tx_byte;
                    end
                    //
                    spi_state <= SPI_RECEIVE;
                end
            endcase
        end
    end: spi_fsm

    assign spi_miso = spi_tx_shreg[$bits(spi_tx_shreg)-1];

    //----------------------------------------------------------------------------------------------
    // AXI4 receive/transmit state machine
    //----------------------------------------------------------------------------------------------

    always_ff@(posedge axi_aclk) begin: axi_fsm
        if (~axi_aresetn || axi_fsm_reset) begin
            s_axi_awvalid_int <= 1'b0;
            s_axi_awprot_int      <= '0;
            s_axi_awaddr_int      <= '0;
            s_axi_arvalid_int     <= 1'b0;
            s_axi_arprot_int      <= '0;
            s_axi_araddr_int      <= '0;
            s_axi_wvalid_int  <= 1'b0;
            s_axi_wstrb_int       <= '0;
            s_axi_wdata_int       <= '0;
            s_axi_bready_int      <= 1'b0;
            s_axi_rready_int      <= 1'b0;
            axi_bresp_valid   <= 1'b0;
            axi_bresp         <= '0;
            axi_rresp         <= '0;
            axi_rdata_valid   <= 1'b0;
            axi_rdata         <= '0;
            axi_state         <= AXI_IDLE;
        end else begin
            case (axi_state)
                //------------------------------------------------------------------------------
                // Idle
                //------------------------------------------------------------------------------
                AXI_IDLE : begin
                    if (spi_rx_valid == 1'b1) begin
                        axi_bresp_valid <= 1'b0;
                        axi_rdata_valid <= 1'b0;
                        //
                        if (spi_rx_cmd == CMD_WRITE) begin
                            s_axi_awvalid_int         <= 1'b1;
                            s_axi_awaddr_int              <= '0;
                            s_axi_awaddr_int[31:0] <= spi_rx_addr;
                            s_axi_awprot_int              <= '0; // unpriviledged, secure data access
                            s_axi_wvalid_int          <= 1'b1;
                            s_axi_wdata_int               <= spi_rx_wdata;
                            s_axi_wstrb_int               <= '1;
                            axi_state                 <= AXI_WRITE_ACK;
                        end else begin
                            s_axi_arvalid_int             <= 1'b1;
                            s_axi_araddr_int              <= '0;
                            s_axi_araddr_int[31:0] <= spi_rx_addr;
                            s_axi_arprot_int              <= '0; // unpriviledged, secure data access
                            axi_state                 <= AXI_READ_ADDR_ACK;
                        end
                    end
                end

                //------------------------------------------------------------------------------
                // AXI write: wait for write address and data acknowledge
                //------------------------------------------------------------------------------
                AXI_WRITE_ACK : begin
                    if (s_axi_awready == 1'b1) begin
                        s_axi_awvalid_int <= 1'b0;
                        //
                        if (s_axi_wvalid_int == 1'b0) begin
                            s_axi_bready_int <= 1'b1;
                            axi_state    <= AXI_WRITE_BRESP; // move on when both write address and data have been acknowledged
                        end
                    end
                    //
                    if (s_axi_wready == 1'b1) begin
                        s_axi_wvalid_int <= 1'b0;
                        s_axi_wstrb_int      <= '0;
                        //
                        if (s_axi_awvalid_int == 1'b0) begin
                            s_axi_bready_int <= 1'b1;
                            axi_state    <= AXI_WRITE_BRESP; // move on when both write address and data have been acknowledged
                        end
                    end
                end

                //------------------------------------------------------------------------------
                // AXI write: wait for write response
                //------------------------------------------------------------------------------
                AXI_WRITE_BRESP : begin
                    if (s_axi_bvalid == 1'b1) begin
                        s_axi_bready_int    <= 1'b0;
                        axi_bresp_valid <= 1'b1;
                        axi_bresp       <= s_axi_bresp;
                        axi_state       <= AXI_IDLE;
                    end
                end

                //------------------------------------------------------------------------------
                // AXI read: wait for read address acknowledge
                //------------------------------------------------------------------------------
                AXI_READ_ADDR_ACK : begin
                    if (s_axi_arready == 1'b1) begin
                        s_axi_arvalid_int <= 1'b0;
                        s_axi_rready_int  <= 1'b1;
                        axi_state     <= AXI_READ_DATA;
                    end
                end

                //------------------------------------------------------------------------------
                // AXI read: wait for read data
                //------------------------------------------------------------------------------
                AXI_READ_DATA : begin
                    if (s_axi_rvalid == 1'b1) begin
                        s_axi_rready_int    <= 1'b0;
                        axi_rdata_valid <= 1'b1;
                        axi_rdata       <= s_axi_rdata;
                        axi_rresp       <= s_axi_rresp;
                        axi_state       <= AXI_IDLE;
                    end
                end
            endcase
        end
    end: axi_fsm

    assign s_axi_awvalid = s_axi_awvalid_int;
    assign s_axi_awprot  = s_axi_awprot_int ;
    assign s_axi_awaddr  = s_axi_awaddr_int ;
    assign s_axi_arvalid = s_axi_arvalid_int;
    assign s_axi_arprot  = s_axi_arprot_int ;
    assign s_axi_araddr  = s_axi_araddr_int ;
    assign s_axi_wvalid  = s_axi_wvalid_int ;
    assign s_axi_wstrb   = s_axi_wstrb_int  ;
    assign s_axi_wdata   = s_axi_wdata_int  ;
    assign s_axi_bready  = s_axi_bready_int ;
    assign s_axi_rready  = s_axi_rready_int ;

endmodule: spi2axi

//--------------------------------------------------------------------------------------------------
//
//  Synchronizer for clock-domain crossings.
//
//  This file is part of the noasic library.
//
//  Description:  
//    Synchronizes a single-bit signal from a source clock domain
//    to a destination clock domain using a chain of flip-flops (synchronizer
//    FF followed by one or more guard FFs).
//
//  Author(s):
//    Guy Eschemann, Guy.Eschemann@gmail.com
//
//--------------------------------------------------------------------------------------------------
//
// Copyright (c) 2012-2022 Guy Eschemann
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//     http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
//--------------------------------------------------------------------------------------------------

module synchronizer #(
    parameter G_INIT_VALUE    = 0, // initial value of all flip-flops in the module
    parameter G_NUM_GUARD_FFS = 1 // number of guard flip-flops after the synchronizing flip-flop
) (
    input wire i_reset,
    input wire i_clk,
    input wire i_data,
    output wire o_data
);

    //-----------------------------------------------------------------------------
    // Registered signals (with initial values):
    //
    logic s_data_sync_r  = G_INIT_VALUE;
    logic [G_NUM_GUARD_FFS-1:0] s_data_guard_r = {G_NUM_GUARD_FFS{G_INIT_VALUE}};

    //-----------------------------------------------------------------------------
    // Synchronizer process
    //
    always_ff@(posedge i_clk or posedge i_reset) begin: p_synchronizer
        if (i_reset == 1'b1) begin
            s_data_sync_r  <= G_INIT_VALUE;
            s_data_guard_r <= {G_NUM_GUARD_FFS{G_INIT_VALUE}};

        end else begin
            sync_ff : s_data_sync_r <= i_data;
            guard_ffs : if ($bits(s_data_guard_r) == 1) begin
                s_data_guard_r[0] <= s_data_sync_r; // avoid "Range is empty (null range)" warnings:
            end else begin
                s_data_guard_r <= { s_data_guard_r[$bits(s_data_guard_r) - 2 : 0], s_data_sync_r};
            end
        end
    end: p_synchronizer

    //-----------------------------------------------------------------------------
    // Outputs
    //
    assign o_data = s_data_guard_r[$bits(s_data_guard_r)-1];

endmodule : synchronizer

`resetall
