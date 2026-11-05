`timescale 1ns/1ps
// Minimal end-to-end smoke test: AXI4-Lite key push -> read back handle ->
// AXI4-Stream data transaction using that handle -> observe M_AXIS result.
// Not a protocol-compliance test suite (no back-to-back/narrow/unaligned
// transfer stress) - just proves the wrapper's wiring is functionally
// sound before it goes into the backend flow.
module tb_aes_axi_wrapper;
    import aes_pkg::*;

    logic ACLK = 0;
    always #5 ACLK = ~ACLK;
    logic ARESETn;

    logic [7:0] S_AXI_AWADDR; logic S_AXI_AWVALID, S_AXI_AWREADY;
    logic [31:0] S_AXI_WDATA; logic [3:0] S_AXI_WSTRB; logic S_AXI_WVALID, S_AXI_WREADY;
    logic [1:0] S_AXI_BRESP; logic S_AXI_BVALID, S_AXI_BREADY;
    logic [7:0] S_AXI_ARADDR; logic S_AXI_ARVALID, S_AXI_ARREADY;
    logic [31:0] S_AXI_RDATA; logic [1:0] S_AXI_RRESP; logic S_AXI_RVALID, S_AXI_RREADY;

    logic [127:0] S_AXIS_TDATA; logic [17:0] S_AXIS_TUSER;
    logic S_AXIS_TVALID, S_AXIS_TREADY, S_AXIS_TLAST;
    logic [127:0] M_AXIS_TDATA; logic [0:0] M_AXIS_TUSER;
    logic M_AXIS_TVALID, M_AXIS_TREADY, M_AXIS_TLAST;

    int pass_count=0, fail_count=0;
    task automatic check(input string name, input bit cond);
        if (cond) begin pass_count++; $display("[PASS] %s", name); end
        else begin fail_count++; $display("[FAIL] %s", name); end
    endtask

    aes_axi_wrapper dut (.*);

    // ---- AXI4-Lite helper tasks ----
    task automatic axi_write(input [7:0] addr, input [31:0] data);
        // Minimal, protocol-correct single-cycle hold: the slave's
        // AWREADY/WREADY are purely combinational (see aes_axi_wrapper's
        // write-channel comment), so holding VALID for more than the one
        // cycle needed for acceptance would cause the slave to
        // (correctly, per AXI semantics) accept the SAME address/data as
        // a SECOND, separate write - discovered during wrapper bring-up
        // when an earlier, over-cautious multi-cycle hold in this task
        // caused a spurious duplicate write.
        @(negedge ACLK);
        S_AXI_AWADDR = addr; S_AXI_AWVALID = 1;
        S_AXI_WDATA = data; S_AXI_WSTRB = 4'hF; S_AXI_WVALID = 1;
        S_AXI_BREADY = 1;
        @(negedge ACLK);
        S_AXI_AWVALID = 0; S_AXI_WVALID = 0;
        wait (S_AXI_BVALID);
        @(negedge ACLK);
        S_AXI_BREADY = 0;
    endtask

    task automatic axi_read(input [7:0] addr, output [31:0] data);
        // Same minimal single-cycle hold rationale as axi_write.
        @(negedge ACLK);
        S_AXI_ARADDR = addr; S_AXI_ARVALID = 1; S_AXI_RREADY = 1;
        @(negedge ACLK);
        S_AXI_ARVALID = 0;
        wait (S_AXI_RVALID);
        data = S_AXI_RDATA;
        @(negedge ACLK);
        S_AXI_RREADY = 0;
    endtask

    localparam aes_block_t KAT_KEY = 128'h000102030405060708090a0b0c0d0e0f;
    localparam aes_block_t KAT_PT  = 128'h00112233445566778899aabbccddeeff;

    logic [31:0] rdata;
    logic [15:0] handle;
    logic bank_sel;

    initial begin
        ARESETn = 0;
        S_AXI_AWADDR=0; S_AXI_AWVALID=0; S_AXI_WDATA=0; S_AXI_WSTRB=0; S_AXI_WVALID=0; S_AXI_BREADY=0;
        S_AXI_ARADDR=0; S_AXI_ARVALID=0; S_AXI_RREADY=0;
        S_AXIS_TDATA=0; S_AXIS_TUSER=0; S_AXIS_TVALID=0; S_AXIS_TLAST=1; M_AXIS_TREADY=1;
        repeat(5) @(negedge ACLK);
        ARESETn = 1;
        repeat(3) @(negedge ACLK);

        // Stage key words 0..3 via AXI-Lite writes, then pulse push
        axi_write(8'h00, KAT_KEY[31:0]);
        axi_write(8'h04, KAT_KEY[63:32]);
        axi_write(8'h08, KAT_KEY[95:64]);
        axi_write(8'h0C, KAT_KEY[127:96]);

        axi_read(8'h14, rdata);
        check("key_push_ready true before push", rdata[0] === 1'b1);

        axi_write(8'h10, 32'h1); // KEY_CTRL.PUSH

        axi_read(8'h18, rdata);
        handle = rdata[15:0];
        $display("[INFO] key_gen handle assigned = %0d", handle);

        // Poll KEY_STATUS until a bank goes valid
        begin
            int to;
            for (to=0; to<50; to++) begin
                axi_read(8'h14, rdata);
                if (rdata[4] || rdata[5]) begin
                    bank_sel = rdata[4] ? 1'b0 : 1'b1;
                    to = 1000; // break
                end else begin
                    @(negedge ACLK);
                end
            end
            check("a bank went valid after AXI-Lite key push", to >= 1000);
        end

        // Issue one AXI4-Stream transaction using the handle
        @(negedge ACLK);
        S_AXIS_TDATA = KAT_PT;
        S_AXIS_TUSER = {handle, bank_sel, 1'b0}; // [17:2]=key_gen [1]=bank [0]=op_mode(encrypt)
        S_AXIS_TVALID = 1;
        @(posedge ACLK); #1;
        check("S_AXIS_TREADY asserted for correctly-tagged beat", S_AXIS_TREADY === 1'b1);
        @(negedge ACLK);
        S_AXIS_TVALID = 0;

        // Wait for the result on M_AXIS
        begin
            int to;
            for (to=0; to<30 && !M_AXIS_TVALID; to++) @(negedge ACLK);
            check("M_AXIS_TVALID observed within pipeline latency", M_AXIS_TVALID === 1'b1);
        end

        // Now try a deliberately wrong key_gen -> should be refused
        @(negedge ACLK);
        S_AXIS_TDATA = KAT_PT;
        S_AXIS_TUSER = {16'hDEAD, bank_sel, 1'b0};
        S_AXIS_TVALID = 1;
        @(posedge ACLK); #1;
        check("S_AXIS_TREADY LOW for wrong key_gen (wrapper propagates the fix)", S_AXIS_TREADY === 1'b0);
        @(negedge ACLK);
        S_AXIS_TVALID = 0;

        axi_read(8'h14, rdata);
        check("KEY_STATUS.key_ctx_error sticky bit set after mismatch", rdata[10] === 1'b1);

        repeat(20) @(negedge ACLK);
        $display("========================================");
        $display("TB_AES_AXI_WRAPPER RESULTS: PASS=%0d FAIL=%0d", pass_count, fail_count);
        $display("========================================");
        $finish;
    end

    initial begin
        #5000;
        $display("[TIMEOUT] tb_aes_axi_wrapper watchdog fired");
        $finish;
    end
endmodule
