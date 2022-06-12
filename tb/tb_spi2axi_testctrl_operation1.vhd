-------------------------------------------------------------------------------
--
--  SPI to AXI4-Lite Bridge, test controller entity declaration 
--
--  Description:  
--    TODO 
--
--  Author(s):
--    Guy Eschemann, guy@airhdl.com
--
-------------------------------------------------------------------------------
--
-- Copyright (c) 2022 Guy Eschemann
-- 
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
-- 
--     http://www.apache.org/licenses/LICENSE-2.0
-- 
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library OSVVM;
context OSVVM.OsvvmContext;
use osvvm.ScoreboardPkg_slv.all;

architecture operation1 of tb_spi2axi_testctrl is

    -------------------------------------------------------------------------------
    -- Signals
    -------------------------------------------------------------------------------

    signal TestDone : integer_barrier := 1;

    -------------------------------------------------------------------------------
    -- Aliases
    -------------------------------------------------------------------------------

    alias TxBurstFifo : ScoreboardIdType is SpiRec.BurstFifo;

begin

    ------------------------------------------------------------
    -- ControlProc
    --   Set up AlertLog and wait for end of test
    ------------------------------------------------------------
    ControlProc : process
        variable addr            : unsigned(31 downto 0);
        variable wdata           : unsigned(31 downto 0);
        variable rdata           : unsigned(31 downto 0);
        variable value           : natural;
        variable spi_tx_bytes    : integer_vector(0 to 10);
        variable spi_tx_byte_idx : natural;
    begin
        -- Initialization of test
        SetAlertLogName("tb_spi2axi_operation1");
        SetLogEnable(INFO, TRUE);
        SetLogEnable(DEBUG, TRUE);
        SetLogEnable(PASSED, TRUE);     -- Enable PASSED logs

        -- Wait for testbench initialization 
        wait for 0 ns;
        wait for 0 ns;
        --TranscriptOpen(OSVVM_RESULTS_DIR & "tb_spi2axi_operation1.txt");

        -- Wait for Design Reset
        wait until nReset = '1';
        ClearAlerts;

        Log("Send SPI data...");
        spi_tx_byte_idx               := 0;
        spi_tx_bytes(spi_tx_byte_idx) := 0; -- 0x00 -> SPI write
        spi_tx_byte_idx               := spi_tx_byte_idx + 1;
        addr                          := x"76543210";
        wdata                         := x"12345678";
        for i in 3 downto 0 loop
            spi_tx_bytes(spi_tx_byte_idx) := to_integer(addr(i * 8 + 7 downto i * 8));
            spi_tx_byte_idx               := spi_tx_byte_idx + 1;
        end loop;
        for i in 3 downto 0 loop
            spi_tx_bytes(spi_tx_byte_idx) := to_integer(wdata(i * 8 + 7 downto i * 8));
            spi_tx_byte_idx               := spi_tx_byte_idx + 1;
        end loop;
        spi_tx_bytes(spi_tx_byte_idx) := 0; -- a dummy byte to allow writing the data word
        spi_tx_byte_idx               := spi_tx_byte_idx + 1;
        spi_tx_bytes(spi_tx_byte_idx) := 0; -- AXI4 write response
        spi_tx_byte_idx               := spi_tx_byte_idx + 1;
        PushBurst(TxBurstFifo, spi_tx_bytes, 8); -- AXI4 write response
        SendBurst(SpiRec, spi_tx_byte_idx);

        -- Wait for test to finish
        WaitForBarrier(TestDone, 10 ms);
        AlertIf(now >= 10 ms, "Test finished due to timeout");
        AlertIf(GetAffirmCount < 1, "Test is not Self-Checking");

        TranscriptClose;

        EndOfTestReports(ExternalErrors => (FAILURE => 0, ERROR => -15, WARNING => 0));
        std.env.stop(SumAlertCount(GetAlertCount + (FAILURE => 0, ERROR => -15, WARNING => 0)));
        wait;
    end process ControlProc;

end architecture operation1;

Configuration operation1_cfg of tb_spi2axi is
    for TestHarness
        for testctrl_inst : tb_spi2axi_testctrl
            use entity work.tb_spi2axi_testctrl(operation1);
        end for;
    end for;
end operation1_cfg;
