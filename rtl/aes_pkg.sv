//-----------------------------------------------------------------------------
// Package
//-----------------------------------------------------------------------------
`timescale 1ns/1ps
package aes_pkg;
    localparam int NUM_ROUNDS  = 10;
    localparam int PIPE_DEPTH  = NUM_ROUNDS + 1;   // stages 0..10
    localparam int NUM_BANKS   = 2;
    localparam int KEY_FIFO_DEPTH = 4;

    // ------------------------------------------------------------------
    // KEY-CONTEXT GENERATION TAG
    // ------------------------------------------------------------------
    // Every accepted key push is stamped with a monotonically-incrementing
    // generation handle. That same handle is latched into the bank that
    // ends up storing the resulting round keys (keymem_dual.bank_gen[]).
    // A data transaction must present the handle it was told to expect
    // (key_gen) alongside current_bank; aes_top only accepts the
    // transaction if key_gen == bank_gen[current_bank]. This closes the
    // key/data synchronization hole: current_bank alone is just a
    // 1-bit slot index supplied by an external, potentially racy or
    // buggy master with no hardware guarantee it still refers to the
    // key that master originally intended. See aes_top.sv header and
    // docs/FIX_AND_BACKEND_README.md for the full rationale.
    // ------------------------------------------------------------------
    localparam int KEY_GEN_W = 16;
    typedef logic [KEY_GEN_W-1:0] key_gen_t;

    typedef logic [127:0] aes_block_t;
    typedef logic  [31:0] aes_word_t;
    typedef logic   [7:0] aes_byte_t;
    typedef aes_block_t   rk_bank_t  [0:NUM_ROUNDS];
    typedef rk_bank_t     rk_store_t [0:NUM_BANKS-1];
endpackage : aes_pkg