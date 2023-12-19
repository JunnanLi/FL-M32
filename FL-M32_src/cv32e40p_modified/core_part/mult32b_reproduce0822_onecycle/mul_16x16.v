/* The reproduction of Multer from wdzs

    This module is designed for a 16bit x 16bit multiplier.
    This design is based on Booth multiply method.
    
    Version list:
    1st version
        2022/08/14 by winetrs wen
*/

module Mul_16x16(
    // input
    clk, 
    rst_n, 
 //   G_stall,
 //   valid,
    src1, 
    src2,
    sign1, 
    sign2,
    // output
    dst
);

input                                           clk;
input                                           rst_n;
//input						G_stall;
//input                                           valid;
input   [15:0]                                  src1;
input   [15:0]                                  src2;
input                                           sign1;
input                                           sign2;

output  [31:0]                                  dst;

wire    [19:0]                                  pp1;
wire    [20:0]                                  pp2;
wire    [20:0]                                  pp3;
wire    [20:0]                                  pp4;
wire    [20:0]                                  pp5;
wire    [20:0]                                  pp6;
wire    [20:0]                                  pp7;
wire    [19:0]                                  pp8;
wire    [17:0]                                  pp9;


PPGenerator ppgener(
    // output
    .pp1                            (pp1),
    .pp2                            (pp2),
    .pp3                            (pp3),
    .pp4                            (pp4),
    .pp5                            (pp5),
    .pp6                            (pp6),
    .pp7                            (pp7),
    .pp8                            (pp8),
    .pp9                            (pp9),
    // input
    .src1                           (src1),
    .src2                           (src2),
    .sign1                          (sign1),
    .sign2                          (sign2)
);


wire    [22:0]                                  sum1_1;
wire    [20:0]                                  carry1_1;
wire    [24:0]                                  sum1_2;
wire    [20:0]                                  carry1_2;
wire    [21:0]                                  sum1_3;
wire    [19:0]                                  carry1_3;

Compressor_1st adder_tree_l1(
    // input
    .pp1                            (pp1),
    .pp2                            (pp2),
    .pp3                            (pp3),
    .pp4                            (pp4),
    .pp5                            (pp5),
    .pp6                            (pp6),
    .pp7                            (pp7),
    .pp8                            (pp8),
    .pp9                            (pp9),
    // output
    .sum1_1                         (sum1_1),
    .sum1_2                         (sum1_2),
    .sum1_3                         (sum1_3),
    .carry1_1                       (carry1_1),
    .carry1_2                       (carry1_2),
    .carry1_3                       (carry1_3)
);


wire    [28:0]                                  sum2_1;
wire    [25:0]                                  sum2_2;
wire    [21:0]                                  carry2_1;
wire    [21:0]                                  carry2_2;

Compressor_2nd adder_tree_l2(
    // input
    .sum1_1                         (sum1_1),
    .sum1_2                         (sum1_2),
    .sum1_3                         (sum1_3),
    .carry1_1                       (carry1_1),
    .carry1_2                       (carry1_2),
    .carry1_3                       (carry1_3),
    // output
    .sum2_1                          (sum2_1),
    .sum2_2                          (sum2_2),
    .carry2_1                        (carry2_1),
    .carry2_2                        (carry2_2)
);


//wire    [28:0]                                  E1_sum2_1;
//wire    [25:0]                                  E1_sum2_2;
//wire    [21:0]                                  E1_carry2_1;
//wire    [21:0]                                  E1_carry2_2;


//Mul_senddown register_segment(
//    // input
 //   .clk                            (clk),
 //   .rst_n                          (rst_n),
 //   .G_stall                        (G_stall),
 //   .valid                          (valid),
 //   .sum2_1                         (sum2_1),
  //  .sum2_2                         (sum2_2),
  //  .carry2_1                       (carry2_1),
  //  .carry2_2                       (carry2_2),
    
    // output
 //   .E1_carry2_1                     (E1_carry2_1),
//    .E1_carry2_2                     (E1_carry2_2),
 //   .E1_sum2_1                       (E1_sum2_1),
 //   .E1_sum2_2                       (E1_sum2_2)
// );


wire    [32:0]                                  sum;
wire    [30:0]                                  carry;

Compressor_3rd  adder_tree_l3(
    // input
   // .in1                            (E1_sum2_1),
    //.in2                            (E1_carry2_1),
   // .in3                            (E1_sum2_2),
  //  .in4                            (E1_carry2_2),
   // input
    .in1                            (sum2_1),
    .in2                            (carry2_1),
    .in3                            (sum2_2),
    .in4                            (carry2_2),
    // output
    .sum                            (sum),
    .carry                          (carry)
);


wire    [31:0]                                  dst;
assign  dst = sum[31:0] + {carry[28:0], 3'b0};



endmodule
