/* The reproduction of Multer from wdzs

    This module is the second level of adder-tree.
    
    Version list:
    1st version
        2022/08/14 by winetrs wen
*/

module Compressor_2nd(
    // input
    sum1_1,
    carry1_1,
    sum1_2,
    carry1_2,
    sum1_3,
    carry1_3,
    // output
    sum2_1,
    carry2_1,
    sum2_2,
    carry2_2
);


input   [22:0]                                          sum1_1;
input   [24:0]                                          sum1_2;
input   [21:0]                                          sum1_3;			//LL0819
input   [20:0]                                          carry1_1;
input   [20:0]                                          carry1_2;
input   [19:0]                                          carry1_3;

output   [28:0]                                          sum2_1;		//LL0819
output   [25:0]                                          sum2_2;		//LL0819
output   [21:0]                                          carry2_1;		//LL0819
output   [21:0]                                          carry2_2;		//LL0819


CSA3_2_3 adder0(
    // input
    .in1                            (sum1_1),
    .in2                            (carry1_1),
    .in3                            (sum1_2),
    // output
    .sum                            (sum2_1),
    .carry                          (carry2_1)
);


CSA3_2_4 adder1(
    // input
    .in1                            (carry1_2),
    .in2                            (sum1_3),
    .in3                            (carry1_3),
    // output
    .sum                            (sum2_2),
    .carry                          (carry2_2)
);


endmodule
