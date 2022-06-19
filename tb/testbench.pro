library spi2axi

include TestHarness.pro

#RunTest tb_spi2axi_operation.vhd
#RunTest tb_spi2axi_overrun.vhd

analyze  tb_spi2axi_operation.vhd
simulate tb_spi2axi_operation "-GSPI_CPOL=0 -GSPI_CPHA=0"
simulate tb_spi2axi_operation "-GSPI_CPOL=0 -GSPI_CPHA=1"
simulate tb_spi2axi_operation "-GSPI_CPOL=1 -GSPI_CPHA=0"
simulate tb_spi2axi_operation "-GSPI_CPOL=1 -GSPI_CPHA=1"

analyze  tb_spi2axi_overrun.vhd
simulate tb_spi2axi_overrun "-GSPI_CPOL=0 -GSPI_CPHA=0"
simulate tb_spi2axi_overrun "-GSPI_CPOL=0 -GSPI_CPHA=1"
simulate tb_spi2axi_overrun "-GSPI_CPOL=1 -GSPI_CPHA=0"
simulate tb_spi2axi_overrun "-GSPI_CPOL=1 -GSPI_CPHA=1"
