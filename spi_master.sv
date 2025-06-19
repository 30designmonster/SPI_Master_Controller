//==================================================================================================================================================================================================================//
//  SPI Master                                                                                                                                                                                                                 //
//  Author:Praveen Saravanan                                                                                                                                                                                                                //
//==================================================================================================================================================================================================================//
module spi_master #(
    parameter DATA_WIDTH = 8,
    parameter CLK_DIV = 4
)(
    input  logic        clk,
    input  logic        rst,
    input  logic        start,
    input  logic [DATA_WIDTH-1:0] mosi_data,
    output logic [DATA_WIDTH-1:0] miso_data,
    output logic        done,
    // SPI lines
    output logic        sclk,
    output logic        mosi,
    input  logic        miso,
    output logic        cs_n    // RENAMED: cs_n to show it's active LOW
);

    typedef enum logic [1:0] {IDLE, TRANSFER, DONE_STATE} state_t;
    state_t state;
    
    logic [$clog2(CLK_DIV)-1:0] clk_cnt;
    logic sclk_int;
    logic [$clog2(DATA_WIDTH):0] bit_cnt;
    logic [DATA_WIDTH-1:0] shift_reg_tx, shift_reg_rx;
    
    // SPI outputs
    assign sclk = sclk_int;
    assign cs_n = (state != TRANSFER);  // FIXED: CS active LOW during transfer
    
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            clk_cnt <= 0;
            bit_cnt <= 0;
            shift_reg_tx <= 0;
            shift_reg_rx <= 0;
            sclk_int <= 0;      // SCLK starts LOW (CPOL=0)
            mosi <= 0;
            done <= 0;
            miso_data <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    sclk_int <= 0;  // Keep SCLK idle LOW
                    if (start) begin
                        state <= TRANSFER;
                        shift_reg_tx <= mosi_data;
                        bit_cnt <= DATA_WIDTH;
                        clk_cnt <= 0;
                    end
                end
                
                TRANSFER: begin
                    clk_cnt <= clk_cnt + 1;
                    if (clk_cnt == CLK_DIV-1) begin
                        clk_cnt <= 0;
                        sclk_int <= ~sclk_int;
                        
                        // FIXED TIMING: SPI Mode 0 (CPOL=0, CPHA=0)
                        if (~sclk_int) begin  // On falling edge (setup edge)
                            // Setup MOSI data
                            mosi <= shift_reg_tx[DATA_WIDTH-1];
                            shift_reg_tx <= {shift_reg_tx[DATA_WIDTH-2:0], 1'b0};
                        end else begin        // On rising edge (sample edge)
                            // Sample MISO data
                            shift_reg_rx <= {shift_reg_rx[DATA_WIDTH-2:0], miso};
                            bit_cnt <= bit_cnt - 1;
                            if (bit_cnt == 1) begin  // FIXED: Check for last bit
                                state <= DONE_STATE;
                            end
                        end
                    end
                end
                
                DONE_STATE: begin
                    done <= 1;
                    miso_data <= shift_reg_rx;
                    sclk_int <= 0;  // Return SCLK to idle state
                    if (!start) begin  // Wait for start to go low
                        state <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule
