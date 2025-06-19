//==================================================================================================================================================================================================================//
//  SPI Slave                                                                                                                                                                                                      //
//  Author:Praveen Saravanan                                                                                                                                                                                        //
//==================================================================================================================================================================================================================//
module spi_slave #(
    parameter DATA_WIDTH = 8
)(
    input  logic        sclk,
    input  logic        mosi,
    input  logic        cs_n,     // RENAMED: cs_n to show it's active LOW
    output logic        miso,
    // Optional: parallel interface for more realistic slave
    input  logic [DATA_WIDTH-1:0] tx_data,
    output logic [DATA_WIDTH-1:0] rx_data,
    output logic        rx_valid
);

    logic [DATA_WIDTH-1:0] shift_reg_tx, shift_reg_rx;
    logic [$clog2(DATA_WIDTH):0] bit_cnt;
    logic transfer_active;
    
    assign transfer_active = ~cs_n;  // Active when CS is LOW
    
    // FIXED: Reset when CS goes HIGH, operate when CS is LOW
    always_ff @(posedge sclk or posedge cs_n) begin
        if (cs_n) begin  // Reset when CS inactive (HIGH)
            bit_cnt <= 0;
            shift_reg_tx <= tx_data;  // Load data to send
            shift_reg_rx <= 0;
            rx_valid <= 0;
        end else begin   // Operate when CS active (LOW)
            // FIXED TIMING: SPI Mode 0 - sample on rising edge
            shift_reg_rx <= {shift_reg_rx[DATA_WIDTH-2:0], mosi};
            shift_reg_tx <= {shift_reg_tx[DATA_WIDTH-2:0], 1'b0};
            bit_cnt <= bit_cnt + 1;
            
            if (bit_cnt == DATA_WIDTH-1) begin
                rx_valid <= 1;  // Signal data ready
            end
        end
    end
    
    // FIXED: Setup MISO on falling edge (for SPI Mode 0)
    always_ff @(negedge sclk or posedge cs_n) begin
        if (cs_n) begin
            miso <= 1'bz;  // Tri-state when not selected
        end else begin
            miso <= shift_reg_tx[DATA_WIDTH-1];  // Drive MISO
        end
    end
    
    // Output received data
    assign rx_data = shift_reg_rx;

endmodule
