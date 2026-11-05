module MixColumns(inp,res);
    input [127:0]inp;
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
     
        assign res[127-32*i : 120-32*i] = mix2(s0) ^ mix3(s1) ^   s2     ^    s3     ;
        assign res[119-32*i : 112-32*i] =     s0   ^ mix2(s1) ^ mix3(s2) ^    s3     ;
        assign res[111-32*i : 104-32*i] =     s0   ^   s1     ^ mix2(s2) ^   mix3(s3);
        assign res[103-32*i :  96-32*i] = mix3(s0) ^   s1     ^    s2    ^   mix2(s3);

              
    end   
    endgenerate
    function automatic [7:0]mix2 (input [7:0]x);
    mix2 = (x << 1) ^ ( x[7] ? 8'h1B : 8'h0);
    endfunction
    
    function automatic [7:0]mix3 (input [7:0]x);
    mix3 = mix2(x) ^ x;
    endfunction
endmodule