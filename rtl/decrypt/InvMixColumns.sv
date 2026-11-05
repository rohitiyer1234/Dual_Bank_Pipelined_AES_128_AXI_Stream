module InvMixColumns(inp,res);
    input  [127:0]inp;
    output [127:0]res;

    genvar i;
    generate
    for (i = 0;i < 4;i = i + 1)
    begin
        wire [7:0] s0;
        wire [7:0] s1;
        wire [7:0] s2;
        wire [7:0] s3;

        assign s0 = inp[127-32*i : 120-32*i];
        assign s1 = inp[119-32*i : 112-32*i];
        assign s2 = inp[111-32*i : 104-32*i];
        assign s3 = inp[103-32*i : 96-32*i];

        // Inverse MixColumns matrix (GF(2^8)):
        // | 0e 0b 0d 09 |
        // | 09 0e 0b 0d |
        // | 0d 09 0e 0b |
        // | 0b 0d 09 0e |
        assign res[127-32*i : 120-32*i] = mul14(s0) ^ mul11(s1) ^ mul13(s2) ^ mul9(s3);
        assign res[119-32*i : 112-32*i] = mul9(s0)  ^ mul14(s1) ^ mul11(s2) ^ mul13(s3);
        assign res[111-32*i : 104-32*i] = mul13(s0) ^ mul9(s1)  ^ mul14(s2) ^ mul11(s3);
        assign res[103-32*i :  96-32*i] = mul11(s0) ^ mul13(s1) ^ mul9(s2)  ^ mul14(s3);

    end
    endgenerate

    function automatic [7:0] mix2 (input [7:0]x);
        mix2 = (x << 1) ^ ( x[7] ? 8'h1B : 8'h0);
    endfunction

    function automatic [7:0] mix4 (input [7:0]x);
        mix4 = mix2(mix2(x));
    endfunction

    function automatic [7:0] mix8 (input [7:0]x);
        mix8 = mix2(mix4(x));
    endfunction

    // 9x  = 8x ^ x
    function automatic [7:0] mul9 (input [7:0]x);
        mul9 = mix8(x) ^ x;
    endfunction

    // 11x = 8x ^ 2x ^ x
    function automatic [7:0] mul11 (input [7:0]x);
        mul11 = mix8(x) ^ mix2(x) ^ x;
    endfunction

    // 13x = 8x ^ 4x ^ x
    function automatic [7:0] mul13 (input [7:0]x);
        mul13 = mix8(x) ^ mix4(x) ^ x;
    endfunction

    // 14x = 8x ^ 4x ^ 2x
    function automatic [7:0] mul14 (input [7:0]x);
        mul14 = mix8(x) ^ mix4(x) ^ mix2(x);
    endfunction

endmodule