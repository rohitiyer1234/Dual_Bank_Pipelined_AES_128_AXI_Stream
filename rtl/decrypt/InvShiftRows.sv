module InvShiftRows(inp,out);
    input [127:0]inp;
    output [127:0]out;

    logic [7:0] b [15:0];
    assign {
        b[0],  b[1],  b[2],  b[3],
        b[4],  b[5],  b[6],  b[7],
        b[8],  b[9],  b[10], b[11],
        b[12], b[13], b[14], b[15]
    } = inp;

    // Exact inverse permutation of ShiftRows:
    //   ShiftRows: out[i] = b[perm[i]] with
    //     perm = {0,5,10,15, 4,9,14,3, 8,13,2,7, 12,1,6,11}
    //   InvShiftRows undoes that permutation.
    assign out = {
        b[0],  b[13], b[10], b[7],
        b[4],  b[1],  b[14], b[11],
        b[8],  b[5],  b[2],  b[15],
        b[12], b[9],  b[6],  b[3]
    };

endmodule