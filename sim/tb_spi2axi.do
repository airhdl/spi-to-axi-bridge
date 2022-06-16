source ../../OsvvmLibraries/Scripts/StartUp.tcl
build ../../OsvvmLibraries/OsvvmLibraries.pro
build ../../OsvvmLibraries/SPI/SPI.pro
build ./tb_spi2axi.pro

vsim -GSPI_CPOL=0 -GSPI_CPHA=0 spi2axi.tb_spi2axi
run -all
 
vsim -GSPI_CPOL=0 -GSPI_CPHA=1 spi2axi.tb_spi2axi
run -all

vsim -GSPI_CPOL=1 -GSPI_CPHA=0 spi2axi.tb_spi2axi
run -all
 
vsim -GSPI_CPOL=1 -GSPI_CPHA=1 spi2axi.tb_spi2axi
run -all
