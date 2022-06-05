-------------------------------------------------------------------------------
--  Synchronizer for clock-domain crossings.
--
--  This file is part of the noasic library.
--
--  Description:  
--    Synchronizes a single-bit signal from a source clock domain
--    to a destination clock domain using a chain of flip-flops (synchronizer
--    FF followed by one or more guard FFs).
--
--  Author(s):
--    Guy Eschemann, Guy.Eschemann@gmail.com
-------------------------------------------------------------------------------
-- Copyright (c) 2012-2022 Guy Eschemann
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
-------------------------------------------------------------------------------

library ieee;

use ieee.std_logic_1164.all;

entity synchronizer is
  generic(
    G_INIT_VALUE    : std_logic := '0'; -- initial value of all flip-flops in the module
    G_NUM_GUARD_FFS : positive  := 1);  -- number of guard flip-flops after the synchronizing flip-flop
  port(
    i_reset : in  std_logic;            -- asynchronous, high-active
    i_clk   : in  std_logic;            -- destination clock
    i_data  : in  std_logic;
    o_data  : out std_logic);
end synchronizer;

architecture RTL of synchronizer is

  -------------------------------------------------------------------------------
  -- Registered signals (with initial values):
  --
  signal s_data_sync_r  : std_logic                                      := G_INIT_VALUE;
  signal s_data_guard_r : std_logic_vector(G_NUM_GUARD_FFS - 1 downto 0) := (others => G_INIT_VALUE);

  -------------------------------------------------------------------------------
  -- Attributes
  --

  -- Synplify Pro: disable shift-register LUT (SRL) extraction
  attribute syn_srlstyle : string;
  attribute syn_srlstyle of s_data_sync_r : signal is "registers";
  attribute syn_srlstyle of s_data_guard_r : signal is "registers";

  -- Xilinx XST: disable shift-register LUT (SRL) extraction
  attribute shreg_extract : string;
  attribute shreg_extract of s_data_sync_r : signal is "no";
  attribute shreg_extract of s_data_guard_r : signal is "no";

  -- Disable X propagation during timing simulation. In the event of 
  -- a timing violation, the previous value is retained on the output instead 
  -- of going unknown (see Xilinx UG625)
  attribute ASYNC_REG : string;
  attribute ASYNC_REG of s_data_sync_r : signal is "TRUE";

begin

  -------------------------------------------------------------------------------
  -- Synchronizer process
  --
  p_synchronizer : process(i_clk, i_reset)
  begin
    if i_reset = '1' then
      s_data_sync_r  <= G_INIT_VALUE;
      s_data_guard_r <= (others => G_INIT_VALUE);

    elsif rising_edge(i_clk) then
      sync_ff : s_data_sync_r <= i_data;
      guard_ffs : if s_data_guard_r'length = 1 then
        s_data_guard_r(0) <= s_data_sync_r; -- avoid "Range is empty (null range)" warnings:
      else
        s_data_guard_r <= s_data_guard_r(s_data_guard_r'high - 1 downto 0) & s_data_sync_r;
      end if;
    end if;
  end process;

  -------------------------------------------------------------------------------
  -- Outputs
  --
  o_data <= s_data_guard_r(s_data_guard_r'high);

end RTL;
