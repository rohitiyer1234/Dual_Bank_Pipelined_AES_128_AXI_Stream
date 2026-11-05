`timescale 1ns/1ps
package aes_ref_pkg;
    import aes_pkg::*;
    
    localparam aes_block_t KEY0 =
    128'h2b7e151628aed2a6abf7158809cf4f3c;
    localparam aes_block_t KEY1 =
    128'h000102030405060708090a0b0c0d0e0f;
    typedef struct {

    aes_block_t pt;
    aes_block_t expected;
    logic       bank;

    } sb_item_t;


    
    function automatic aes_byte_t ref_sbox(input aes_byte_t b);
    case (b)
            8'h00:ref_sbox=8'h63;8'h01:ref_sbox=8'h7c;8'h02:ref_sbox=8'h77;8'h03:ref_sbox=8'h7b;
            8'h04:ref_sbox=8'hf2;8'h05:ref_sbox=8'h6b;8'h06:ref_sbox=8'h6f;8'h07:ref_sbox=8'hc5;
            8'h08:ref_sbox=8'h30;8'h09:ref_sbox=8'h01;8'h0a:ref_sbox=8'h67;8'h0b:ref_sbox=8'h2b;
            8'h0c:ref_sbox=8'hfe;8'h0d:ref_sbox=8'hd7;8'h0e:ref_sbox=8'hab;8'h0f:ref_sbox=8'h76;
            8'h10:ref_sbox=8'hca;8'h11:ref_sbox=8'h82;8'h12:ref_sbox=8'hc9;8'h13:ref_sbox=8'h7d;
            8'h14:ref_sbox=8'hfa;8'h15:ref_sbox=8'h59;8'h16:ref_sbox=8'h47;8'h17:ref_sbox=8'hf0;
            8'h18:ref_sbox=8'had;8'h19:ref_sbox=8'hd4;8'h1a:ref_sbox=8'ha2;8'h1b:ref_sbox=8'haf;
            8'h1c:ref_sbox=8'h9c;8'h1d:ref_sbox=8'ha4;8'h1e:ref_sbox=8'h72;8'h1f:ref_sbox=8'hc0;
            8'h20:ref_sbox=8'hb7;8'h21:ref_sbox=8'hfd;8'h22:ref_sbox=8'h93;8'h23:ref_sbox=8'h26;
            8'h24:ref_sbox=8'h36;8'h25:ref_sbox=8'h3f;8'h26:ref_sbox=8'hf7;8'h27:ref_sbox=8'hcc;
            8'h28:ref_sbox=8'h34;8'h29:ref_sbox=8'ha5;8'h2a:ref_sbox=8'he5;8'h2b:ref_sbox=8'hf1;
            8'h2c:ref_sbox=8'h71;8'h2d:ref_sbox=8'hd8;8'h2e:ref_sbox=8'h31;8'h2f:ref_sbox=8'h15;
            8'h30:ref_sbox=8'h04;8'h31:ref_sbox=8'hc7;8'h32:ref_sbox=8'h23;8'h33:ref_sbox=8'hc3;
            8'h34:ref_sbox=8'h18;8'h35:ref_sbox=8'h96;8'h36:ref_sbox=8'h05;8'h37:ref_sbox=8'h9a;
            8'h38:ref_sbox=8'h07;8'h39:ref_sbox=8'h12;8'h3a:ref_sbox=8'h80;8'h3b:ref_sbox=8'he2;
            8'h3c:ref_sbox=8'heb;8'h3d:ref_sbox=8'h27;8'h3e:ref_sbox=8'hb2;8'h3f:ref_sbox=8'h75;
            8'h40:ref_sbox=8'h09;8'h41:ref_sbox=8'h83;8'h42:ref_sbox=8'h2c;8'h43:ref_sbox=8'h1a;
            8'h44:ref_sbox=8'h1b;8'h45:ref_sbox=8'h6e;8'h46:ref_sbox=8'h5a;8'h47:ref_sbox=8'ha0;
            8'h48:ref_sbox=8'h52;8'h49:ref_sbox=8'h3b;8'h4a:ref_sbox=8'hd6;8'h4b:ref_sbox=8'hb3;
            8'h4c:ref_sbox=8'h29;8'h4d:ref_sbox=8'he3;8'h4e:ref_sbox=8'h2f;8'h4f:ref_sbox=8'h84;
            8'h50:ref_sbox=8'h53;8'h51:ref_sbox=8'hd1;8'h52:ref_sbox=8'h00;8'h53:ref_sbox=8'hed;
            8'h54:ref_sbox=8'h20;8'h55:ref_sbox=8'hfc;8'h56:ref_sbox=8'hb1;8'h57:ref_sbox=8'h5b;
            8'h58:ref_sbox=8'h6a;8'h59:ref_sbox=8'hcb;8'h5a:ref_sbox=8'hbe;8'h5b:ref_sbox=8'h39;
            8'h5c:ref_sbox=8'h4a;8'h5d:ref_sbox=8'h4c;8'h5e:ref_sbox=8'h58;8'h5f:ref_sbox=8'hcf;
            8'h60:ref_sbox=8'hd0;8'h61:ref_sbox=8'hef;8'h62:ref_sbox=8'haa;8'h63:ref_sbox=8'hfb;
            8'h64:ref_sbox=8'h43;8'h65:ref_sbox=8'h4d;8'h66:ref_sbox=8'h33;8'h67:ref_sbox=8'h85;
            8'h68:ref_sbox=8'h45;8'h69:ref_sbox=8'hf9;8'h6a:ref_sbox=8'h02;8'h6b:ref_sbox=8'h7f;
            8'h6c:ref_sbox=8'h50;8'h6d:ref_sbox=8'h3c;8'h6e:ref_sbox=8'h9f;8'h6f:ref_sbox=8'ha8;
            8'h70:ref_sbox=8'h51;8'h71:ref_sbox=8'ha3;8'h72:ref_sbox=8'h40;8'h73:ref_sbox=8'h8f;
            8'h74:ref_sbox=8'h92;8'h75:ref_sbox=8'h9d;8'h76:ref_sbox=8'h38;8'h77:ref_sbox=8'hf5;
            8'h78:ref_sbox=8'hbc;8'h79:ref_sbox=8'hb6;8'h7a:ref_sbox=8'hda;8'h7b:ref_sbox=8'h21;
            8'h7c:ref_sbox=8'h10;8'h7d:ref_sbox=8'hff;8'h7e:ref_sbox=8'hf3;8'h7f:ref_sbox=8'hd2;
            8'h80:ref_sbox=8'hcd;8'h81:ref_sbox=8'h0c;8'h82:ref_sbox=8'h13;8'h83:ref_sbox=8'hec;
            8'h84:ref_sbox=8'h5f;8'h85:ref_sbox=8'h97;8'h86:ref_sbox=8'h44;8'h87:ref_sbox=8'h17;
            8'h88:ref_sbox=8'hc4;8'h89:ref_sbox=8'ha7;8'h8a:ref_sbox=8'h7e;8'h8b:ref_sbox=8'h3d;
            8'h8c:ref_sbox=8'h64;8'h8d:ref_sbox=8'h5d;8'h8e:ref_sbox=8'h19;8'h8f:ref_sbox=8'h73;
            8'h90:ref_sbox=8'h60;8'h91:ref_sbox=8'h81;8'h92:ref_sbox=8'h4f;8'h93:ref_sbox=8'hdc;
            8'h94:ref_sbox=8'h22;8'h95:ref_sbox=8'h2a;8'h96:ref_sbox=8'h90;8'h97:ref_sbox=8'h88;
            8'h98:ref_sbox=8'h46;8'h99:ref_sbox=8'hee;8'h9a:ref_sbox=8'hb8;8'h9b:ref_sbox=8'h14;
            8'h9c:ref_sbox=8'hde;8'h9d:ref_sbox=8'h5e;8'h9e:ref_sbox=8'h0b;8'h9f:ref_sbox=8'hdb;
            8'ha0:ref_sbox=8'he0;8'ha1:ref_sbox=8'h32;8'ha2:ref_sbox=8'h3a;8'ha3:ref_sbox=8'h0a;
            8'ha4:ref_sbox=8'h49;8'ha5:ref_sbox=8'h06;8'ha6:ref_sbox=8'h24;8'ha7:ref_sbox=8'h5c;
            8'ha8:ref_sbox=8'hc2;8'ha9:ref_sbox=8'hd3;8'haa:ref_sbox=8'hac;8'hab:ref_sbox=8'h62;
            8'hac:ref_sbox=8'h91;8'had:ref_sbox=8'h95;8'hae:ref_sbox=8'he4;8'haf:ref_sbox=8'h79;
            8'hb0:ref_sbox=8'he7;8'hb1:ref_sbox=8'hc8;8'hb2:ref_sbox=8'h37;8'hb3:ref_sbox=8'h6d;
            8'hb4:ref_sbox=8'h8d;8'hb5:ref_sbox=8'hd5;8'hb6:ref_sbox=8'h4e;8'hb7:ref_sbox=8'ha9;
            8'hb8:ref_sbox=8'h6c;8'hb9:ref_sbox=8'h56;8'hba:ref_sbox=8'hf4;8'hbb:ref_sbox=8'hea;
            8'hbc:ref_sbox=8'h65;8'hbd:ref_sbox=8'h7a;8'hbe:ref_sbox=8'hae;8'hbf:ref_sbox=8'h08;
            8'hc0:ref_sbox=8'hba;8'hc1:ref_sbox=8'h78;8'hc2:ref_sbox=8'h25;8'hc3:ref_sbox=8'h2e;
            8'hc4:ref_sbox=8'h1c;8'hc5:ref_sbox=8'ha6;8'hc6:ref_sbox=8'hb4;8'hc7:ref_sbox=8'hc6;
            8'hc8:ref_sbox=8'he8;8'hc9:ref_sbox=8'hdd;8'hca:ref_sbox=8'h74;8'hcb:ref_sbox=8'h1f;
            8'hcc:ref_sbox=8'h4b;8'hcd:ref_sbox=8'hbd;8'hce:ref_sbox=8'h8b;8'hcf:ref_sbox=8'h8a;
            8'hd0:ref_sbox=8'h70;8'hd1:ref_sbox=8'h3e;8'hd2:ref_sbox=8'hb5;8'hd3:ref_sbox=8'h66;
            8'hd4:ref_sbox=8'h48;8'hd5:ref_sbox=8'h03;8'hd6:ref_sbox=8'hf6;8'hd7:ref_sbox=8'h0e;
            8'hd8:ref_sbox=8'h61;8'hd9:ref_sbox=8'h35;8'hda:ref_sbox=8'h57;8'hdb:ref_sbox=8'hb9;
            8'hdc:ref_sbox=8'h86;8'hdd:ref_sbox=8'hc1;8'hde:ref_sbox=8'h1d;8'hdf:ref_sbox=8'h9e;
            8'he0:ref_sbox=8'he1;8'he1:ref_sbox=8'hf8;8'he2:ref_sbox=8'h98;8'he3:ref_sbox=8'h11;
            8'he4:ref_sbox=8'h69;8'he5:ref_sbox=8'hd9;8'he6:ref_sbox=8'h8e;8'he7:ref_sbox=8'h94;
            8'he8:ref_sbox=8'h9b;8'he9:ref_sbox=8'h1e;8'hea:ref_sbox=8'h87;8'heb:ref_sbox=8'he9;
            8'hec:ref_sbox=8'hce;8'hed:ref_sbox=8'h55;8'hee:ref_sbox=8'h28;8'hef:ref_sbox=8'hdf;
            8'hf0:ref_sbox=8'h8c;8'hf1:ref_sbox=8'ha1;8'hf2:ref_sbox=8'h89;8'hf3:ref_sbox=8'h0d;
            8'hf4:ref_sbox=8'hbf;8'hf5:ref_sbox=8'he6;8'hf6:ref_sbox=8'h42;8'hf7:ref_sbox=8'h68;
            8'hf8:ref_sbox=8'h41;8'hf9:ref_sbox=8'h99;8'hfa:ref_sbox=8'h2d;8'hfb:ref_sbox=8'h0f;
            8'hfc:ref_sbox=8'hb0;8'hfd:ref_sbox=8'h54;8'hfe:ref_sbox=8'hbb;8'hff:ref_sbox=8'h16;
            default:ref_sbox=8'h00;
        endcase
    
    endfunction
    
function automatic aes_block_t ref_subbytes(input aes_block_t state);

    aes_block_t result;

    result = '0;

    for(int i=0;i<16;i++) begin
        result[127-8*i -: 8]
            = ref_sbox(state[127-8*i -: 8]);
    end

    return result;

endfunction
    
    function automatic aes_block_t ref_shiftrows(input aes_block_t state);
     aes_byte_t b[0:15];

    {
        b[0],b[1],b[2],b[3],
        b[4],b[5],b[6],b[7],
        b[8],b[9],b[10],b[11],
        b[12],b[13],b[14],b[15]
    } = state;

    return {
        b[0], b[5], b[10], b[15],
        b[4], b[9], b[14], b[3],
        b[8], b[13], b[2],  b[7],
        b[12],b[1], b[6],  b[11]
    };

    
    endfunction
    
    function automatic aes_byte_t xtime(input aes_byte_t x);

         return (x<<1) ^ (x[7] ? 8'h1B : 8'h00);

    endfunction
    
    function automatic logic [31:0] mix_column(
    input logic [31:0] col
);

    aes_byte_t s0,s1,s2,s3;

    logic [31:0] out;
    out = '0;

    s0 = col[31:24];
    s1 = col[23:16];
    s2 = col[15:8];
    s3 = col[7:0];

    out[31:24] =
        xtime(s0) ^
        (xtime(s1)^s1) ^
        s2 ^
        s3;

    out[23:16] =
        s0 ^
        xtime(s1) ^
        (xtime(s2)^s2) ^
        s3;

    out[15:8] =
        s0 ^
        s1 ^
        xtime(s2) ^
        (xtime(s3)^s3);

    out[7:0] =
        (xtime(s0)^s0) ^
        s1 ^
        s2 ^
        xtime(s3);

    return out;

    endfunction
    
    function automatic aes_block_t ref_mixcolumns(
    input aes_block_t state
);

    aes_block_t out;
    out = '0;

    for(int c=0;c<4;c++) begin

        out[127-32*c -: 32]
            =
        mix_column(
            state[127-32*c -: 32]
        );

    end

    return out;

    endfunction
    
    function automatic void ref_keyschedule(
        input  logic [127:0] key,
        output logic [127:0] rk [0:10]
    );
        logic [31:0] w [0:43];
       logic [7:0] rcon [0:9] = '{
         8'h01,8'h02,8'h04,8'h08,8'h10,
         8'h20,8'h40,8'h80,8'h1b,8'h36
};
        for (int i=0;i<4;i++) w[i]=key[127-32*i -: 32];
        for (int i=4;i<44;i++) begin
            logic [31:0] tmp=w[i-1];
            if (i%4==0) begin
                tmp={tmp[23:0],tmp[31:24]};
                tmp[31:24]=ref_sbox(tmp[31:24]);
                tmp[23:16]=ref_sbox(tmp[23:16]);
                tmp[15:8] =ref_sbox(tmp[15:8]);
                tmp[7:0]  =ref_sbox(tmp[7:0]);
                tmp[31:24]^=rcon[(i/4)-1];
            end
            w[i]=w[i-4]^tmp;
        end
        for (int r=0;r<=10;r++)
            rk[r]={w[4*r],w[4*r+1],w[4*r+2],w[4*r+3]};
    endfunction


    function automatic aes_block_t ref_aes128(
    input aes_block_t plaintext,
    input aes_block_t key
);

    aes_block_t rk [0:10];
    aes_block_t s;

    ref_keyschedule(key,rk);

    //---------------------------------
    // Initial AddRoundKey
    //---------------------------------

    s = plaintext ^ rk[0];

    //---------------------------------
    // Rounds 1-9
    //---------------------------------

    for(int r=1;r<=9;r++) begin

        s = ref_subbytes(s);
        s = ref_shiftrows(s);
        s = ref_mixcolumns(s);
        s = s ^ rk[r];

    end

    //---------------------------------
    // Final Round
    //---------------------------------

    s = ref_subbytes(s);
    s = ref_shiftrows(s);
    s = s ^ rk[10];

    return s;

endfunction

function automatic aes_block_t ref_encrypt_bank(
    input aes_block_t pt,
    input logic       bank
);

    aes_block_t key;

begin

    key = bank ? KEY1 : KEY0;

    return ref_aes128(pt,key);

end

endfunction
    

    // ========================================================================
    // DECRYPT ADD-ONS
    // ========================================================================

    // Inverse S-box (exact functional inverse of ref_sbox: ref_inv_sbox(ref_sbox(x)) == x)
    function automatic aes_byte_t ref_inv_sbox(input aes_byte_t b);
    case (b)
8'h00:ref_inv_sbox=8'h52;8'h01:ref_inv_sbox=8'h09;8'h02:ref_inv_sbox=8'h6a;8'h03:ref_inv_sbox=8'hd5;
8'h04:ref_inv_sbox=8'h30;8'h05:ref_inv_sbox=8'h36;8'h06:ref_inv_sbox=8'ha5;8'h07:ref_inv_sbox=8'h38;
8'h08:ref_inv_sbox=8'hbf;8'h09:ref_inv_sbox=8'h40;8'h0a:ref_inv_sbox=8'ha3;8'h0b:ref_inv_sbox=8'h9e;
8'h0c:ref_inv_sbox=8'h81;8'h0d:ref_inv_sbox=8'hf3;8'h0e:ref_inv_sbox=8'hd7;8'h0f:ref_inv_sbox=8'hfb;
8'h10:ref_inv_sbox=8'h7c;8'h11:ref_inv_sbox=8'he3;8'h12:ref_inv_sbox=8'h39;8'h13:ref_inv_sbox=8'h82;
8'h14:ref_inv_sbox=8'h9b;8'h15:ref_inv_sbox=8'h2f;8'h16:ref_inv_sbox=8'hff;8'h17:ref_inv_sbox=8'h87;
8'h18:ref_inv_sbox=8'h34;8'h19:ref_inv_sbox=8'h8e;8'h1a:ref_inv_sbox=8'h43;8'h1b:ref_inv_sbox=8'h44;
8'h1c:ref_inv_sbox=8'hc4;8'h1d:ref_inv_sbox=8'hde;8'h1e:ref_inv_sbox=8'he9;8'h1f:ref_inv_sbox=8'hcb;
8'h20:ref_inv_sbox=8'h54;8'h21:ref_inv_sbox=8'h7b;8'h22:ref_inv_sbox=8'h94;8'h23:ref_inv_sbox=8'h32;
8'h24:ref_inv_sbox=8'ha6;8'h25:ref_inv_sbox=8'hc2;8'h26:ref_inv_sbox=8'h23;8'h27:ref_inv_sbox=8'h3d;
8'h28:ref_inv_sbox=8'hee;8'h29:ref_inv_sbox=8'h4c;8'h2a:ref_inv_sbox=8'h95;8'h2b:ref_inv_sbox=8'h0b;
8'h2c:ref_inv_sbox=8'h42;8'h2d:ref_inv_sbox=8'hfa;8'h2e:ref_inv_sbox=8'hc3;8'h2f:ref_inv_sbox=8'h4e;
8'h30:ref_inv_sbox=8'h08;8'h31:ref_inv_sbox=8'h2e;8'h32:ref_inv_sbox=8'ha1;8'h33:ref_inv_sbox=8'h66;
8'h34:ref_inv_sbox=8'h28;8'h35:ref_inv_sbox=8'hd9;8'h36:ref_inv_sbox=8'h24;8'h37:ref_inv_sbox=8'hb2;
8'h38:ref_inv_sbox=8'h76;8'h39:ref_inv_sbox=8'h5b;8'h3a:ref_inv_sbox=8'ha2;8'h3b:ref_inv_sbox=8'h49;
8'h3c:ref_inv_sbox=8'h6d;8'h3d:ref_inv_sbox=8'h8b;8'h3e:ref_inv_sbox=8'hd1;8'h3f:ref_inv_sbox=8'h25;
8'h40:ref_inv_sbox=8'h72;8'h41:ref_inv_sbox=8'hf8;8'h42:ref_inv_sbox=8'hf6;8'h43:ref_inv_sbox=8'h64;
8'h44:ref_inv_sbox=8'h86;8'h45:ref_inv_sbox=8'h68;8'h46:ref_inv_sbox=8'h98;8'h47:ref_inv_sbox=8'h16;
8'h48:ref_inv_sbox=8'hd4;8'h49:ref_inv_sbox=8'ha4;8'h4a:ref_inv_sbox=8'h5c;8'h4b:ref_inv_sbox=8'hcc;
8'h4c:ref_inv_sbox=8'h5d;8'h4d:ref_inv_sbox=8'h65;8'h4e:ref_inv_sbox=8'hb6;8'h4f:ref_inv_sbox=8'h92;
8'h50:ref_inv_sbox=8'h6c;8'h51:ref_inv_sbox=8'h70;8'h52:ref_inv_sbox=8'h48;8'h53:ref_inv_sbox=8'h50;
8'h54:ref_inv_sbox=8'hfd;8'h55:ref_inv_sbox=8'hed;8'h56:ref_inv_sbox=8'hb9;8'h57:ref_inv_sbox=8'hda;
8'h58:ref_inv_sbox=8'h5e;8'h59:ref_inv_sbox=8'h15;8'h5a:ref_inv_sbox=8'h46;8'h5b:ref_inv_sbox=8'h57;
8'h5c:ref_inv_sbox=8'ha7;8'h5d:ref_inv_sbox=8'h8d;8'h5e:ref_inv_sbox=8'h9d;8'h5f:ref_inv_sbox=8'h84;
8'h60:ref_inv_sbox=8'h90;8'h61:ref_inv_sbox=8'hd8;8'h62:ref_inv_sbox=8'hab;8'h63:ref_inv_sbox=8'h00;
8'h64:ref_inv_sbox=8'h8c;8'h65:ref_inv_sbox=8'hbc;8'h66:ref_inv_sbox=8'hd3;8'h67:ref_inv_sbox=8'h0a;
8'h68:ref_inv_sbox=8'hf7;8'h69:ref_inv_sbox=8'he4;8'h6a:ref_inv_sbox=8'h58;8'h6b:ref_inv_sbox=8'h05;
8'h6c:ref_inv_sbox=8'hb8;8'h6d:ref_inv_sbox=8'hb3;8'h6e:ref_inv_sbox=8'h45;8'h6f:ref_inv_sbox=8'h06;
8'h70:ref_inv_sbox=8'hd0;8'h71:ref_inv_sbox=8'h2c;8'h72:ref_inv_sbox=8'h1e;8'h73:ref_inv_sbox=8'h8f;
8'h74:ref_inv_sbox=8'hca;8'h75:ref_inv_sbox=8'h3f;8'h76:ref_inv_sbox=8'h0f;8'h77:ref_inv_sbox=8'h02;
8'h78:ref_inv_sbox=8'hc1;8'h79:ref_inv_sbox=8'haf;8'h7a:ref_inv_sbox=8'hbd;8'h7b:ref_inv_sbox=8'h03;
8'h7c:ref_inv_sbox=8'h01;8'h7d:ref_inv_sbox=8'h13;8'h7e:ref_inv_sbox=8'h8a;8'h7f:ref_inv_sbox=8'h6b;
8'h80:ref_inv_sbox=8'h3a;8'h81:ref_inv_sbox=8'h91;8'h82:ref_inv_sbox=8'h11;8'h83:ref_inv_sbox=8'h41;
8'h84:ref_inv_sbox=8'h4f;8'h85:ref_inv_sbox=8'h67;8'h86:ref_inv_sbox=8'hdc;8'h87:ref_inv_sbox=8'hea;
8'h88:ref_inv_sbox=8'h97;8'h89:ref_inv_sbox=8'hf2;8'h8a:ref_inv_sbox=8'hcf;8'h8b:ref_inv_sbox=8'hce;
8'h8c:ref_inv_sbox=8'hf0;8'h8d:ref_inv_sbox=8'hb4;8'h8e:ref_inv_sbox=8'he6;8'h8f:ref_inv_sbox=8'h73;
8'h90:ref_inv_sbox=8'h96;8'h91:ref_inv_sbox=8'hac;8'h92:ref_inv_sbox=8'h74;8'h93:ref_inv_sbox=8'h22;
8'h94:ref_inv_sbox=8'he7;8'h95:ref_inv_sbox=8'had;8'h96:ref_inv_sbox=8'h35;8'h97:ref_inv_sbox=8'h85;
8'h98:ref_inv_sbox=8'he2;8'h99:ref_inv_sbox=8'hf9;8'h9a:ref_inv_sbox=8'h37;8'h9b:ref_inv_sbox=8'he8;
8'h9c:ref_inv_sbox=8'h1c;8'h9d:ref_inv_sbox=8'h75;8'h9e:ref_inv_sbox=8'hdf;8'h9f:ref_inv_sbox=8'h6e;
8'ha0:ref_inv_sbox=8'h47;8'ha1:ref_inv_sbox=8'hf1;8'ha2:ref_inv_sbox=8'h1a;8'ha3:ref_inv_sbox=8'h71;
8'ha4:ref_inv_sbox=8'h1d;8'ha5:ref_inv_sbox=8'h29;8'ha6:ref_inv_sbox=8'hc5;8'ha7:ref_inv_sbox=8'h89;
8'ha8:ref_inv_sbox=8'h6f;8'ha9:ref_inv_sbox=8'hb7;8'haa:ref_inv_sbox=8'h62;8'hab:ref_inv_sbox=8'h0e;
8'hac:ref_inv_sbox=8'haa;8'had:ref_inv_sbox=8'h18;8'hae:ref_inv_sbox=8'hbe;8'haf:ref_inv_sbox=8'h1b;
8'hb0:ref_inv_sbox=8'hfc;8'hb1:ref_inv_sbox=8'h56;8'hb2:ref_inv_sbox=8'h3e;8'hb3:ref_inv_sbox=8'h4b;
8'hb4:ref_inv_sbox=8'hc6;8'hb5:ref_inv_sbox=8'hd2;8'hb6:ref_inv_sbox=8'h79;8'hb7:ref_inv_sbox=8'h20;
8'hb8:ref_inv_sbox=8'h9a;8'hb9:ref_inv_sbox=8'hdb;8'hba:ref_inv_sbox=8'hc0;8'hbb:ref_inv_sbox=8'hfe;
8'hbc:ref_inv_sbox=8'h78;8'hbd:ref_inv_sbox=8'hcd;8'hbe:ref_inv_sbox=8'h5a;8'hbf:ref_inv_sbox=8'hf4;
8'hc0:ref_inv_sbox=8'h1f;8'hc1:ref_inv_sbox=8'hdd;8'hc2:ref_inv_sbox=8'ha8;8'hc3:ref_inv_sbox=8'h33;
8'hc4:ref_inv_sbox=8'h88;8'hc5:ref_inv_sbox=8'h07;8'hc6:ref_inv_sbox=8'hc7;8'hc7:ref_inv_sbox=8'h31;
8'hc8:ref_inv_sbox=8'hb1;8'hc9:ref_inv_sbox=8'h12;8'hca:ref_inv_sbox=8'h10;8'hcb:ref_inv_sbox=8'h59;
8'hcc:ref_inv_sbox=8'h27;8'hcd:ref_inv_sbox=8'h80;8'hce:ref_inv_sbox=8'hec;8'hcf:ref_inv_sbox=8'h5f;
8'hd0:ref_inv_sbox=8'h60;8'hd1:ref_inv_sbox=8'h51;8'hd2:ref_inv_sbox=8'h7f;8'hd3:ref_inv_sbox=8'ha9;
8'hd4:ref_inv_sbox=8'h19;8'hd5:ref_inv_sbox=8'hb5;8'hd6:ref_inv_sbox=8'h4a;8'hd7:ref_inv_sbox=8'h0d;
8'hd8:ref_inv_sbox=8'h2d;8'hd9:ref_inv_sbox=8'he5;8'hda:ref_inv_sbox=8'h7a;8'hdb:ref_inv_sbox=8'h9f;
8'hdc:ref_inv_sbox=8'h93;8'hdd:ref_inv_sbox=8'hc9;8'hde:ref_inv_sbox=8'h9c;8'hdf:ref_inv_sbox=8'hef;
8'he0:ref_inv_sbox=8'ha0;8'he1:ref_inv_sbox=8'he0;8'he2:ref_inv_sbox=8'h3b;8'he3:ref_inv_sbox=8'h4d;
8'he4:ref_inv_sbox=8'hae;8'he5:ref_inv_sbox=8'h2a;8'he6:ref_inv_sbox=8'hf5;8'he7:ref_inv_sbox=8'hb0;
8'he8:ref_inv_sbox=8'hc8;8'he9:ref_inv_sbox=8'heb;8'hea:ref_inv_sbox=8'hbb;8'heb:ref_inv_sbox=8'h3c;
8'hec:ref_inv_sbox=8'h83;8'hed:ref_inv_sbox=8'h53;8'hee:ref_inv_sbox=8'h99;8'hef:ref_inv_sbox=8'h61;
8'hf0:ref_inv_sbox=8'h17;8'hf1:ref_inv_sbox=8'h2b;8'hf2:ref_inv_sbox=8'h04;8'hf3:ref_inv_sbox=8'h7e;
8'hf4:ref_inv_sbox=8'hba;8'hf5:ref_inv_sbox=8'h77;8'hf6:ref_inv_sbox=8'hd6;8'hf7:ref_inv_sbox=8'h26;
8'hf8:ref_inv_sbox=8'he1;8'hf9:ref_inv_sbox=8'h69;8'hfa:ref_inv_sbox=8'h14;8'hfb:ref_inv_sbox=8'h63;
8'hfc:ref_inv_sbox=8'h55;8'hfd:ref_inv_sbox=8'h21;8'hfe:ref_inv_sbox=8'h0c;8'hff:ref_inv_sbox=8'h7d;
            default: ref_inv_sbox = 8'h00;
        endcase

    endfunction

    function automatic aes_block_t ref_invsubbytes(input aes_block_t state);

        aes_block_t result;

        result = '0;

        for(int i=0;i<16;i++) begin
            result[127-8*i -: 8]
                = ref_inv_sbox(state[127-8*i -: 8]);
        end

        return result;

    endfunction

    // Exact inverse permutation of ref_shiftrows
    function automatic aes_block_t ref_invshiftrows(input aes_block_t state);
        aes_byte_t b[0:15];

        {
            b[0],b[1],b[2],b[3],
            b[4],b[5],b[6],b[7],
            b[8],b[9],b[10],b[11],
            b[12],b[13],b[14],b[15]
        } = state;

        return {
            b[0], b[13], b[10], b[7],
            b[4], b[1],  b[14], b[11],
            b[8], b[5],  b[2],  b[15],
            b[12],b[9],  b[6],  b[3]
        };

    endfunction

    function automatic aes_byte_t mul9(input aes_byte_t x);
        return xtime(xtime(xtime(x))) ^ x;
    endfunction

    function automatic aes_byte_t mul11(input aes_byte_t x);
        return xtime(xtime(xtime(x))) ^ xtime(x) ^ x;
    endfunction

    function automatic aes_byte_t mul13(input aes_byte_t x);
        return xtime(xtime(xtime(x))) ^ xtime(xtime(x)) ^ x;
    endfunction

    function automatic aes_byte_t mul14(input aes_byte_t x);
        return xtime(xtime(xtime(x))) ^ xtime(xtime(x)) ^ xtime(x);
    endfunction

    function automatic logic [31:0] inv_mix_column(
        input logic [31:0] col
    );

        aes_byte_t s0,s1,s2,s3;

        logic [31:0] out;
        out = '0;

        s0 = col[31:24];
        s1 = col[23:16];
        s2 = col[15:8];
        s3 = col[7:0];

        // | 0e 0b 0d 09 |
        // | 09 0e 0b 0d |
        // | 0d 09 0e 0b |
        // | 0b 0d 09 0e |
        out[31:24] = mul14(s0) ^ mul11(s1) ^ mul13(s2) ^ mul9(s3);
        out[23:16] = mul9(s0)  ^ mul14(s1) ^ mul11(s2) ^ mul13(s3);
        out[15:8]  = mul13(s0) ^ mul9(s1)  ^ mul14(s2) ^ mul11(s3);
        out[7:0]   = mul11(s0) ^ mul13(s1) ^ mul9(s2)  ^ mul14(s3);

        return out;

    endfunction

    function automatic aes_block_t ref_invmixcolumns(
        input aes_block_t state
    );

        aes_block_t out;
        out = '0;

        for(int c=0;c<4;c++) begin

            out[127-32*c -: 32]
                =
            inv_mix_column(
                state[127-32*c -: 32]
            );

        end

        return out;

    endfunction

    function automatic aes_block_t ref_aes128_decrypt(
        input aes_block_t ciphertext,
        input aes_block_t key
    );

        aes_block_t rk [0:10];
        aes_block_t s;

        ref_keyschedule(key,rk);

        //---------------------------------
        // Undo final AddRoundKey (K10)
        //---------------------------------

        s = ciphertext ^ rk[10];

        //---------------------------------
        // Rounds 9 downto 1
        //---------------------------------

        for(int r=9;r>=1;r--) begin

            s = ref_invshiftrows(s);
            s = ref_invsubbytes(s);
            s = s ^ rk[r];
            s = ref_invmixcolumns(s);

        end

        //---------------------------------
        // Final Round (undo initial ARK, K0)
        //---------------------------------

        s = ref_invshiftrows(s);
        s = ref_invsubbytes(s);
        s = s ^ rk[0];

        return s;

    endfunction

    function automatic aes_block_t ref_decrypt_bank(
        input aes_block_t ct,
        input logic       bank
    );

        aes_block_t key;

    begin

        key = bank ? KEY1 : KEY0;

        return ref_aes128_decrypt(ct,key);

    end

    endfunction

endpackage

// ============================================================================
//  aes_ref_pkg.sv
//
//  Standalone, from-scratch software AES-128 reference model (FIPS-197),
//  used as the golden model for tb_aes_top's scoreboard. Independent of
//  the RTL: its own S-box/inverse S-box tables, its own key schedule, its
//  own GF(2^8) MixColumns/InvMixColumns arithmetic.
// ============================================================================
/*
`timescale 1ns/1ps

package aes_ref_pkg;

    import aes_pkg::*;

    // ------------------------------------------------------------------
    // Forward / inverse S-boxes
    // ------------------------------------------------------------------
    function automatic aes_byte_t r_sbox(input aes_byte_t a);
        case (a)
            8'h00:r_sbox=8'h63; 8'h01:r_sbox=8'h7c; 8'h02:r_sbox=8'h77; 8'h03:r_sbox=8'h7b;
            8'h04:r_sbox=8'hf2; 8'h05:r_sbox=8'h6b; 8'h06:r_sbox=8'h6f; 8'h07:r_sbox=8'hc5;
            8'h08:r_sbox=8'h30; 8'h09:r_sbox=8'h01; 8'h0a:r_sbox=8'h67; 8'h0b:r_sbox=8'h2b;
            8'h0c:r_sbox=8'hfe; 8'h0d:r_sbox=8'hd7; 8'h0e:r_sbox=8'hab; 8'h0f:r_sbox=8'h76;
            8'h10:r_sbox=8'hca; 8'h11:r_sbox=8'h82; 8'h12:r_sbox=8'hc9; 8'h13:r_sbox=8'h7d;
            8'h14:r_sbox=8'hfa; 8'h15:r_sbox=8'h59; 8'h16:r_sbox=8'h47; 8'h17:r_sbox=8'hf0;
            8'h18:r_sbox=8'had; 8'h19:r_sbox=8'hd4; 8'h1a:r_sbox=8'ha2; 8'h1b:r_sbox=8'haf;
            8'h1c:r_sbox=8'h9c; 8'h1d:r_sbox=8'ha4; 8'h1e:r_sbox=8'h72; 8'h1f:r_sbox=8'hc0;
            8'h20:r_sbox=8'hb7; 8'h21:r_sbox=8'hfd; 8'h22:r_sbox=8'h93; 8'h23:r_sbox=8'h26;
            8'h24:r_sbox=8'h36; 8'h25:r_sbox=8'h3f; 8'h26:r_sbox=8'hf7; 8'h27:r_sbox=8'hcc;
            8'h28:r_sbox=8'h34; 8'h29:r_sbox=8'ha5; 8'h2a:r_sbox=8'he5; 8'h2b:r_sbox=8'hf1;
            8'h2c:r_sbox=8'h71; 8'h2d:r_sbox=8'hd8; 8'h2e:r_sbox=8'h31; 8'h2f:r_sbox=8'h15;
            8'h30:r_sbox=8'h04; 8'h31:r_sbox=8'hc7; 8'h32:r_sbox=8'h23; 8'h33:r_sbox=8'hc3;
            8'h34:r_sbox=8'h18; 8'h35:r_sbox=8'h96; 8'h36:r_sbox=8'h05; 8'h37:r_sbox=8'h9a;
            8'h38:r_sbox=8'h07; 8'h39:r_sbox=8'h12; 8'h3a:r_sbox=8'h80; 8'h3b:r_sbox=8'he2;
            8'h3c:r_sbox=8'heb; 8'h3d:r_sbox=8'h27; 8'h3e:r_sbox=8'hb2; 8'h3f:r_sbox=8'h75;
            8'h40:r_sbox=8'h09; 8'h41:r_sbox=8'h83; 8'h42:r_sbox=8'h2c; 8'h43:r_sbox=8'h1a;
            8'h44:r_sbox=8'h1b; 8'h45:r_sbox=8'h6e; 8'h46:r_sbox=8'h5a; 8'h47:r_sbox=8'ha0;
            8'h48:r_sbox=8'h52; 8'h49:r_sbox=8'h3b; 8'h4a:r_sbox=8'hd6; 8'h4b:r_sbox=8'hb3;
            8'h4c:r_sbox=8'h29; 8'h4d:r_sbox=8'he3; 8'h4e:r_sbox=8'h2f; 8'h4f:r_sbox=8'h84;
            8'h50:r_sbox=8'h53; 8'h51:r_sbox=8'hd1; 8'h52:r_sbox=8'h00; 8'h53:r_sbox=8'hed;
            8'h54:r_sbox=8'h20; 8'h55:r_sbox=8'hfc; 8'h56:r_sbox=8'hb1; 8'h57:r_sbox=8'h5b;
            8'h58:r_sbox=8'h6a; 8'h59:r_sbox=8'hcb; 8'h5a:r_sbox=8'hbe; 8'h5b:r_sbox=8'h39;
            8'h5c:r_sbox=8'h4a; 8'h5d:r_sbox=8'h4c; 8'h5e:r_sbox=8'h58; 8'h5f:r_sbox=8'hcf;
            8'h60:r_sbox=8'hd0; 8'h61:r_sbox=8'hef; 8'h62:r_sbox=8'haa; 8'h63:r_sbox=8'hfb;
            8'h64:r_sbox=8'h43; 8'h65:r_sbox=8'h4d; 8'h66:r_sbox=8'h33; 8'h67:r_sbox=8'h85;
            8'h68:r_sbox=8'h45; 8'h69:r_sbox=8'hf9; 8'h6a:r_sbox=8'h02; 8'h6b:r_sbox=8'h7f;
            8'h6c:r_sbox=8'h50; 8'h6d:r_sbox=8'h3c; 8'h6e:r_sbox=8'h9f; 8'h6f:r_sbox=8'ha8;
            8'h70:r_sbox=8'h51; 8'h71:r_sbox=8'ha3; 8'h72:r_sbox=8'h40; 8'h73:r_sbox=8'h8f;
            8'h74:r_sbox=8'h92; 8'h75:r_sbox=8'h9d; 8'h76:r_sbox=8'h38; 8'h77:r_sbox=8'hf5;
            8'h78:r_sbox=8'hbc; 8'h79:r_sbox=8'hb6; 8'h7a:r_sbox=8'hda; 8'h7b:r_sbox=8'h21;
            8'h7c:r_sbox=8'h10; 8'h7d:r_sbox=8'hff; 8'h7e:r_sbox=8'hf3; 8'h7f:r_sbox=8'hd2;
            8'h80:r_sbox=8'hcd; 8'h81:r_sbox=8'h0c; 8'h82:r_sbox=8'h13; 8'h83:r_sbox=8'hec;
            8'h84:r_sbox=8'h5f; 8'h85:r_sbox=8'h97; 8'h86:r_sbox=8'h44; 8'h87:r_sbox=8'h17;
            8'h88:r_sbox=8'hc4; 8'h89:r_sbox=8'ha7; 8'h8a:r_sbox=8'h7e; 8'h8b:r_sbox=8'h3d;
            8'h8c:r_sbox=8'h64; 8'h8d:r_sbox=8'h5d; 8'h8e:r_sbox=8'h19; 8'h8f:r_sbox=8'h73;
            8'h90:r_sbox=8'h60; 8'h91:r_sbox=8'h81; 8'h92:r_sbox=8'h4f; 8'h93:r_sbox=8'hdc;
            8'h94:r_sbox=8'h22; 8'h95:r_sbox=8'h2a; 8'h96:r_sbox=8'h90; 8'h97:r_sbox=8'h88;
            8'h98:r_sbox=8'h46; 8'h99:r_sbox=8'hee; 8'h9a:r_sbox=8'hb8; 8'h9b:r_sbox=8'h14;
            8'h9c:r_sbox=8'hde; 8'h9d:r_sbox=8'h5e; 8'h9e:r_sbox=8'h0b; 8'h9f:r_sbox=8'hdb;
            8'ha0:r_sbox=8'he0; 8'ha1:r_sbox=8'h32; 8'ha2:r_sbox=8'h3a; 8'ha3:r_sbox=8'h0a;
            8'ha4:r_sbox=8'h49; 8'ha5:r_sbox=8'h06; 8'ha6:r_sbox=8'h24; 8'ha7:r_sbox=8'h5c;
            8'ha8:r_sbox=8'hc2; 8'ha9:r_sbox=8'hd3; 8'haa:r_sbox=8'hac; 8'hab:r_sbox=8'h62;
            8'hac:r_sbox=8'h91; 8'had:r_sbox=8'h95; 8'hae:r_sbox=8'he4; 8'haf:r_sbox=8'h79;
            8'hb0:r_sbox=8'he7; 8'hb1:r_sbox=8'hc8; 8'hb2:r_sbox=8'h37; 8'hb3:r_sbox=8'h6d;
            8'hb4:r_sbox=8'h8d; 8'hb5:r_sbox=8'hd5; 8'hb6:r_sbox=8'h4e; 8'hb7:r_sbox=8'ha9;
            8'hb8:r_sbox=8'h6c; 8'hb9:r_sbox=8'h56; 8'hba:r_sbox=8'hf4; 8'hbb:r_sbox=8'hea;
            8'hbc:r_sbox=8'h65; 8'hbd:r_sbox=8'h7a; 8'hbe:r_sbox=8'hae; 8'hbf:r_sbox=8'h08;
            8'hc0:r_sbox=8'hba; 8'hc1:r_sbox=8'h78; 8'hc2:r_sbox=8'h25; 8'hc3:r_sbox=8'h2e;
            8'hc4:r_sbox=8'h1c; 8'hc5:r_sbox=8'ha6; 8'hc6:r_sbox=8'hb4; 8'hc7:r_sbox=8'hc6;
            8'hc8:r_sbox=8'he8; 8'hc9:r_sbox=8'hdd; 8'hca:r_sbox=8'h74; 8'hcb:r_sbox=8'h1f;
            8'hcc:r_sbox=8'h4b; 8'hcd:r_sbox=8'hbd; 8'hce:r_sbox=8'h8b; 8'hcf:r_sbox=8'h8a;
            8'hd0:r_sbox=8'h70; 8'hd1:r_sbox=8'h3e; 8'hd2:r_sbox=8'hb5; 8'hd3:r_sbox=8'h66;
            8'hd4:r_sbox=8'h48; 8'hd5:r_sbox=8'h03; 8'hd6:r_sbox=8'hf6; 8'hd7:r_sbox=8'h0e;
            8'hd8:r_sbox=8'h61; 8'hd9:r_sbox=8'h35; 8'hda:r_sbox=8'h57; 8'hdb:r_sbox=8'hb9;
            8'hdc:r_sbox=8'h86; 8'hdd:r_sbox=8'hc1; 8'hde:r_sbox=8'h1d; 8'hdf:r_sbox=8'h9e;
            8'he0:r_sbox=8'he1; 8'he1:r_sbox=8'hf8; 8'he2:r_sbox=8'h98; 8'he3:r_sbox=8'h11;
            8'he4:r_sbox=8'h69; 8'he5:r_sbox=8'hd9; 8'he6:r_sbox=8'h8e; 8'he7:r_sbox=8'h94;
            8'he8:r_sbox=8'h9b; 8'he9:r_sbox=8'h1e; 8'hea:r_sbox=8'h87; 8'heb:r_sbox=8'he9;
            8'hec:r_sbox=8'hce; 8'hed:r_sbox=8'h55; 8'hee:r_sbox=8'h28; 8'hef:r_sbox=8'hdf;
            8'hf0:r_sbox=8'h8c; 8'hf1:r_sbox=8'ha1; 8'hf2:r_sbox=8'h89; 8'hf3:r_sbox=8'h0d;
            8'hf4:r_sbox=8'hbf; 8'hf5:r_sbox=8'he6; 8'hf6:r_sbox=8'h42; 8'hf7:r_sbox=8'h68;
            8'hf8:r_sbox=8'h41; 8'hf9:r_sbox=8'h99; 8'hfa:r_sbox=8'h2d; 8'hfb:r_sbox=8'h0f;
            8'hfc:r_sbox=8'hb0; 8'hfd:r_sbox=8'h54; 8'hfe:r_sbox=8'hbb; 8'hff:r_sbox=8'h16;
            default: r_sbox = 8'h00;
        endcase
    endfunction

    function automatic aes_byte_t r_inv_sbox(input aes_byte_t a);
        // Built by inverting r_sbox once at elaboration via a lookup search
        // would need a loop-with-break (unsupported on Icarus); instead
        // this is the standard published AES inverse S-box table.
        case (a)
            8'h00:r_inv_sbox=8'h52; 8'h01:r_inv_sbox=8'h09; 8'h02:r_inv_sbox=8'h6a; 8'h03:r_inv_sbox=8'hd5;
            8'h04:r_inv_sbox=8'h30; 8'h05:r_inv_sbox=8'h36; 8'h06:r_inv_sbox=8'ha5; 8'h07:r_inv_sbox=8'h38;
            8'h08:r_inv_sbox=8'hbf; 8'h09:r_inv_sbox=8'h40; 8'h0a:r_inv_sbox=8'ha3; 8'h0b:r_inv_sbox=8'h9e;
            8'h0c:r_inv_sbox=8'h81; 8'h0d:r_inv_sbox=8'hf3; 8'h0e:r_inv_sbox=8'hd7; 8'h0f:r_inv_sbox=8'hfb;
            8'h10:r_inv_sbox=8'h7c; 8'h11:r_inv_sbox=8'he3; 8'h12:r_inv_sbox=8'h39; 8'h13:r_inv_sbox=8'h82;
            8'h14:r_inv_sbox=8'h9b; 8'h15:r_inv_sbox=8'h2f; 8'h16:r_inv_sbox=8'hff; 8'h17:r_inv_sbox=8'h87;
            8'h18:r_inv_sbox=8'h34; 8'h19:r_inv_sbox=8'h8e; 8'h1a:r_inv_sbox=8'h43; 8'h1b:r_inv_sbox=8'h44;
            8'h1c:r_inv_sbox=8'hc4; 8'h1d:r_inv_sbox=8'hde; 8'h1e:r_inv_sbox=8'he9; 8'h1f:r_inv_sbox=8'hcb;
            8'h20:r_inv_sbox=8'h54; 8'h21:r_inv_sbox=8'h7b; 8'h22:r_inv_sbox=8'h94; 8'h23:r_inv_sbox=8'h32;
            8'h24:r_inv_sbox=8'ha6; 8'h25:r_inv_sbox=8'hc2; 8'h26:r_inv_sbox=8'h23; 8'h27:r_inv_sbox=8'h3d;
            8'h28:r_inv_sbox=8'hee; 8'h29:r_inv_sbox=8'h4c; 8'h2a:r_inv_sbox=8'h95; 8'h2b:r_inv_sbox=8'h0b;
            8'h2c:r_inv_sbox=8'h42; 8'h2d:r_inv_sbox=8'hfa; 8'h2e:r_inv_sbox=8'hc3; 8'h2f:r_inv_sbox=8'h4e;
            8'h30:r_inv_sbox=8'h08; 8'h31:r_inv_sbox=8'h2e; 8'h32:r_inv_sbox=8'ha1; 8'h33:r_inv_sbox=8'h66;
            8'h34:r_inv_sbox=8'h28; 8'h35:r_inv_sbox=8'hd9; 8'h36:r_inv_sbox=8'h24; 8'h37:r_inv_sbox=8'hb2;
            8'h38:r_inv_sbox=8'h76; 8'h39:r_inv_sbox=8'h5b; 8'h3a:r_inv_sbox=8'ha2; 8'h3b:r_inv_sbox=8'h49;
            8'h3c:r_inv_sbox=8'h6d; 8'h3d:r_inv_sbox=8'h8b; 8'h3e:r_inv_sbox=8'hd1; 8'h3f:r_inv_sbox=8'h25;
            8'h40:r_inv_sbox=8'h72; 8'h41:r_inv_sbox=8'hf8; 8'h42:r_inv_sbox=8'hf6; 8'h43:r_inv_sbox=8'h64;
            8'h44:r_inv_sbox=8'h86; 8'h45:r_inv_sbox=8'h68; 8'h46:r_inv_sbox=8'h98; 8'h47:r_inv_sbox=8'h16;
            8'h48:r_inv_sbox=8'hd4; 8'h49:r_inv_sbox=8'ha4; 8'h4a:r_inv_sbox=8'h5c; 8'h4b:r_inv_sbox=8'hcc;
            8'h4c:r_inv_sbox=8'h5d; 8'h4d:r_inv_sbox=8'h65; 8'h4e:r_inv_sbox=8'hb6; 8'h4f:r_inv_sbox=8'h92;
            8'h50:r_inv_sbox=8'h6c; 8'h51:r_inv_sbox=8'h70; 8'h52:r_inv_sbox=8'h48; 8'h53:r_inv_sbox=8'h50;
            8'h54:r_inv_sbox=8'hfd; 8'h55:r_inv_sbox=8'hed; 8'h56:r_inv_sbox=8'hb9; 8'h57:r_inv_sbox=8'hda;
            8'h58:r_inv_sbox=8'h5e; 8'h59:r_inv_sbox=8'h15; 8'h5a:r_inv_sbox=8'h46; 8'h5b:r_inv_sbox=8'h57;
            8'h5c:r_inv_sbox=8'ha7; 8'h5d:r_inv_sbox=8'h8d; 8'h5e:r_inv_sbox=8'h9d; 8'h5f:r_inv_sbox=8'h84;
            8'h60:r_inv_sbox=8'h90; 8'h61:r_inv_sbox=8'hd8; 8'h62:r_inv_sbox=8'hab; 8'h63:r_inv_sbox=8'h00;
            8'h64:r_inv_sbox=8'h8c; 8'h65:r_inv_sbox=8'hbc; 8'h66:r_inv_sbox=8'hd3; 8'h67:r_inv_sbox=8'h0a;
            8'h68:r_inv_sbox=8'hf7; 8'h69:r_inv_sbox=8'he4; 8'h6a:r_inv_sbox=8'h58; 8'h6b:r_inv_sbox=8'h05;
            8'h6c:r_inv_sbox=8'hb8; 8'h6d:r_inv_sbox=8'hb3; 8'h6e:r_inv_sbox=8'h45; 8'h6f:r_inv_sbox=8'h06;
            8'h70:r_inv_sbox=8'hd0; 8'h71:r_inv_sbox=8'h2c; 8'h72:r_inv_sbox=8'h1e; 8'h73:r_inv_sbox=8'h8f;
            8'h74:r_inv_sbox=8'hca; 8'h75:r_inv_sbox=8'h3f; 8'h76:r_inv_sbox=8'h0f; 8'h77:r_inv_sbox=8'h02;
            8'h78:r_inv_sbox=8'hc1; 8'h79:r_inv_sbox=8'haf; 8'h7a:r_inv_sbox=8'hbd; 8'h7b:r_inv_sbox=8'h03;
            8'h7c:r_inv_sbox=8'h01; 8'h7d:r_inv_sbox=8'h13; 8'h7e:r_inv_sbox=8'h8a; 8'h7f:r_inv_sbox=8'h6b;
            8'h80:r_inv_sbox=8'h3a; 8'h81:r_inv_sbox=8'h91; 8'h82:r_inv_sbox=8'h11; 8'h83:r_inv_sbox=8'h41;
            8'h84:r_inv_sbox=8'h4f; 8'h85:r_inv_sbox=8'h67; 8'h86:r_inv_sbox=8'hdc; 8'h87:r_inv_sbox=8'hea;
            8'h88:r_inv_sbox=8'h97; 8'h89:r_inv_sbox=8'hf2; 8'h8a:r_inv_sbox=8'hcf; 8'h8b:r_inv_sbox=8'hce;
            8'h8c:r_inv_sbox=8'hf0; 8'h8d:r_inv_sbox=8'hb4; 8'h8e:r_inv_sbox=8'he6; 8'h8f:r_inv_sbox=8'h73;
            8'h90:r_inv_sbox=8'h96; 8'h91:r_inv_sbox=8'hac; 8'h92:r_inv_sbox=8'h74; 8'h93:r_inv_sbox=8'h22;
            8'h94:r_inv_sbox=8'he7; 8'h95:r_inv_sbox=8'had; 8'h96:r_inv_sbox=8'h35; 8'h97:r_inv_sbox=8'h85;
            8'h98:r_inv_sbox=8'he2; 8'h99:r_inv_sbox=8'hf9; 8'h9a:r_inv_sbox=8'h37; 8'h9b:r_inv_sbox=8'he8;
            8'h9c:r_inv_sbox=8'h1c; 8'h9d:r_inv_sbox=8'h75; 8'h9e:r_inv_sbox=8'hdf; 8'h9f:r_inv_sbox=8'h6e;
            8'ha0:r_inv_sbox=8'h47; 8'ha1:r_inv_sbox=8'hf1; 8'ha2:r_inv_sbox=8'h1a; 8'ha3:r_inv_sbox=8'h71;
            8'ha4:r_inv_sbox=8'h1d; 8'ha5:r_inv_sbox=8'h29; 8'ha6:r_inv_sbox=8'hc5; 8'ha7:r_inv_sbox=8'h89;
            8'ha8:r_inv_sbox=8'h6f; 8'ha9:r_inv_sbox=8'hb7; 8'haa:r_inv_sbox=8'h62; 8'hab:r_inv_sbox=8'h0e;
            8'hac:r_inv_sbox=8'haa; 8'had:r_inv_sbox=8'h18; 8'hae:r_inv_sbox=8'hbe; 8'haf:r_inv_sbox=8'h1b;
            8'hb0:r_inv_sbox=8'hfc; 8'hb1:r_inv_sbox=8'h56; 8'hb2:r_inv_sbox=8'h3e; 8'hb3:r_inv_sbox=8'h4b;
            8'hb4:r_inv_sbox=8'hc6; 8'hb5:r_inv_sbox=8'hd2; 8'hb6:r_inv_sbox=8'h79; 8'hb7:r_inv_sbox=8'h20;
            8'hb8:r_inv_sbox=8'h9a; 8'hb9:r_inv_sbox=8'hdb; 8'hba:r_inv_sbox=8'hc0; 8'hbb:r_inv_sbox=8'hfe;
            8'hbc:r_inv_sbox=8'h78; 8'hbd:r_inv_sbox=8'hcd; 8'hbe:r_inv_sbox=8'h5a; 8'hbf:r_inv_sbox=8'hf4;
            8'hc0:r_inv_sbox=8'h1f; 8'hc1:r_inv_sbox=8'hdd; 8'hc2:r_inv_sbox=8'ha8; 8'hc3:r_inv_sbox=8'h33;
            8'hc4:r_inv_sbox=8'h88; 8'hc5:r_inv_sbox=8'h07; 8'hc6:r_inv_sbox=8'hc7; 8'hc7:r_inv_sbox=8'h31;
            8'hc8:r_inv_sbox=8'hb1; 8'hc9:r_inv_sbox=8'h12; 8'hca:r_inv_sbox=8'h10; 8'hcb:r_inv_sbox=8'h59;
            8'hcc:r_inv_sbox=8'h27; 8'hcd:r_inv_sbox=8'h80; 8'hce:r_inv_sbox=8'hec; 8'hcf:r_inv_sbox=8'h5f;
            8'hd0:r_inv_sbox=8'h60; 8'hd1:r_inv_sbox=8'h51; 8'hd2:r_inv_sbox=8'h7f; 8'hd3:r_inv_sbox=8'ha9;
            8'hd4:r_inv_sbox=8'h19; 8'hd5:r_inv_sbox=8'hb5; 8'hd6:r_inv_sbox=8'h4a; 8'hd7:r_inv_sbox=8'h0d;
            8'hd8:r_inv_sbox=8'h2d; 8'hd9:r_inv_sbox=8'he5; 8'hda:r_inv_sbox=8'h7a; 8'hdb:r_inv_sbox=8'h9f;
            8'hdc:r_inv_sbox=8'h93; 8'hdd:r_inv_sbox=8'hc9; 8'hde:r_inv_sbox=8'h9c; 8'hdf:r_inv_sbox=8'hef;
            8'he0:r_inv_sbox=8'ha0; 8'he1:r_inv_sbox=8'he0; 8'he2:r_inv_sbox=8'h3b; 8'he3:r_inv_sbox=8'h4d;
            8'he4:r_inv_sbox=8'hae; 8'he5:r_inv_sbox=8'h2a; 8'he6:r_inv_sbox=8'hf5; 8'he7:r_inv_sbox=8'hb0;
            8'he8:r_inv_sbox=8'hc8; 8'he9:r_inv_sbox=8'heb; 8'hea:r_inv_sbox=8'hbb; 8'heb:r_inv_sbox=8'h3c;
            8'hec:r_inv_sbox=8'h83; 8'hed:r_inv_sbox=8'h53; 8'hee:r_inv_sbox=8'h99; 8'hef:r_inv_sbox=8'h61;
            8'hf0:r_inv_sbox=8'h17; 8'hf1:r_inv_sbox=8'h2b; 8'hf2:r_inv_sbox=8'h04; 8'hf3:r_inv_sbox=8'h7e;
            8'hf4:r_inv_sbox=8'hba; 8'hf5:r_inv_sbox=8'h77; 8'hf6:r_inv_sbox=8'hd6; 8'hf7:r_inv_sbox=8'h26;
            8'hf8:r_inv_sbox=8'he1; 8'hf9:r_inv_sbox=8'h69; 8'hfa:r_inv_sbox=8'h14; 8'hfb:r_inv_sbox=8'h63;
            8'hfc:r_inv_sbox=8'h55; 8'hfd:r_inv_sbox=8'h21; 8'hfe:r_inv_sbox=8'h0c; 8'hff:r_inv_sbox=8'h7d;
            default: r_inv_sbox = 8'h00;
        endcase
    endfunction

    function automatic aes_byte_t r_rcon(input int r);
        case (r)
            1:r_rcon=8'h01; 2:r_rcon=8'h02; 3:r_rcon=8'h04; 4:r_rcon=8'h08; 5:r_rcon=8'h10;
            6:r_rcon=8'h20; 7:r_rcon=8'h40; 8:r_rcon=8'h80; 9:r_rcon=8'h1b; 10:r_rcon=8'h36;
            default: r_rcon = 8'h00;
        endcase
    endfunction

    // GF(2^8) xtime (multiply by 2 mod the AES polynomial)
    function automatic aes_byte_t xtime(input aes_byte_t a);
        xtime = (a[7]) ? ((a << 1) ^ 8'h1b) : (a << 1);
    endfunction

    function automatic aes_byte_t gmul(input aes_byte_t a, input aes_byte_t b);
        aes_byte_t p, aa, bb;
        p  = 8'h00; aa = a; bb = b;
        for (int i = 0; i < 8; i++) begin
            if (bb[0]) p = p ^ aa;
            aa = xtime(aa);
            bb = bb >> 1;
        end
        gmul = p;
    endfunction

    // ------------------------------------------------------------------
    // Key schedule -> populates a 0:10 array of 128-bit round keys.
    // Written as a task with a ref argument (not a function with an
    // array output port) - Icarus Verilog does not accept unpacked
    // array function output ports; `ref` task arguments work fine and
    // avoid a wasteful array copy either way.
    // ------------------------------------------------------------------
    // Package-level scratch array: side-effect output instead of an
    // array ref/output task port, which Icarus does not accept cleanly.
    aes_block_t g_rk[0:10];

    task automatic ref_key_schedule(input aes_block_t key);
        aes_word_t w[0:43];
        w[0] = key[127:96]; w[1] = key[95:64]; w[2] = key[63:32]; w[3] = key[31:0];
        for (int i = 4; i < 44; i++) begin
            aes_word_t temp = w[i-1];
            if (i % 4 == 0) begin
                aes_word_t rotw = {temp[23:0], temp[31:24]};
                temp = {r_sbox(rotw[31:24]), r_sbox(rotw[23:16]), r_sbox(rotw[15:8]), r_sbox(rotw[7:0])}
                       ^ {r_rcon(i/4), 24'h0};
            end
            w[i] = w[i-4] ^ temp;
        end
        for (int r = 0; r <= 10; r++)
            g_rk[r] = {w[4*r], w[4*r+1], w[4*r+2], w[4*r+3]};
    endtask

    // ------------------------------------------------------------------
    // Full AES-128 encrypt / decrypt (single block, FIPS-197 5.1 / 5.3)
    // State layout: 128-bit block treated as 16 bytes, byte[0] = MSB.
    // ------------------------------------------------------------------
    task automatic ref_encrypt(input aes_block_t pt, input aes_block_t key, output aes_block_t ct_out);
        aes_byte_t s[0:15];
        ref_key_schedule(key);
        for (int i = 0; i < 16; i++) s[i] = pt[127-8*i -: 8];

        // Initial AddRoundKey
        for (int i = 0; i < 16; i++) s[i] = s[i] ^ g_rk[0][127-8*i -: 8];

        for (int round = 1; round <= 10; round++) begin
            aes_byte_t sb[0:15], sr[0:15];
            // SubBytes
            for (int i = 0; i < 16; i++) sb[i] = r_sbox(s[i]);
            // ShiftRows (column-major 4x4: index = col*4+row)
            for (int c = 0; c < 4; c++) begin
                sr[c*4+0] = sb[((c+0)%4)*4+0];
                sr[c*4+1] = sb[((c+1)%4)*4+1];
                sr[c*4+2] = sb[((c+2)%4)*4+2];
                sr[c*4+3] = sb[((c+3)%4)*4+3];
            end
            if (round < 10) begin
                // MixColumns
                for (int c = 0; c < 4; c++) begin
                    aes_byte_t a0,a1,a2,a3;
                    a0=sr[c*4+0]; a1=sr[c*4+1]; a2=sr[c*4+2]; a3=sr[c*4+3];
                    s[c*4+0] = gmul(a0,8'h02) ^ gmul(a1,8'h03) ^ a2 ^ a3;
                    s[c*4+1] = a0 ^ gmul(a1,8'h02) ^ gmul(a2,8'h03) ^ a3;
                    s[c*4+2] = a0 ^ a1 ^ gmul(a2,8'h02) ^ gmul(a3,8'h03);
                    s[c*4+3] = gmul(a0,8'h03) ^ a1 ^ a2 ^ gmul(a3,8'h02);
                end
            end else begin
                for (int i = 0; i < 16; i++) s[i] = sr[i];
            end
            // AddRoundKey
            for (int i = 0; i < 16; i++) s[i] = s[i] ^ g_rk[round][127-8*i -: 8];
        end

        for (int i = 0; i < 16; i++) ct_out[127-8*i -: 8] = s[i];
    endtask

    task automatic ref_decrypt(input aes_block_t ct, input aes_block_t key, output aes_block_t pt_out);
        aes_byte_t s[0:15];
        ref_key_schedule(key);
        for (int i = 0; i < 16; i++) s[i] = ct[127-8*i -: 8];

        for (int i = 0; i < 16; i++) s[i] = s[i] ^ g_rk[10][127-8*i -: 8];

        for (int round = 9; round >= 0; round--) begin
            aes_byte_t isr[0:15], isb[0:15], ark[0:15];
            // InvShiftRows
            for (int c = 0; c < 4; c++) begin
                isr[c*4+0] = s[((c+0)%4)*4+0];
                isr[c*4+1] = s[((c-1+4)%4)*4+1];
                isr[c*4+2] = s[((c-2+4)%4)*4+2];
                isr[c*4+3] = s[((c-3+4)%4)*4+3];
            end
            // InvSubBytes
            for (int i = 0; i < 16; i++) isb[i] = r_inv_sbox(isr[i]);
            // AddRoundKey
            for (int i = 0; i < 16; i++) ark[i] = isb[i] ^ g_rk[round][127-8*i -: 8];
            if (round > 0) begin
                // InvMixColumns
                for (int c = 0; c < 4; c++) begin
                    aes_byte_t a0,a1,a2,a3;
                    a0=ark[c*4+0]; a1=ark[c*4+1]; a2=ark[c*4+2]; a3=ark[c*4+3];
                    s[c*4+0] = gmul(a0,8'h0e) ^ gmul(a1,8'h0b) ^ gmul(a2,8'h0d) ^ gmul(a3,8'h09);
                    s[c*4+1] = gmul(a0,8'h09) ^ gmul(a1,8'h0e) ^ gmul(a2,8'h0b) ^ gmul(a3,8'h0d);
                    s[c*4+2] = gmul(a0,8'h0d) ^ gmul(a1,8'h09) ^ gmul(a2,8'h0e) ^ gmul(a3,8'h0b);
                    s[c*4+3] = gmul(a0,8'h0b) ^ gmul(a1,8'h0d) ^ gmul(a2,8'h09) ^ gmul(a3,8'h0e);
                end
            end else begin
                for (int i = 0; i < 16; i++) s[i] = ark[i];
            end
        end

        for (int i = 0; i < 16; i++) pt_out[127-8*i -: 8] = s[i];
    endtask

endpackage : aes_ref_pkg
*/