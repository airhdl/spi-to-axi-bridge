# SPI to AXI4-Lite Bridge

An SPI to AXI4-lite bridge for interfacing `airhdl` register maps to SPI.

## SPI Modes

The SPI to AXI4-Lite bridge supports different SPI modes, as defined in the table below.

| Mode | Clock polarity (CPOL) | Clock Phase (CPHA) | Description |
| -----| --------------------- | ------------------ | ----------- |
| 0    | 0 | 0 | Idle clock level is `0`, data captured on leading (rising) clock edge. |
| 1    | 0 | 1 | Idle clock level is `0`, data captured on trailing (falling) clock edge |
| 2    | 1 | 0 | Idle clock level is `1`, data captured on leading (falling) clock edge. |
| 3    | 1 | 1 | Idle clock level is `0`, data captured on leading (falling) clock edge. |

The SPI mode is configured statically using the component's `SPI_MODE` generic parameter.

## SPI Transactions

### Write Data Transactions

Write transactions write a 32-bit data word to an AXI4-Lite register at a given address. SPI write transactions have a total length of 11 bytes. The first byte, which is the `instruction` byte, must have a value of `0x00` to initiate a write transaction. It is followed by the 4 address bytes and the 4 data bytes which are all transmitted high-byte first.

| Byte | MOSI    | MISO | Comment |
| ---- | ------- | ---- | ------- |
| 0    | `0x00` | `0x00` | Signals a write transaction |
| 1    | `address[7:0]` | `0x00` | Write address |
| 2    | `address[15:8]` | `0x00` | Write address |
| 3    | `address[23:16]` | `0x00` | Write address |
| 4    | `address[31:24]` | `0x00` | Write address |
| 5    | `wr_data[7:0]` | `0x00` | Write data |
| 6    | `wr_data[15:8]` | `0x00` | Write data |
| 7    | `wr_data[23:16]` | `0x00` | Write data |
| 8    | `wr_data[31:24]` | `0x00` | Write data |
| 9    | `don't care` | `0x00` | A dummy byte to allow writing the data word |
| 10    | `don't care` | `wr_resp` | `[1:0] BRESP` (AXI4 write response) |

### Read Data Transactions

Read transactions read a 32-bit data word from an AXI4-Lite register at a given address. SPI read transactions have a total length of 11 bytes. The first byte, which is the `instruction` byte, must have a value of `0x01` to initiate a read transaction. It is followed by the 4 address bytes, plus a `dummy` byte which gives time to the bridge to perform the AXI4-Lite read transaction. The read data word appears on the `MISO` line following the transmission of the `dummy` byte.

| Byte | MOSI    | MISO | Comment |
| ---- | ------- | ---- | ------- |
| 0    | `0x01` | `0x00` | Signals a read transaction |
| 1    | `address[7:0]` | `0x00` | Read address |
| 2    | `address[15:8]` | `0x00` | Read address |
| 3    | `address[23:16]` | `0x00` | Read address |
| 4    | `address[31:24]` | `0x00` | Read address |
| 5    | `don't care` | `0x00` | A dummy byte to allow fetching the read data word |
| 6    | `don't care` | `rd_resp` | `[1:0] RRESP` AXI4 read response |
| 7    | `don't care` | `rd_data[7:0]` | Read data|
| 8    | `don't care` | `rd_data[15:8]` | Read data|
| 9    | `don't care` | `rd_data[23:16]` | Read data|
| 10   | `don't care` | `rd_data[31:24]` | Read data |
