`timescale 1ns/1ps
`default_nettype none

// Educational RV32I subset. One instruction is active at a time.
// The slave registers a read at the request edge; there is no wait/ready signal.
module rv32i_core (
    input  wire        clk,
    input  wire        reset,
    output reg         mem_req,
    output reg  [31:0] mem_addr,
    output reg  [31:0] mem_wdata,
    output reg  [3:0]  mem_wstrb,
    input  wire [31:0] mem_rdata,
    input  wire        mem_fault,
    output reg         halted,
    output reg  [31:0] fault_pc,
    output reg  [3:0]  fault_code
);
    localparam [1:0] FETCH = 2'd0, EXEC = 2'd1, LOAD_WB = 2'd2;
    localparam [3:0] ILLEGAL = 4'd1, INSTR_ALIGN = 4'd2,
                     DATA_ALIGN = 4'd3, BUS_FAULT = 4'd4;

    reg [31:0] regs [0:31];
    reg [31:0] pc, instr;
    reg [1:0] state;
    reg fetch_pending;
    reg [4:0] load_rd;
    reg [2:0] load_funct3;
    reg [1:0] load_offset;

    wire [6:0] opcode = instr[6:0];
    wire [2:0] funct3 = instr[14:12];
    wire [6:0] funct7 = instr[31:25];
    wire [4:0] rd = instr[11:7];
    wire [31:0] rs1 = (instr[19:15] == 0) ? 32'd0 : regs[instr[19:15]];
    wire [31:0] rs2 = (instr[24:20] == 0) ? 32'd0 : regs[instr[24:20]];

    wire [31:0] imm_i = {{20{instr[31]}}, instr[31:20]};
    wire [31:0] imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    wire [31:0] imm_b = {{19{instr[31]}}, instr[31], instr[7],
                         instr[30:25], instr[11:8], 1'b0};
    wire [31:0] imm_u = {instr[31:12], 12'b0};
    wire [31:0] imm_j = {{11{instr[31]}}, instr[31], instr[19:12],
                         instr[20], instr[30:21], 1'b0};
    wire [31:0] load_shifted = mem_rdata >> {load_offset, 3'b000};

    reg [31:0] next_pc;
    reg [1:0] next_state;
    reg next_fetch_pending, capture_instr, save_load;
    reg write_rd;
    reg [4:0] write_index;
    reg [31:0] write_value;
    reg stop;
    reg [3:0] stop_code;
    reg [31:0] address, target;
    reg take_branch, legal;
    integer i;

    // Decode and bus requests are combinational; architectural changes are below.
    always @* begin
        mem_req = 1'b0;
        mem_addr = 32'd0;
        mem_wdata = 32'd0;
        mem_wstrb = 4'b0000;
        next_pc = pc;
        next_state = state;
        next_fetch_pending = fetch_pending;
        capture_instr = 1'b0;
        save_load = 1'b0;
        write_rd = 1'b0;
        write_index = rd;
        write_value = 32'd0;
        stop = 1'b0;
        stop_code = ILLEGAL;
        address = 32'd0;
        target = 32'd0;
        take_branch = 1'b0;
        legal = 1'b1;

        if (!reset && !halted) begin
            case (state)
                FETCH: begin
                    if (!fetch_pending) begin
                        if (pc[1:0] != 0) begin
                            stop = 1'b1;
                            stop_code = INSTR_ALIGN;
                        end else begin
                            mem_req = 1'b1;
                            mem_addr = pc;
                            next_fetch_pending = 1'b1;
                        end
                    end else begin
                        // The previous edge registered the requested RAM word.
                        capture_instr = 1'b1;
                        next_fetch_pending = 1'b0;
                        next_state = EXEC;
                    end
                end

                EXEC: begin
                    next_pc = pc + 32'd4;
                    next_state = FETCH;
                    next_fetch_pending = 1'b0;
                    case (opcode)
                        7'b0110111: begin // LUI
                            write_rd = 1'b1;
                            write_value = imm_u;
                        end
                        7'b0010111: begin // AUIPC
                            write_rd = 1'b1;
                            write_value = pc + imm_u;
                        end
                        7'b1101111: begin // JAL
                            target = pc + imm_j;
                            write_rd = 1'b1;
                            write_value = pc + 32'd4;
                            next_pc = target;
                            if (target[1:0] != 0) begin
                                stop = 1'b1;
                                stop_code = INSTR_ALIGN;
                            end
                        end
                        7'b1100111: begin // JALR: bit zero is cleared by the ISA.
                            if (funct3 != 3'b000) legal = 1'b0;
                            else begin
                                target = (rs1 + imm_i) & 32'hffff_fffe;
                                write_rd = 1'b1;
                                write_value = pc + 32'd4;
                                next_pc = target;
                                if (target[1:0] != 0) begin
                                    stop = 1'b1;
                                    stop_code = INSTR_ALIGN;
                                end
                            end
                        end
                        7'b1100011: begin // Conditional branches
                            case (funct3)
                                3'b000: take_branch = (rs1 == rs2); // BEQ
                                3'b001: take_branch = (rs1 != rs2); // BNE
                                3'b100: take_branch = ($signed(rs1) < $signed(rs2)); // BLT
                                3'b101: take_branch = ($signed(rs1) >= $signed(rs2)); // BGE
                                3'b110: take_branch = (rs1 < rs2); // BLTU
                                3'b111: take_branch = (rs1 >= rs2); // BGEU
                                default: legal = 1'b0;
                            endcase
                            if (legal && take_branch) begin
                                target = pc + imm_b;
                                next_pc = target;
                                if (target[1:0] != 0) begin
                                    stop = 1'b1;
                                    stop_code = INSTR_ALIGN;
                                end
                            end
                        end
                        7'b0010011: begin // Integer register/immediate operations
                            write_rd = 1'b1;
                            case (funct3)
                                3'b000: write_value = rs1 + imm_i; // ADDI
                                3'b010: write_value = {31'd0, ($signed(rs1) < $signed(imm_i))};
                                3'b011: write_value = {31'd0, (rs1 < imm_i)}; // SLTIU
                                3'b100: write_value = rs1 ^ imm_i;
                                3'b110: write_value = rs1 | imm_i;
                                3'b111: write_value = rs1 & imm_i;
                                3'b001: begin // SLLI has a fixed upper immediate.
                                    if (funct7 != 7'b0000000) legal = 1'b0;
                                    write_value = rs1 << instr[24:20];
                                end
                                3'b101: begin
                                    case (funct7)
                                        7'b0000000: write_value = rs1 >> instr[24:20];
                                        7'b0100000: write_value = $signed(rs1) >>> instr[24:20];
                                        default: legal = 1'b0;
                                    endcase
                                end
                                default: legal = 1'b0;
                            endcase
                        end
                        7'b0110011: begin // Integer register/register operations
                            write_rd = 1'b1;
                            case ({funct7, funct3})
                                {7'b0000000, 3'b000}: write_value = rs1 + rs2;
                                {7'b0100000, 3'b000}: write_value = rs1 - rs2;
                                {7'b0000000, 3'b001}: write_value = rs1 << rs2[4:0];
                                {7'b0000000, 3'b010}: write_value = {31'd0, ($signed(rs1) < $signed(rs2))};
                                {7'b0000000, 3'b011}: write_value = {31'd0, (rs1 < rs2)};
                                {7'b0000000, 3'b100}: write_value = rs1 ^ rs2;
                                {7'b0000000, 3'b101}: write_value = rs1 >> rs2[4:0];
                                {7'b0100000, 3'b101}: write_value = $signed(rs1) >>> rs2[4:0];
                                {7'b0000000, 3'b110}: write_value = rs1 | rs2;
                                {7'b0000000, 3'b111}: write_value = rs1 & rs2;
                                default: legal = 1'b0; // Includes the unimplemented M extension.
                            endcase
                        end
                        7'b0000011: begin // Loads return one edge after this request.
                            address = rs1 + imm_i;
                            case (funct3)
                                3'b000, 3'b100: begin end // LB, LBU
                                3'b001, 3'b101: begin // LH, LHU
                                    if (address[0]) begin
                                        stop = 1'b1;
                                        stop_code = DATA_ALIGN;
                                    end
                                end
                                3'b010: begin // LW
                                    if (address[1:0] != 0) begin
                                        stop = 1'b1;
                                        stop_code = DATA_ALIGN;
                                    end
                                end
                                default: legal = 1'b0;
                            endcase
                            if (legal && !stop) begin
                                mem_req = 1'b1;
                                mem_addr = address;
                                save_load = 1'b1;
                                next_pc = pc;
                                next_state = LOAD_WB;
                            end
                        end
                        7'b0100011: begin // Little-endian stores use byte lane strobes.
                            address = rs1 + imm_s;
                            case (funct3)
                                3'b000: mem_wstrb = 4'b0001 << address[1:0]; // SB
                                3'b001: begin // SH
                                    if (address[0]) begin
                                        stop = 1'b1;
                                        stop_code = DATA_ALIGN;
                                    end else mem_wstrb = 4'b0011 << address[1:0];
                                end
                                3'b010: begin // SW
                                    if (address[1:0] != 0) begin
                                        stop = 1'b1;
                                        stop_code = DATA_ALIGN;
                                    end else mem_wstrb = 4'b1111;
                                end
                                default: legal = 1'b0;
                            endcase
                            if (legal && !stop) begin
                                mem_req = 1'b1;
                                mem_addr = address;
                                mem_wdata = rs2 << {address[1:0], 3'b000};
                            end else mem_wstrb = 4'b0000;
                        end
                        default: legal = 1'b0; // FENCE and all SYSTEM instructions halt.
                    endcase
                    if (!legal) begin
                        stop = 1'b1;
                        stop_code = ILLEGAL;
                        mem_req = 1'b0;
                        mem_wstrb = 4'b0000;
                    end
                end

                LOAD_WB: begin
                    write_rd = 1'b1;
                    write_index = load_rd;
                    case (load_funct3)
                        3'b000: write_value = {{24{load_shifted[7]}}, load_shifted[7:0]};
                        3'b001: write_value = {{16{load_shifted[15]}}, load_shifted[15:0]};
                        3'b010: write_value = mem_rdata;
                        3'b100: write_value = {24'd0, load_shifted[7:0]};
                        3'b101: write_value = {16'd0, load_shifted[15:0]};
                        default: begin stop = 1'b1; stop_code = ILLEGAL; end
                    endcase
                    next_pc = pc + 32'd4;
                    next_state = FETCH;
                end
                default: begin stop = 1'b1; stop_code = ILLEGAL; end
            endcase
            // A rejecting slave must not perform the requested read/write.
            // Keep the request stable so fault decoding has no feedback loop.
            if (mem_req && mem_fault) begin
                stop = 1'b1;
                stop_code = BUS_FAULT;
            end
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            pc <= 32'd0;
            instr <= 32'h0000_0013;
            state <= FETCH;
            fetch_pending <= 1'b0;
            halted <= 1'b0;
            fault_pc <= 32'd0;
            fault_code <= 4'd0;
            load_rd <= 5'd0;
            load_funct3 <= 3'd0;
            load_offset <= 2'd0;
            for (i = 0; i < 32; i = i + 1) regs[i] <= 32'd0;
        end else begin
            regs[0] <= 32'd0;
            if (!halted) begin
                if (stop) begin
                    halted <= 1'b1;
                    fault_pc <= pc;
                    fault_code <= stop_code;
                end else begin
                    pc <= next_pc;
                    state <= next_state;
                    fetch_pending <= next_fetch_pending;
                    if (capture_instr) instr <= mem_rdata;
                    if (write_rd && write_index != 0) regs[write_index] <= write_value;
                    if (save_load) begin
                        load_rd <= rd;
                        load_funct3 <= funct3;
                        load_offset <= address[1:0];
                    end
                end
            end
        end
    end
endmodule

`default_nettype wire
