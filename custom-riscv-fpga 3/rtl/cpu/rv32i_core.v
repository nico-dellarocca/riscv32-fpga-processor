// A small multicycle RV32I integer core.
//
// Memory contract: the SoC samples a request on the rising edge and updates
// mem_rdata with the selected aligned 32-bit word on that SAME edge. The CPU
// consumes the registered response in EXEC (instruction) or LOAD_WB (data).
// Instructions normally retire every two clocks; loads take three clocks.
// This is neither a pipelined design nor a processor with a privileged ISA.
//
// Stop reasons: 1 illegal/unsupported instruction, 2 misaligned instruction
// target, 3 misaligned load/store, 4 ECALL, 5 EBREAK.
module rv32i_core (
    input  wire        clk,
    input  wire        reset,
    output reg         mem_valid,
    output reg         mem_write,
    output reg  [31:0] mem_addr,
    output reg  [31:0] mem_wdata,
    output reg  [3:0]  mem_wstrb,
    input  wire [31:0] mem_rdata,
    output reg         halted,
    output reg  [3:0]  halt_reason,
    output reg         trace_valid,
    output reg  [31:0] trace_pc,
    output reg  [31:0] trace_insn,
    output reg  [4:0]  trace_rd,
    output reg  [31:0] trace_value,
    output reg  [3:0]  trace_store_mask,
    output reg  [31:0] trace_store_addr,
    output reg  [31:0] trace_store_data
);
    localparam [1:0] FETCH = 2'd0, EXEC = 2'd1, LOAD_WB = 2'd2;
    reg [1:0] state;
    reg [31:0] pc;
    reg [31:0] regs [0:31];
    integer i;

    wire [31:0] insn = mem_rdata;
    wire [6:0] op = insn[6:0];
    wire [2:0] f3 = insn[14:12];
    wire [6:0] f7 = insn[31:25];
    wire [4:0] rd = insn[11:7];
    wire [4:0] rs1 = insn[19:15];
    wire [4:0] rs2 = insn[24:20];
    wire [31:0] src1 = (rs1 == 0) ? 32'd0 : regs[rs1];
    wire [31:0] src2 = (rs2 == 0) ? 32'd0 : regs[rs2];
    wire [31:0] imm_i = {{20{insn[31]}}, insn[31:20]};
    wire [31:0] imm_s = {{20{insn[31]}}, insn[31:25], insn[11:7]};
    wire [31:0] imm_b = {{19{insn[31]}}, insn[31], insn[7],
                         insn[30:25], insn[11:8], 1'b0};
    wire [31:0] imm_u = {insn[31:12], 12'b0};
    wire [31:0] imm_j = {{11{insn[31]}}, insn[31], insn[19:12],
                         insn[20], insn[30:21], 1'b0};

    reg [31:0] next_pc;
    reg [31:0] result;
    reg [31:0] effective_addr;
    reg [3:0]  write_strobe;
    reg        write_rd;
    reg        is_load;
    reg        is_store;
    reg        illegal;
    reg        misaligned_data;
    reg        system_stop;
    reg [3:0]  system_reason;
    reg        take_branch;

    always @* begin
        next_pc = pc + 32'd4;
        result = 32'd0;
        effective_addr = 32'd0;
        write_strobe = 4'b0000;
        write_rd = 1'b0;
        is_load = 1'b0;
        is_store = 1'b0;
        illegal = 1'b0;
        misaligned_data = 1'b0;
        system_stop = 1'b0;
        system_reason = 4'd0;
        take_branch = 1'b0;
        case (op)
            7'b0110111: begin // LUI
                write_rd = 1'b1;
                result = imm_u;
            end
            7'b0010111: begin // AUIPC
                write_rd = 1'b1;
                result = pc + imm_u;
            end
            7'b1101111: begin // JAL
                write_rd = 1'b1;
                result = pc + 32'd4;
                next_pc = pc + imm_j;
            end
            7'b1100111: begin // JALR: clear bit zero
                if (f3 != 3'b000) illegal = 1'b1;
                else begin
                    write_rd = 1'b1;
                    result = pc + 32'd4;
                    next_pc = (src1 + imm_i) & 32'hffff_fffe;
                end
            end
            7'b1100011: begin // branches
                case (f3)
                    3'b000: take_branch = src1 == src2;                 // BEQ
                    3'b001: take_branch = src1 != src2;                 // BNE
                    3'b100: take_branch = $signed(src1) < $signed(src2);// BLT
                    3'b101: take_branch = $signed(src1) >= $signed(src2);// BGE
                    3'b110: take_branch = src1 < src2;                  // BLTU
                    3'b111: take_branch = src1 >= src2;                 // BGEU
                    default: illegal = 1'b1;
                endcase
                if (take_branch && !illegal) next_pc = pc + imm_b;
            end
            7'b0000011: begin // load (RAM and MMIO)
                effective_addr = src1 + imm_i;
                case (f3)
                    3'b000, 3'b100: ; // LB, LBU
                    3'b001, 3'b101: misaligned_data = effective_addr[0]; // LH, LHU
                    3'b010: misaligned_data = |effective_addr[1:0]; // LW
                    default: illegal = 1'b1;
                endcase
                is_load = !illegal;
            end
            7'b0100011: begin // store (wstrb is within aligned 32-bit word)
                effective_addr = src1 + imm_s;
                case (f3)
                    3'b000: write_strobe = 4'b0001 << effective_addr[1:0]; // SB
                    3'b001: begin // SH
                        misaligned_data = effective_addr[0];
                        write_strobe = 4'b0011 << effective_addr[1:0];
                    end
                    3'b010: begin // SW
                        misaligned_data = |effective_addr[1:0];
                        write_strobe = 4'b1111;
                    end
                    default: illegal = 1'b1;
                endcase
                is_store = !illegal;
            end
            7'b0010011: begin // arithmetic immediate
                write_rd = 1'b1;
                case (f3)
                    3'b000: result = src1 + imm_i;                         // ADDI
                    3'b010: result = {31'd0, $signed(src1) < $signed(imm_i)}; // SLTI
                    3'b011: result = {31'd0, src1 < imm_i};              // SLTIU
                    3'b100: result = src1 ^ imm_i;                       // XORI
                    3'b110: result = src1 | imm_i;                       // ORI
                    3'b111: result = src1 & imm_i;                       // ANDI
                    3'b001: begin // SLLI
                        if (f7 != 7'b0000000) illegal = 1'b1;
                        else result = src1 << rs2;
                    end
                    3'b101: begin // SRLI/SRAI
                        if (f7 == 7'b0000000) result = src1 >> rs2;
                        else if (f7 == 7'b0100000) result = $signed(src1) >>> rs2;
                        else illegal = 1'b1;
                    end
                    default: illegal = 1'b1;
                endcase
            end
            7'b0110011: begin // arithmetic register
                write_rd = 1'b1;
                case ({f7, f3})
                    {7'b0000000, 3'b000}: result = src1 + src2; // ADD
                    {7'b0100000, 3'b000}: result = src1 - src2; // SUB
                    {7'b0000000, 3'b001}: result = src1 << src2[4:0]; // SLL
                    {7'b0000000, 3'b010}: result = {31'd0, $signed(src1) < $signed(src2)}; // SLT
                    {7'b0000000, 3'b011}: result = {31'd0, src1 < src2}; // SLTU
                    {7'b0000000, 3'b100}: result = src1 ^ src2; // XOR
                    {7'b0000000, 3'b101}: result = src1 >> src2[4:0]; // SRL
                    {7'b0100000, 3'b101}: result = $signed(src1) >>> src2[4:0]; // SRA
                    {7'b0000000, 3'b110}: result = src1 | src2; // OR
                    {7'b0000000, 3'b111}: result = src1 & src2; // AND
                    default: illegal = 1'b1;
                endcase
            end
            7'b0001111: begin // FENCE: no effect on a single in-order CPU
                if (f3 != 3'b000 || rd != 0 || rs1 != 0) illegal = 1'b1;
            end
            7'b1110011: begin // ECALL/EBREAK stop (no privilege runtime)
                if (insn == 32'h00000073) begin
                    system_stop = 1'b1;
                    system_reason = 4'd4;
                end else if (insn == 32'h00100073) begin
                    system_stop = 1'b1;
                    system_reason = 4'd5;
                end else illegal = 1'b1;
            end
            default: illegal = 1'b1;
        endcase
    end

    always @* begin
        mem_valid = 1'b0;
        mem_write = 1'b0;
        mem_addr = pc;
        mem_wdata = 32'd0;
        mem_wstrb = 4'b0000;
        if (!reset && !halted) begin
            if (state == FETCH) begin
                mem_valid = 1'b1;
            end else if (state == EXEC && (is_load || is_store) &&
                         !illegal && !misaligned_data) begin
                mem_valid = 1'b1;
                mem_write = is_store;
                mem_addr = effective_addr;
                mem_wdata = src2 << (8 * effective_addr[1:0]);
                mem_wstrb = is_store ? write_strobe : 4'b0000;
            end
        end
    end

    reg [4:0]  pending_rd;
    reg [2:0]  pending_f3;
    reg [1:0]  pending_byte;
    reg [31:0] pending_addr;
    reg [31:0] pending_insn;
    wire [31:0] shifted_load = mem_rdata >> (8 * pending_byte);
    reg [31:0] load_value;
    always @* begin
        case (pending_f3)
            3'b000: load_value = {{24{shifted_load[7]}}, shifted_load[7:0]};
            3'b001: load_value = {{16{shifted_load[15]}}, shifted_load[15:0]};
            3'b010: load_value = shifted_load;
            3'b100: load_value = {24'b0, shifted_load[7:0]};
            3'b101: load_value = {16'b0, shifted_load[15:0]};
            default: load_value = 32'd0;
        endcase
    end

    always @(posedge clk) begin
        if (reset) begin
            state <= FETCH;
            pc <= 32'd0;
            halted <= 1'b0;
            halt_reason <= 4'd0;
            trace_valid <= 1'b0;
            trace_pc <= 32'd0;
            trace_insn <= 32'd0;
            trace_rd <= 5'd0;
            trace_value <= 32'd0;
            trace_store_mask <= 4'd0;
            trace_store_addr <= 32'd0;
            trace_store_data <= 32'd0;
            pending_rd <= 5'd0;
            pending_f3 <= 3'd0;
            pending_byte <= 2'd0;
            pending_addr <= 32'd0;
            pending_insn <= 32'd0;
            for (i = 0; i < 32; i = i + 1) regs[i] <= 32'd0;
        end else begin
            trace_valid <= 1'b0;
            if (!halted) begin
                case (state)
                    FETCH: begin
                        // SoC samples mem_addr=pc on this edge.
                        state <= EXEC;
                    end
                    EXEC: begin
                        if (illegal || system_stop || misaligned_data || |next_pc[1:0]) begin
                            halted <= 1'b1;
                            if (illegal) halt_reason <= 4'd1;
                            else if (system_stop) halt_reason <= system_reason;
                            else if (misaligned_data) halt_reason <= 4'd3;
                            else halt_reason <= 4'd2;
                        end else if (is_load) begin
                            pending_rd <= rd;
                            pending_f3 <= f3;
                            pending_byte <= effective_addr[1:0];
                            pending_addr <= effective_addr;
                            pending_insn <= insn;
                            state <= LOAD_WB;
                        end else begin
                            if (write_rd && rd != 0) regs[rd] <= result;
                            pc <= next_pc;
                            state <= FETCH;
                            trace_valid <= 1'b1;
                            trace_pc <= pc;
                            trace_insn <= insn;
                            trace_rd <= (write_rd && rd != 0) ? rd : 5'd0;
                            trace_value <= (write_rd && rd != 0) ? result : 32'd0;
                            trace_store_mask <= is_store ? write_strobe : 4'd0;
                            trace_store_addr <= is_store ? effective_addr : 32'd0;
                            trace_store_data <= is_store ? (src2 << (8 * effective_addr[1:0])) : 32'd0;
                        end
                    end
                    LOAD_WB: begin
                        if (pending_rd != 0) regs[pending_rd] <= load_value;
                        pc <= pc + 32'd4;
                        state <= FETCH;
                        trace_valid <= 1'b1;
                        trace_pc <= pc;
                        trace_insn <= pending_insn;
                        trace_rd <= pending_rd;
                        trace_value <= (pending_rd != 0) ? load_value : 32'd0;
                        trace_store_mask <= 4'd0;
                        trace_store_addr <= 32'd0;
                        trace_store_data <= 32'd0;
                    end
                    default: begin
                        halted <= 1'b1;
                        halt_reason <= 4'd1;
                    end
                endcase
            end
        end
    end
endmodule
