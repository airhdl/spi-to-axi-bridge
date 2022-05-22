# SPI to AXI4-Lite Bridge

An SPI to AXI4-lite bridge for interfacing `airhdl` register maps to SPI.

## SPI Modes

The SPI to AXI4-Lite bridge supports all combinations of clock polarities and clock phases, as defined in the table below.

| Clock polarity (CPOL) | Clock Phase (CPHA) | Description |
| --------------------- | ------------------ | ----------- |
| 0 | 0 | Idle clock level is `0`, data captured on leading (rising) clock edge. |
| 0 | 1 | Idle clock level is `0`, data captured on trailing (falling) clock edge |
| 1 | 0 | Idle clock level is `1`, data captured on leading (falling) clock edge. |
| 1 | 1 | Idle clock level is `0`, data captured on leading (falling) clock edge. |

The values for the `CPOL` and `CPHA` parameters are configured statically using the component's generic parameters.

## SPI Transactions

### Write Data Transactions

Write transactions write a 32-bit data word to an AXI4-Lite register at a given address. SPI write transactions have a total length of 9 bytes. The first byte, which is the `instruction` byte, must have a value of `0x00` to initiate a write transaction. It is followed by the 4 address bytes and the 4 data bytes which are all transmitted high-byte first.

| Byte | MOSI    | MISO | Comment |
| ---- | ------- | ---- | ------- |
| 0    | `instruction` | `-` | Set to `0x00` for a write transaction |
| 1    | `address[31:24]` | `-` | Write address |
| 2    | `address[23:16]` | `-` | Write address |
| 3    | `address[15:8]` | `-` | Write address |
| 4    | `address[7:0]` | `-` | Write address |
| 5    | `wr_data[31:24]` | `-` | Write data |
| 6    | `wr_data[23:16]` | `-` | Write data |
| 7    | `wr_data[15:8]` | `-` | Write data |
| 8    | `wr_data[7:0]` | `-` | Write data |

### Read Data Transactions

Read transactions read a 32-bit data word from an AXI4-Lite register at a given address. SPI read transactions have a total length of 10 bytes. The first byte, which is the `instruction` byte, must have a value of `0x01` to initiate a read transaction. It is followed by the 4 address bytes, plus a `dummy` byte which gives time to the bridge to perform the AXI4-Lite read transaction. The read data word appears on the `MISO` line following the transmission of the `dummy` byte.

| Byte | MOSI    | MISO | Comment |
| ---- | ------- | ---- | ------- |
| 0    | `instruction` | `-` | Set to `0x01` for a read transaction |
| 1    | `address[31:24]` | `-` | Read address |
| 2    | `address[23:16]` | `-` | Read address |
| 3    | `address[15:8]` | `-` | Read address |
| 4    | `address[7:0]` | `-` | Read address |
| 5    | `dummy` | `-` | a dummy byte to allow fetching the read data word |
| 6    | `-` | `rd_data[31:24]` | Read data |
| 7    | `-` | `rd_data[23:16]` | Read data|
| 8    | `-` | `rd_data[15:8]` | Read data|
| 9    | `-` | `rd_data[7:0]` | Read data|
