/* The reproduction of Multer from wdzs

    This module is the third level of adder-tree.
    
    Version list:
    1st version
        2022/08/14 by winetrs wen
*/

module Compressor_3rd(
    // input
    in1,
    in2,
    in3,
    in4,

    // output
    sum,
    carry
);


input   [28:0]                                      in1;
input   [21:0]                                      in2;
input   [25:0]                                      in3;
input   [21:0]                                      in4;

output  [32:0]                                      sum;
output  [30:0]                                      carry;


wire    [18:0]                                      cout;
assign cout[0] = 'b0;

assign sum[0] = in1[0];
assign sum[1] = in1[1];
assign {carry[0], sum[2]} = in1[2] + in2[0];
assign {carry[1], sum[3]} = in1[3] + in2[1];
assign {carry[2], sum[4]} = in1[4] + in2[2];
assign {carry[3], sum[5]} = in1[5] + in2[3];
assign {carry[4], sum[6]} = in1[6] + in2[4];


CSA3_2 adder0(
    // input
    .in1                            (in1[7]),
    .in2                            (in2[5]),
    .in3                            (in3[0]),
    // output
    .sum                            (sum[7]),
    .carry                          (carry[5])
);


CSA3_2 adder1(
    // input
    .in1                            (in1[8]),
    .in2                            (in2[6]),
    .in3                            (in3[1]),
    // output
    .sum                            (sum[8]),
    .carry                          (carry[6])
);


CSA3_2 adder2(
    // input
    .in1                            (in1[9]),
    .in2                            (in2[7]),
    .in3                            (in3[2]),
    // output
    .sum                            (sum[9]),
    .carry                          (carry[7])
);


CSA3_2 adder3(
    // input
    .in1                            (in1[10]),
    .in2                            (in2[8]),
    .in3                            (in3[3]),
    // output
    .sum                            (sum[10]),
    .carry                          (carry[8])
);


CSA4_2 adder4_2_0(
    // output
    .sum                            (sum[11]),
    .carry                          (carry[9]),
    .cout                           (cout[1]),
    // input
    .in1                            (in1[11]),
    .in2                            (in2[9]),
    .in3                            (in3[4]),
    .in4                            (in4[0]),
    .cin                            (cout[0])
);


CSA4_2 adder4_2_1(
    // output
    .sum                            (sum[12]),
    .carry                          (carry[10]),
    .cout                           (cout[2]),
    // input
    .in1                            (in1[12]),
    .in2                            (in2[10]),
    .in3                            (in3[5]),
    .in4                            (in4[1]),
    .cin                            (cout[1])
);


CSA4_2 adder4_2_2(
    // output
    .sum                            (sum[13]),
    .carry                          (carry[11]),
    .cout                           (cout[3]),
    // input
    .in1                            (in1[13]),
    .in2                            (in2[11]),
    .in3                            (in3[6]),
    .in4                            (in4[2]),
    .cin                            (cout[2])
);


CSA4_2 adder4_2_3(
    // output
    .sum                            (sum[14]),
    .carry                          (carry[12]),
    .cout                           (cout[4]),
    // input
    .in1                            (in1[14]),
    .in2                            (in2[12]),
    .in3                            (in3[7]),
    .in4                            (in4[3]),
    .cin                            (cout[3])
);


CSA4_2 adder4_2_4(
    // output
    .sum                            (sum[15]),
    .carry                          (carry[13]),
    .cout                           (cout[5]),
    // input
    .in1                            (in1[15]),
    .in2                            (in2[13]),
    .in3                            (in3[8]),
    .in4                            (in4[4]),
    .cin                            (cout[4])
);


CSA4_2 adder4_2_5(
    // output
    .sum                            (sum[16]),
    .carry                          (carry[14]),
    .cout                           (cout[6]),
    // input
    .in1                            (in1[16]),
    .in2                            (in2[14]),
    .in3                            (in3[9]),
    .in4                            (in4[5]),
    .cin                            (cout[5])
);


CSA4_2 adder4_2_6(
    // output
    .sum                            (sum[17]),
    .carry                          (carry[15]),
    .cout                           (cout[7]),
    // input
    .in1                            (in1[17]),
    .in2                            (in2[15]),
    .in3                            (in3[10]),
    .in4                            (in4[6]),
    .cin                            (cout[6])
);


CSA4_2 adder4_2_7(
    // output
    .sum                            (sum[18]),
    .carry                          (carry[16]),
    .cout                           (cout[8]),
    // input
    .in1                            (in1[18]),
    .in2                            (in2[16]),
    .in3                            (in3[11]),
    .in4                            (in4[7]),
    .cin                            (cout[7])
);


CSA4_2 adder4_2_8(
    // output
    .sum                            (sum[19]),
    .carry                          (carry[17]),
    .cout                           (cout[9]),
    // input
    .in1                            (in1[19]),
    .in2                            (in2[17]),
    .in3                            (in3[12]),
    .in4                            (in4[8]),
    .cin                            (cout[8])
);


CSA4_2 adder4_2_9(
    // output
    .sum                            (sum[20]),
    .carry                          (carry[18]),
    .cout                           (cout[10]),
    // input
    .in1                            (in1[20]),
    .in2                            (in2[18]),
    .in3                            (in3[13]),
    .in4                            (in4[9]),
    .cin                            (cout[9])
);


CSA4_2 adder4_2_10(
    // output
    .sum                            (sum[21]),
    .carry                          (carry[19]),
    .cout                           (cout[11]),
    // input
    .in1                            (in1[21]),
    .in2                            (in2[19]),
    .in3                            (in3[14]),
    .in4                            (in4[10]),
    .cin                            (cout[10])
);


CSA4_2 adder4_2_11(
    // output
    .sum                            (sum[22]),
    .carry                          (carry[20]),
    .cout                           (cout[12]),
    // input
    .in1                            (in1[22]),
    .in2                            (in2[20]),
    .in3                            (in3[15]),
    .in4                            (in4[11]),
    .cin                            (cout[11])
);


CSA4_2 adder4_2_12(
    // output
    .sum                            (sum[23]),
    .carry                          (carry[21]),
    .cout                           (cout[13]),
    // input
    .in1                            (in1[23]),
    .in2                            (in2[21]),
    .in3                            (in3[16]),
    .in4                            (in4[12]),
    .cin                            (cout[12])
);


CSA4_2 adder4_2_13(
    // output
    .sum                            (sum[24]),
    .carry                          (carry[22]),
    .cout                           (cout[14]),
    // input
    .in1                            (in1[24]),
    .in2                            (1'b0),
    .in3                            (in3[17]),
    .in4                            (in4[13]),
    .cin                            (cout[13])
);


CSA4_2 adder4_2_14(
    // output
    .sum                            (sum[25]),
    .carry                          (carry[23]),
    .cout                           (cout[15]),
    // input
    .in1                            (in1[25]),
    .in2                            (1'b0),
    .in3                            (in3[18]),
    .in4                            (in4[14]),
    .cin                            (cout[14])
);


CSA4_2 adder4_2_15(
    // output
    .sum                            (sum[26]),
    .carry                          (carry[24]),
    .cout                           (cout[16]),
    // input
    .in1                            (in1[26]),
    .in2                            (1'b0),
    .in3                            (in3[19]),
    .in4                            (in4[15]),
    .cin                            (cout[15])
);


CSA4_2 adder4_2_16(
    // output
    .sum                            (sum[27]),
    .carry                          (carry[25]),
    .cout                           (cout[17]),
    // input
    .in1                            (in1[27]),
    .in2                            (1'b0),
    .in3                            (in3[20]),
    .in4                            (in4[16]),
    .cin                            (cout[16])
);


CSA4_2 adder4_2_17(
    // output
    .sum                            (sum[28]),
    .carry                          (carry[26]),
    .cout                           (cout[18]),
    // input
    .in1                            (in1[28]),
    .in2                            (1'b0),
    .in3                            (in3[21]),
    .in4                            (in4[17]),
    .cin                            (cout[17])
);


assign {carry[27], sum[29]} = in3[22] + in4[18] + cout[18];
assign {carry[28], sum[30]} = in3[23] + in4[19];
assign {carry[29], sum[31]} = in3[24] + in4[20];
assign {carry[30], sum[32]} = in3[25] + in4[21];


endmodule