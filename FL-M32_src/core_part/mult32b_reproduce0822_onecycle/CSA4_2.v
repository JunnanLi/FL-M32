/* The reproduction of Multer from wdzs

    This module is an adder conducting (21b + 22b + 20b) with carry flag.
    CSA: carry save adder
    CSA_4_2: (4, 2) compressor
    
    Version list:
    1st version
        2022/08/15 by winetrs wen
*/

module CSA4_2(
    // input
    in1,
    in2,
    in3,
    in4,
    cin,

    // output
    sum,
    carry,
    cout
);


input                                           in1;
input                                           in2;
input                                           in3;
input                                           in4;
input                                           cin;

output                                          sum;
output                                          carry;
output                                          cout;

wire                                            sum1;

assign  {cout, sum1} = in1 + in2 + in3;
assign  {carry, sum} = cin + sum1 + in4;


endmodule