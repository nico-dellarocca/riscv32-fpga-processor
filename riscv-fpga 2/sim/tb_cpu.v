`timescale 1ns/1ps
`default_nettype none

// Encoders only build test instructions; the expected values are independent
// constants. This bench runs the RTL against an edge-registered RAM model.
module tb_cpu;
    reg clk = 1'b0;
    always #5 clk = !clk;
    reg reset = 1'b1;
    wire req, halted;
    wire [31:0] addr, wdata, fault_pc;
    wire [3:0] wstrb, fault_code;
    reg [31:0] rdata;
    wire bus_fault = req && (addr[31:12] != 0);
    reg [31:0] memory [0:1023];
    integer lane, writes, load_wb_count, cycles;
    integer p, expected_loads, n, auipc_pc;

    rv32i_core dut (
        .clk(clk), .reset(reset), .mem_req(req), .mem_addr(addr),
        .mem_wdata(wdata), .mem_wstrb(wstrb), .mem_rdata(rdata),
        .mem_fault(bus_fault), .halted(halted),
        .fault_pc(fault_pc), .fault_code(fault_code)
    );

    always @(posedge clk) begin
        if (reset) begin
            rdata <= 32'd0;
            writes <= 0;
            load_wb_count <= 0;
        end else begin
            if (!halted && dut.state == 2) load_wb_count <= load_wb_count + 1;
            if (req && !bus_fault) begin
                if (wstrb == 0) rdata <= memory[addr[11:2]];
                else begin
                    for (lane = 0; lane < 4; lane = lane + 1)
                        if (wstrb[lane])
                            memory[addr[11:2]][8*lane +: 8] <= wdata[8*lane +: 8];
                    writes <= writes + 1;
                end
            end
        end
    end

    function [31:0] op_i;
        input [4:0] rd, rs1;
        input [2:0] f3;
        input integer imm;
        begin op_i = {imm[11:0], rs1, f3, rd, 7'h13}; end
    endfunction
    function [31:0] op_r;
        input [4:0] rd, rs1, rs2;
        input [2:0] f3;
        input [6:0] f7;
        begin op_r = {f7, rs2, rs1, f3, rd, 7'h33}; end
    endfunction
    function [31:0] load;
        input [4:0] rd, rs1;
        input [2:0] f3;
        input integer imm;
        begin load = {imm[11:0], rs1, f3, rd, 7'h03}; end
    endfunction
    function [31:0] store;
        input [4:0] rs1, rs2;
        input [2:0] f3;
        input integer imm;
        begin store = {imm[11:5], rs2, rs1, f3, imm[4:0], 7'h23}; end
    endfunction
    function [31:0] branch;
        input [4:0] rs1, rs2;
        input [2:0] f3;
        input integer imm;
        begin
            branch = {imm[12], imm[10:5], rs2, rs1, f3,
                      imm[4:1], imm[11], 7'h63};
        end
    endfunction
    function [31:0] jal;
        input [4:0] rd;
        input integer imm;
        begin jal = {imm[20], imm[10:1], imm[11], imm[19:12], rd, 7'h6f}; end
    endfunction
    function [31:0] jalr;
        input [4:0] rd, rs1;
        input [2:0] f3;
        input integer imm;
        begin jalr = {imm[11:0], rs1, f3, rd, 7'h67}; end
    endfunction
    function [31:0] upper;
        input [4:0] rd;
        input [19:0] imm;
        input [6:0] opcode;
        begin upper = {imm, rd, opcode}; end
    endfunction

    task check;
        input [511:0] label;
        input [31:0] actual, expected;
        begin
            if (actual !== expected)
                $fatal(1, "%0s: got %08x, expected %08x", label, actual, expected);
        end
    endtask
    task clear_program;
        begin
            reset = 1'b1;
            for (n = 0; n < 1024; n = n + 1) memory[n] = 32'd0;
            p = 0;
            expected_loads = 0;
        end
    endtask
    task emit;
        input [31:0] word;
        begin
            memory[p] = word;
            p = p + 1;
            if (word[6:0] == 7'h03) expected_loads = expected_loads + 1;
        end
    endtask
    task run;
        begin
            repeat (2) @(negedge clk);
            reset = 1'b0;
            cycles = 0;
            while (!halted && cycles < 500) begin
                @(posedge clk);
                #1;
                cycles = cycles + 1;
            end
            if (!halted) $fatal(1, "CPU timeout: pc=%08x state=%0d", dut.pc, dut.state);
        end
    endtask
    task expect_halt;
        input [31:0] at_pc;
        input [3:0] code;
        begin
            check("fault PC", fault_pc, at_pc);
            check("fault code", {28'd0, fault_code}, {28'd0, code});
            check("x0", dut.regs[0], 0);
            repeat (2) @(posedge clk);
            #1;
            if (!halted || req) $fatal(1, "halt was not sticky or issued a request");
            check("PC remains at faulting instruction", dut.pc, at_pc);
        end
    endtask
    task run_branch;
        input [2:0] f3;
        input integer a, b;
        input taken;
        begin
            clear_program;
            emit(op_i(1, 0, 0, a));
            emit(op_i(2, 0, 0, b));
            emit(branch(1, 2, f3, 8));
            emit(op_i(3, 0, 0, 1));
            emit(op_i(3, 3, 0, 2));
            run;
            expect_halt(20, 1);
            check("branch result", dut.regs[3], taken ? 2 : 3);
            check("branch timing", cycles, taken ? 15 : 18);
        end
    endtask
    task reject;
        input [511:0] label;
        input [31:0] word;
        input [3:0] code;
        begin
            clear_program;
            emit(op_i(1, 0, 0, 7));
            emit(word);
            emit(op_i(2, 0, 0, 9));
            run;
            expect_halt(4, code);
            check(label, dut.regs[1], 7);
            check("fault prevents next instruction", dut.regs[2], 0);
            check("fault prevents stores", writes, 0);
        end
    endtask

    initial begin
        clear_program;
        emit(op_i(1, 0, 0, 5));
        emit(op_i(2, 0, 0, 7));
        emit(op_r(3, 1, 2, 0, 0));       // ADD = 12
        emit(op_r(4, 2, 1, 0, 7'h20));   // SUB = 2
        emit(op_i(5, 0, 0, -1));
        emit(op_i(0, 0, 0, 99));         // Writes to x0 are discarded.
        emit(op_i(6, 1, 1, 3));          // SLLI
        emit(op_i(7, 5, 5, 4));          // SRLI
        emit(op_i(8, 5, 5, 12'h404));    // SRAI
        emit(op_i(9, 5, 2, 0));          // SLTI (signed)
        emit(op_i(10, 1, 3, -1));        // SLTIU still sign-extends its immediate.
        emit(op_i(11, 1, 4, 3));         // XORI
        emit(op_i(12, 1, 6, 8));         // ORI
        emit(op_i(13, 5, 7, 15));        // ANDI
        emit(op_r(14, 1, 2, 1, 0));      // SLL
        emit(op_r(15, 5, 1, 5, 0));      // SRL
        emit(op_r(16, 5, 1, 5, 7'h20));  // SRA
        emit(op_r(17, 5, 1, 2, 0));      // SLT
        emit(op_r(18, 5, 1, 3, 0));      // SLTU
        emit(op_r(19, 1, 2, 4, 0));      // XOR
        emit(op_r(20, 1, 2, 6, 0));      // OR
        emit(op_r(21, 1, 2, 7, 0));      // AND
        emit(upper(22, 20'h12345, 7'h37));
        auipc_pc = 4*p;
        emit(upper(23, 0, 7'h17));
        emit(op_i(24, 0, 0, -2048));
        emit(op_i(25, 0, 0, 2047));
        emit(op_i(26, 0, 0, 33));
        emit(op_r(27, 1, 26, 1, 0));     // Register shifts use only low five bits.
        emit(op_i(28, 1, 2, -1));
        emit(op_i(29, 5, 3, -1));
        emit(op_i(30, 0, 0, 0));
        run;
        expect_halt(p*4, 1);             // A zero word is the intentional terminator.
        check("ADDI", dut.regs[1], 5);
        check("ADD", dut.regs[3], 12);
        check("SUB", dut.regs[4], 2);
        check("negative immediate", dut.regs[5], 32'hffff_ffff);
        check("SLLI", dut.regs[6], 40);
        check("SRLI", dut.regs[7], 32'h0fff_ffff);
        check("SRAI", dut.regs[8], 32'hffff_ffff);
        check("SLTI true", dut.regs[9], 1);
        check("SLTIU true", dut.regs[10], 1);
        check("XORI", dut.regs[11], 6);
        check("ORI", dut.regs[12], 13);
        check("ANDI", dut.regs[13], 15);
        check("SLL", dut.regs[14], 640);
        check("SRL", dut.regs[15], 32'h07ff_ffff);
        check("SRA", dut.regs[16], 32'hffff_ffff);
        check("SLT", dut.regs[17], 1);
        check("SLTU", dut.regs[18], 0);
        check("XOR", dut.regs[19], 2);
        check("OR", dut.regs[20], 7);
        check("AND", dut.regs[21], 5);
        check("LUI", dut.regs[22], 32'h1234_5000);
        check("AUIPC", dut.regs[23], auipc_pc);
        check("minimum I immediate", dut.regs[24], 32'hffff_f800);
        check("maximum I immediate", dut.regs[25], 2047);
        check("shift masks count", dut.regs[27], 10);
        check("SLTI false", dut.regs[28], 0);
        check("SLTIU false", dut.regs[29], 0);
        check("read x0 after attempted write", dut.regs[30], 0);
        check("three cycles per ordinary instruction", cycles, 3*(p+1));
        $display("PASS cpu arithmetic: all 21 ALU/U mnemonics, x0, signed immediates; %0d cycles", cycles);

        clear_program;
        emit(op_i(1, 0, 0, 16'h200));
        emit(upper(2, 20'h80ff8, 7'h37));
        emit(op_i(2, 2, 0, -255));        // x2 = 80ff7f01
        emit(store(1, 2, 2, 0));
        emit(load(3, 1, 0, 3));
        emit(load(4, 1, 4, 3));
        emit(load(5, 1, 1, 2));
        emit(load(6, 1, 5, 2));
        emit(load(7, 1, 2, 0));
        emit(load(8, 1, 0, 1));
        emit(load(9, 1, 1, 0));
        emit(store(1, 2, 0, 1));
        emit(store(1, 2, 1, 2));
        emit(load(10, 1, 2, 0));
        emit(store(1, 0, 2, 4));
        emit(store(1, 5, 0, 7));
        emit(load(11, 1, 4, 7));
        emit(load(12, 1, 0, 7));
        emit(load(13, 1, 1, 6));
        emit(load(14, 1, 5, 6));
        emit(op_i(15, 1, 0, 8));
        emit(store(15, 2, 2, -8));
        emit(load(16, 15, 2, -8));
        emit(load(0, 1, 0, 3));
        run;
        expect_halt(p*4, 1);
        check("LB negative", dut.regs[3], 32'hffff_ff80);
        check("LBU", dut.regs[4], 128);
        check("LH negative", dut.regs[5], 32'hffff_80ff);
        check("LHU", dut.regs[6], 32'h0000_80ff);
        check("LW", dut.regs[7], 32'h80ff_7f01);
        check("LB positive lane 1", dut.regs[8], 127);
        check("LH positive", dut.regs[9], 32'h0000_7f01);
        check("SB/SH preserve other lanes", dut.regs[10], 32'h7f01_0101);
        check("LBU lane 3", dut.regs[11], 255);
        check("LB lane 3", dut.regs[12], 32'hffff_ffff);
        check("LH upper half", dut.regs[13], 32'hffff_ff00);
        check("LHU upper half", dut.regs[14], 32'h0000_ff00);
        check("negative load/store offset", dut.regs[16], 32'h80ff_7f01);
        check("RAM round-trip", memory[128], 32'h80ff_7f01);
        check("RAM byte preservation", memory[129], 32'hff00_0000);
        check("each load takes LOAD_WB", load_wb_count, expected_loads);
        check("loads add exactly one cycle", cycles, 3*(p+1)+expected_loads);
        $display("PASS cpu memory: all 8 load/store mnemonics, lanes, extension, %0d LOAD_WB cycles; %0d cycles", load_wb_count, cycles);

        run_branch(0, 5, 5, 1);  run_branch(0, 5, 6, 0);
        run_branch(1, 5, 6, 1);  run_branch(1, 5, 5, 0);
        run_branch(4, -1, 1, 1); run_branch(4, 1, -1, 0);
        run_branch(5, 1, -1, 1); run_branch(5, -1, 1, 0);
        run_branch(6, 1, -1, 1); run_branch(6, -1, 1, 0);
        run_branch(7, -1, 1, 1); run_branch(7, 1, -1, 0);
        clear_program;
        emit(op_i(1, 0, 0, 3));
        emit(op_i(2, 0, 0, 0));
        emit(op_i(2, 2, 0, 1));
        emit(op_i(1, 1, 0, -1));
        emit(branch(1, 0, 1, -8));
        run;
        expect_halt(20, 1);
        check("backward branch loop count", dut.regs[2], 3);
        check("backward branch counter", dut.regs[1], 0);
        check("backward branch cycles", cycles, 36);
        clear_program;
        memory[0] = op_i(1, 0, 0, 1);
        memory[1] = branch(1, 1, 0, 2048);
        memory[513] = op_i(2, 0, 0, 31); // PC 4 + 2048: checks B immediate bit 11.
        run;
        expect_halt(2056, 1);
        check("discontiguous B immediate bit 11", dut.regs[2], 31);
        $display("PASS cpu branches: all 6 branches taken/not-taken, signed/unsigned, backward offset");

        clear_program;
        memory[0] = op_i(1, 0, 0, 0);
        memory[1] = jal(5, 12);
        memory[2] = op_i(6, 0, 0, 42);
        memory[3] = jal(0, 24);
        memory[4] = op_i(7, 0, 0, 9);
        memory[5] = jalr(8, 7, 0, 0);
        memory[6] = op_i(6, 0, 0, 99);
        run;
        expect_halt(36, 1);
        check("JAL link", dut.regs[5], 8);
        check("JALR clears target bit zero", dut.regs[6], 42);
        check("JALR link", dut.regs[8], 24);
        clear_program;
        memory[0] = jal(0, 12);
        memory[1] = op_i(4, 0, 0, 7);
        memory[2] = jal(0, 12);
        memory[3] = jal(5, -8);
        run;
        expect_halt(20, 1);
        check("negative JAL offset", dut.regs[4], 7);
        check("negative JAL link", dut.regs[5], 16);
        clear_program;
        memory[0] = jal(5, 2052);
        memory[513] = op_i(6, 0, 0, 17); // Separates J immediate bit 11 from sign.
        run;
        expect_halt(2056, 1);
        check("discontiguous J immediate bit 11", dut.regs[6], 17);
        check("large forward JAL link", dut.regs[5], 4);
        $display("PASS cpu jumps: JAL, JALR, links, bit-zero clearing, negative J immediate");

        reject("FENCE unsupported", 32'h0000_000f, 1);
        reject("ECALL unsupported", 32'h0000_0073, 1);
        reject("EBREAK unsupported", 32'h0010_0073, 1);
        reject("M extension unsupported", op_r(1, 1, 1, 0, 1), 1);
        reject("reserved R funct7", op_r(1, 1, 1, 1, 7'h20), 1);
        reject("reserved SLLI upper bits", op_i(1, 1, 1, 12'h020), 1);
        reject("reserved right-shift upper bits", op_i(1, 1, 5, 12'h220), 1);
        reject("reserved JALR funct3", jalr(1, 1, 1, 0), 1);
        reject("reserved load funct3", load(1, 1, 3, 0), 1);
        reject("reserved store funct3", store(1, 1, 3, 0), 1);
        reject("reserved branch funct3", branch(1, 1, 2, 8), 1);
        reject("misaligned LW", load(1, 1, 2, 0), 3);
        reject("misaligned LH", load(1, 1, 1, 0), 3);
        reject("misaligned SW", store(1, 1, 2, 0), 3);
        reject("misaligned SH", store(1, 1, 1, 0), 3);
        reject("misaligned JAL", jal(1, 2), 2);
        reject("misaligned JALR after bit clear", jalr(1, 1, 0, 0), 2);
        reject("misaligned taken branch", branch(1, 1, 0, 2), 2);
        clear_program;
        emit(op_i(1, 0, 0, 7));
        emit(branch(1, 1, 1, 2));
        emit(op_i(2, 0, 0, 9));
        run;
        expect_halt(12, 1);
        check("untaken branch need not align target", dut.regs[2], 9);

        clear_program;
        emit(upper(1, 1, 7'h37));
        emit(load(1, 1, 2, 0));
        run;
        expect_halt(4, 4);
        check("bus fault preserves destination", dut.regs[1], 4096);
        clear_program;
        emit(upper(1, 1, 7'h37));
        emit(load(0, 1, 2, 0));
        run;
        expect_halt(4, 4); // Loads to x0 still perform access checks.
        clear_program;
        emit(upper(1, 1, 7'h37));
        emit(store(1, 1, 2, 0));
        run;
        expect_halt(4, 4);
        check("rejected bus store has no effect", writes, 0);
        clear_program;
        emit(jal(5, 32'h0008_0004)); // Tests the J immediate's upper bit group too.
        run;
        expect_halt(32'h0008_0004, 4);
        check("fetch fault follows completed JAL", dut.regs[5], 4);
        $display("PASS cpu faults: unsupported/reserved encodings, alignment, rejected reads/writes/fetches, sticky halt");
        $display("PASS tb_cpu");
        $finish;
    end

    initial begin
        #200000;
        $fatal(1, "testbench watchdog expired");
    end
endmodule

`default_nettype wire
