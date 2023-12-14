/* The reproduction of Multer from wdzs

    This module is designed for generating Partial Product.
    
    Version list:
    1st version
        2022/08/14 by winetrs wen
*/

module PPGenerator(
    // output
    pp1, 
    pp2, 
    pp3, 
    pp4, 
    pp5, 
    pp6, 
    pp7, 
    pp8, 
    pp9,

    // inputs
    src1,
    src2,
    sign1,
    sign2 
);


output  [19:0]                          pp1;
output  [20:0]                          pp2;
output  [20:0]                          pp3;
output  [20:0]                          pp4;
output  [20:0]                          pp5;
output  [20:0]                          pp6;
output  [20:0]                          pp7;
output  [19:0]                          pp8;
output  [17:0]                          pp9;


input   [15:0]                          src1;
input   [15:0]                          src2;
input                                   sign1;
input                                   sign2;


wire    [19:0]                          pp1;
wire    [20:0]                          pp2;
wire    [20:0]                          pp3;
wire    [20:0]                          pp4;
wire    [20:0]                          pp5;
wire    [20:0]                          pp6;
wire    [20:0]                          pp7;
wire    [19:0]                          pp8;
wire    [17:0]                          pp9;


wire    [16:0]                          g0;
wire    [16:0]                          g1;
wire    [16:0]                          g2;
wire    [16:0]                          g3;
wire    [16:0]                          g4;
wire    [16:0]                          g5;
wire    [16:0]                          g6;
wire    [16:0]                          g7;
wire    [15:0]                          g8;


wire    [7:0]                           E;
wire    [7:0]                           S;


wire    [16:0]                          multi_num;
assign multi_num = {sign1 & src1[15], src1};


// take bits -1, 0, 1
PP_Decoder decode1(
    // input
    .src1               (multi_num),
    .p0                 (1'b0),
    .p1                 (src2[0]),
    .p2                 (src2[1]),
    // output
    .g                  (g0),
    .E                  (E[0]),
    .S                  (S[0])
);


// take bits 1, 2, 3
PP_Decoder decode2(
    // input
    .src1               (multi_num),
    .p0                 (src2[1]),
    .p1                 (src2[2]),
    .p2                 (src2[3]),
    // output
    .g                  (g1),
    .E                  (E[1]),
    .S                  (S[1])
);


// take bits 3, 4, 5
PP_Decoder decode3(
    // input
    .src1               (multi_num),
    .p0                 (src2[3]),
    .p1                 (src2[4]),
    .p2                 (src2[5]),
    // output
    .g                  (g2),
    .E                  (E[2]),
    .S                  (S[2])
);


// take bits 5, 6, 7
PP_Decoder decode4(
    // input
    .src1               (multi_num),
    .p0                 (src2[5]),
    .p1                 (src2[6]),
    .p2                 (src2[7]),
    // output
    .g                  (g3),
    .E                  (E[3]),
    .S                  (S[3])
);


// take bits 7, 8, 9
PP_Decoder decode5(
    // input
    .src1               (multi_num),
    .p0                 (src2[7]),
    .p1                 (src2[8]),
    .p2                 (src2[9]),
    // output
    .g                  (g4),
    .E                  (E[4]),
    .S                  (S[4])
);


// take bits 9, 10, 11
PP_Decoder decode6(
    // input
    .src1               (multi_num),
    .p0                 (src2[9]),
    .p1                 (src2[10]),
    .p2                 (src2[11]),
    // output
    .g                  (g5),
    .E                  (E[5]),
    .S                  (S[5])
);


// take bits 11, 12, 13
PP_Decoder decode7(
    // input
    .src1               (multi_num),
    .p0                 (src2[11]),
    .p1                 (src2[12]),
    .p2                 (src2[13]),
    // output
    .g                  (g6),
    .E                  (E[6]),
    .S                  (S[6])
);


// take bits 13, 14, 15
PP_Decoder decode8(
    // input
    .src1               (multi_num),
    .p0                 (src2[13]),
    .p1                 (src2[14]),
    .p2                 (src2[15]),
    // output
    .g                  (g7),
    .E                  (E[7]),
    .S                  (S[7])
);


// take bits 15, sign, extended sign
PP_Decoder_Last decode9(
    // input
    .src1               (src1),
    .p0                 (src2[15]),
    .sign               (sign2),
    // output
    .g                  (g8)
);


assign pp1 = {E[0], ~E[0], ~E[0], g0};
assign pp2 = {1'b1, E[1], g1, 1'b0, S[0]};
assign pp3 = {1'b1, E[2], g2, 1'b0, S[1]};
assign pp4 = {1'b1, E[3], g3, 1'b0, S[2]};
assign pp5 = {1'b1, E[4], g4, 1'b0, S[3]};
assign pp6 = {1'b1, E[5], g5, 1'b0, S[4]};
assign pp7 = {1'b1, E[6], g6, 1'b0, S[5]};
assign pp8 = {E[7], g7, 1'b0, S[6]};
assign pp9 = {g8, 1'b0, S[7]};


endmodule
