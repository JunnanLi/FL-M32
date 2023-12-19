/* The reproduction of Multer from wdzs

    This module is a 1bit adder with carry flag.
    
    Version list:
    1st version
        2022/08/14 by winetrs wen
*/

module CSA3_2(
    // input
    in1,
    in2,
    in3,
    // output
    sum,
    carry
);

input                                       in1;
input                                       in2;
input                                       in3;

output                                      sum;
output                                      carry;

assign {carry, sum} = in1 + in2 + in3;

endmodule
