TestSuite Spi2Axi

SetCoverageSimulateEnable true

library spi2axi
SetCoverageAnalyzeEnable true
analyze src/spi2axi.vhd
SetCoverageAnalyzeEnable false

include ./tb/testbench.pro

SetCoverageSimulateEnable false
