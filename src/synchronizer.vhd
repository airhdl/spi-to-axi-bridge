-------------------------------------------------------------------------------
--
--  Synchronizer for clock-domain crossings.
--
--  This file is part of the noasic library.
--
--  Description:  
--    Synchronizes a single-bit signal from a source clock domain
--    to a destination clock domain using a chain of flip-flops (synchronizer
--    FF followed by one or more guard FFs).
--
--  See also:
--    * http://noasic.com/blog/how-not-to-design-a-2dff-synchronizer/
--
--  Author(s):
--    Guy Eschemann, Guy.Eschemann@gmail.com
--
-------------------------------------------------------------------------------
--
--  Copyright (c) 2012 Guy Eschemann
--
--  This source file may be used and distributed without restriction provided
--  that this copyright statement is not removed from the file and that any
--  derivative work contains the original copyright notice and the associated
--  disclaimer.
--
--  This source file is free software: you can redistribute it and/or modify it
--  under the terms of the GNU Lesser General Public License as published by
--  the Free Software Foundation, either version 3 of the License, or (at your
--  option) any later version.
--
--  This source file is distributed in the hope that it will be useful, but
--  WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
--  or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
--  for more details.
--
--  You should have received a copy of the GNU Lesser General Public License
--  along with the noasic library.  If not, see http://www.gnu.org/licenses
--
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
