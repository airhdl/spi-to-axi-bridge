library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity spi2axi is
  generic (
    AXI_ADDR_WIDTH : integer := 32; -- width of the AXI address bus
  )
  port (
    -- Clock and Reset
    axi_aclk : in std_logic;
    axi_aresetn : in std_logic;
    -- SPI interface
    spi_clk : in std_logic;
    spi_mosi : in std_logic;
    spi_miso : out std_logic;
    -- AXI Write Address Channel
    s_axi_awaddr : out std_logic_vector(AXI_ADDR_WIDTH - 1 downto 0);
    s_axi_awprot : out std_logic_vector(2 downto 0); -- sigasi @suppress "Unused port"
    s_axi_awvalid : out std_logic;
    s_axi_awready : in std_logic;
    -- AXI Write Data Channel
    s_axi_wdata : out std_logic_vector(31 downto 0);
    s_axi_wstrb : out std_logic_vector(3 downto 0);
    s_axi_wvalid : out std_logic;
    s_axi_wready : in std_logic;
    -- AXI Read Address Channel
    s_axi_araddr : out std_logic_vector(AXI_ADDR_WIDTH - 1 downto 0);
    s_axi_arprot : out std_logic_vector(2 downto 0); -- sigasi @suppress "Unused port"
    s_axi_arvalid : out std_logic;
    s_axi_arready : in std_logic;
    -- AXI Read Data Channel
    s_axi_rdata : in std_logic_vector(31 downto 0);
    s_axi_rresp : in std_logic_vector(1 downto 0);
    s_axi_rvalid : in std_logic;
    s_axi_rready : out std_logic;
    -- AXI Write Response Channel
    s_axi_bresp : in std_logic_vector(1 downto 0);
    s_axi_bvalid : in std_logic;
    s_axi_bready : out std_logic;
  );
end entity;

architecture rtl of spi2axi is

begin

end architecture;