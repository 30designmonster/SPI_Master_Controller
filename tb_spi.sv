///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//TESTBENCH
//Author:Praveen Saravanan
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
module spi_testbench;

    // Parameters
    parameter DATA_WIDTH = 8;
    parameter CLK_DIV = 4;
    parameter CLK_PERIOD = 10;  // 100MHz system clock
    
    // System signals
    logic clk;
    logic rst;
    
    // Master interface
    logic start;
    logic [DATA_WIDTH-1:0] master_tx_data;
    logic [DATA_WIDTH-1:0] master_rx_data;
    logic master_done;
    
    // SPI bus
    logic sclk;
    logic mosi;
    logic miso;
    logic cs_n;
    
    // Slave interface
    logic [DATA_WIDTH-1:0] slave_tx_data;
    logic [DATA_WIDTH-1:0] slave_rx_data;
    logic slave_rx_valid;
    
    //==========================================================================
    // DUT INSTANTIATIONS
    //==========================================================================
    
    // Master
    spi_master #(
        .DATA_WIDTH(DATA_WIDTH),
        .CLK_DIV(CLK_DIV)
    ) u_master (
        .clk(clk),
        .rst(rst),
        .start(start),
        .mosi_data(master_tx_data),
        .miso_data(master_rx_data),
        .done(master_done),
        .sclk(sclk),
        .mosi(mosi),
        .miso(miso),
        .cs_n(cs_n)
    );
    
    // Slave
    spi_slave #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_slave (
        .sclk(sclk),
        .mosi(mosi),
        .cs_n(cs_n),
        .miso(miso),
        .tx_data(slave_tx_data),
        .rx_data(slave_rx_data),
        .rx_valid(slave_rx_valid)
    );
    
    //==========================================================================
    // CLOCK GENERATION
    //==========================================================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    //==========================================================================
    // TEST TASKS
    //==========================================================================
    
    // Task to send data via SPI
    task send_spi_data(input [DATA_WIDTH-1:0] data);
        begin
            $display("Time %0t: Sending 0x%02X", $time, data);
            master_tx_data = data;
            start = 1;
            @(posedge clk);
            start = 0;
            
            // Wait for transfer to complete
            wait(master_done);
            @(posedge clk);
            
            $display("Time %0t: Transfer complete. Master RX: 0x%02X, Slave RX: 0x%02X", 
                     $time, master_rx_data, slave_rx_data);
        end
    endtask
    
    // Task to check if transfer worked correctly
    task verify_transfer(input [DATA_WIDTH-1:0] expected_slave_rx, 
                        input [DATA_WIDTH-1:0] expected_master_rx);
        begin
            if (slave_rx_data == expected_slave_rx) begin
                $display("PASS: Slave received correct data: 0x%02X", slave_rx_data);
            end else begin
                $display("FAIL: Slave expected 0x%02X, got 0x%02X", 
                         expected_slave_rx, slave_rx_data);
            end
            
            if (master_rx_data == expected_master_rx) begin
                $display("PASS: Master received correct data: 0x%02X", master_rx_data);
            end else begin
                $display("FAIL: Master expected 0x%02X, got 0x%02X", 
                         expected_master_rx, master_rx_data);
            end
        end
    endtask
    
    //==========================================================================
    // MAIN TEST SEQUENCE
    //==========================================================================
    initial begin
        // Initialize signals
        rst = 1;
        start = 0;
        master_tx_data = 0;
        slave_tx_data = 8'h5A;  // Slave will send this back to master
        
        // Generate VCD dump for waveform viewing
        $dumpfile("spi_test.vcd");
        $dumpvars(0, spi_testbench);
        
        $display("=== SPI Master-Slave Test Starting ===");
        
        // Reset sequence
        #(CLK_PERIOD * 5);
        rst = 0;
        #(CLK_PERIOD * 2);
        
        $display("\nTest 1: Basic transfer");
        send_spi_data(8'h55);  // Send 0x55 to slave
        verify_transfer(8'h55, 8'h5A);  // Slave should receive 0x55, master should receive 0x5A
        
        #(CLK_PERIOD * 10);
        
        $display("\nTest 2: Different data pattern");
        slave_tx_data = 8'hAA;  // Change slave's response
        send_spi_data(8'h33);   // Send 0x33 to slave
        verify_transfer(8'h33, 8'hAA);
        
        #(CLK_PERIOD * 10);
        
        $display("\nTest 3: All zeros");
        slave_tx_data = 8'h00;
        send_spi_data(8'h00);
        verify_transfer(8'h00, 8'h00);
        
        #(CLK_PERIOD * 10);
        
        $display("\nTest 4: All ones");
        slave_tx_data = 8'hFF;
        send_spi_data(8'hFF);
        verify_transfer(8'hFF, 8'hFF);
        
        #(CLK_PERIOD * 10);
        
        $display("\nTest 5: Back-to-back transfers");
        slave_tx_data = 8'h11;
        send_spi_data(8'h22);
        verify_transfer(8'h22, 8'h11);
        
        // Immediate second transfer
        slave_tx_data = 8'h44;
        send_spi_data(8'h88);
        verify_transfer(8'h88, 8'h44);
        
        #(CLK_PERIOD * 20);
        
        $display("\n=== All Tests Complete ===");
        $display("Check waveforms in spi_test.vcd");
        $finish;
    end
    
    //==========================================================================
    // MONITORING
    //==========================================================================
    
    // Monitor SPI signals for debugging
    always @(negedge cs_n) begin
        $display("Time %0t: SPI Transfer Starting (CS asserted)", $time);
    end
    
    always @(posedge cs_n) begin
        $display("Time %0t: SPI Transfer Ending (CS released)", $time);
    end
    
    // Timeout watchdog
    initial begin
        #(CLK_PERIOD * 10000);  // 10000 clock cycles timeout
        $display("ERROR: Test timeout!");
        $finish;
    end

endmodule
