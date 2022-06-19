TestSuite Spi2Axi

SetCoverageAnalyzeEnable true
SetCoverageSimulateEnable true

library spi2axi
analyze src/spi2axi.vhd

SetCoverageAnalyzeEnable false

include ./tb/testbench.pro

SetCoverageSimulateEnable false