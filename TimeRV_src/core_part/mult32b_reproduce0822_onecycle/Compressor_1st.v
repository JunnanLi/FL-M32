/* The reproduction of Multer from wdzs

    This module is the first level of adder-tree.
    
    Version list:
    1st version
        2022/08/14 by winetrs wen
*/

module Compressor_1st(
    // input
    pp1,
    pp2,
    pp3,
    pp4,
    pp5,
    pp6,
    pp7,
    pp8,
    pp9,
    // output
    sum1_1,
    carry1_1,
    sum1_2,
    carry1_2,
    sum1_3,
    carry1_3
);


input   [19:0]                                      pp1;
input   [20:0]                                      pp2;
input   [20:0]                                      pp3;
input   [20:0]                                      pp4;
input   [20:0]                                      pp5;
input   [20:0]                                      pp6;
input   [20:0]                                      pp7;
input   [19:0]                                      pp8;
input   [17:0]                                      pp9;

output  [22:0]                                      sum1_1;
output  [24:0]                                      sum1_2;
output  [21:0]                                      sum1_3;
output  [20:0]                                      carry1_1;
output  [20:0]                                      carry1_2;
output  [19:0]                                      carry1_3;


CSA3_2_0    adder3_2_0(
    // input
    .in1                                        (pp1),
    .in2                                        (pp2),
    .in3                                        (pp3),
    // output
    .sum                                        (sum1_1),
    .carry                                      (carry1_1)
);


CSA3_2_1    adder3_2_1(
    // input
    .in1                                        (pp4),
    .in2                                        (pp5),
    .in3                                        (pp6),
    // output
    .sum                                        (sum1_2),
    .carry                                      (carry1_2)
);


CSA3_2_2    adder3_2_2(
    // input
    .in1                                        (pp7),
    .in2                                        (pp8),
    .in3                                        (pp9),
    // output
    .sum                                        (sum1_3),
    .carry                                      (carry1_3)
);


endmodule