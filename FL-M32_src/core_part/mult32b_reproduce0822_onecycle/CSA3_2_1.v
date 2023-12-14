/* The reproduction of Multer from wdzs

    This module is an adder conducting (21b + 21b + 21b) with carry flag.
    CSA: carry save adder
    CSA_3_2: (3, 2) compressor
    
    Version list:
    1st version
        2022/08/14 by winetrs wen
*/

module CSA3_2_1(
    // input
    in1, 
    in2, 
    in3,
    // output
    sum, 
    carry
);


input   [20:0]                                      in1;
input   [20:0]                                      in2;
input   [20:0]                                      in3;

output  [24:0]                                      sum;
output  [20:0]                                      carry;


assign sum[0] = in1[0];
assign sum[1] = in1[1];

assign {carry[0], sum[2]} = in1[2] + in2[0];
assign {carry[1], sum[3]} = in1[3] + in2[1];


CSA3_2 adder0(
    // output
    .sum                    (sum[4]),
    .carry                  (carry[2]),
    // input
    .in1                    (in1[4]),
    .in2                    (in2[2]),
    .in3                    (in3[0])
);


CSA3_2 adder1(
    // output
    .sum                    (sum[5]),
    .carry                  (carry[3]),
    // input
    .in1                    (in1[5]),
    .in2                    (in2[3]),
    .in3                    (in3[1])
);


CSA3_2 adder2(
    // output
    .sum                    (sum[6]),
    .carry                  (carry[4]),
    // input
    .in1                    (in1[6]),
    .in2                    (in2[4]),
    .in3                    (in3[2])
);


CSA3_2 adder3(
    // output
    .sum                    (sum[7]),
    .carry                  (carry[5]),
    // input
    .in1                    (in1[7]),
    .in2                    (in2[5]),
    .in3                    (in3[3])
);


CSA3_2 adder4(
    // output
    .sum                    (sum[8]),
    .carry                  (carry[6]),
    // input
    .in1                    (in1[8]),
    .in2                    (in2[6]),
    .in3                    (in3[4])
);


CSA3_2 adder5(
    // output
    .sum                    (sum[9]),
    .carry                  (carry[7]),
    // input
    .in1                    (in1[9]),
    .in2                    (in2[7]),
    .in3                    (in3[5])
);


CSA3_2 adder6(
    // output
    .sum                    (sum[10]),
    .carry                  (carry[8]),
    // input
    .in1                    (in1[10]),
    .in2                    (in2[8]),
    .in3                    (in3[6])
);


CSA3_2 adder7(
    // output
    .sum                    (sum[11]),
    .carry                  (carry[9]),
    // input
    .in1                    (in1[11]),
    .in2                    (in2[9]),
    .in3                    (in3[7])
);


CSA3_2 adder8(
    // output
    .sum                    (sum[12]),
    .carry                  (carry[10]),
    // input
    .in1                    (in1[12]),
    .in2                    (in2[10]),
    .in3                    (in3[8])
);


CSA3_2 adder9(
    // output
    .sum                    (sum[13]),
    .carry                  (carry[11]),
    // input
    .in1                    (in1[13]),
    .in2                    (in2[11]),
    .in3                    (in3[9])
);


CSA3_2 adder10(
    // output
    .sum                    (sum[14]),
    .carry                  (carry[12]),
    // input
    .in1                    (in1[14]),
    .in2                    (in2[12]),
    .in3                    (in3[10])
);


CSA3_2 adder11(
    // output
    .sum                    (sum[15]),
    .carry                  (carry[13]),
    // input
    .in1                    (in1[15]),
    .in2                    (in2[13]),
    .in3                    (in3[11])
);


CSA3_2 adder12(
    // output
    .sum                    (sum[16]),
    .carry                  (carry[14]),
    // input
    .in1                    (in1[16]),
    .in2                    (in2[14]),
    .in3                    (in3[12])
);


CSA3_2 adder13(
    // output
    .sum                    (sum[17]),
    .carry                  (carry[15]),
    // input
    .in1                    (in1[17]),
    .in2                    (in2[15]),
    .in3                    (in3[13])
);


CSA3_2 adder14(
    // output
    .sum                    (sum[18]),
    .carry                  (carry[16]),
    // input
    .in1                    (in1[18]),
    .in2                    (in2[16]),
    .in3                    (in3[14])
);


CSA3_2 adder15(
    // output
    .sum                    (sum[19]),
    .carry                  (carry[17]),
    // input
    .in1                    (in1[19]),
    .in2                    (in2[17]),
    .in3                    (in3[15])
);


CSA3_2 adder16(
    // output
    .sum                    (sum[20]),
    .carry                  (carry[18]),
    // input
    .in1                    (in1[20]),
    .in2                    (in2[18]),
    .in3                    (in3[16])
);


assign {carry[19], sum[21]} = in2[19] + in3[17];
assign {carry[20], sum[22]} = in2[20] + in3[18];
assign sum[23] = in3[19];
assign sum[24] = in3[20];



endmodule