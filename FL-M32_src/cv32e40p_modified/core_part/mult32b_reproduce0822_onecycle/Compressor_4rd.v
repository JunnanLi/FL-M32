/* The reproduction of Multer from wdzs

    This module is the forth level of adder-tree.
    
    Version list:
    1st version
        2022/08/18 by yh
*/

module Compressor_4rd(
    // outputs
    sum,
    carry,
	// inputs
	sign_in2,
	sign_in3,
    in1,
    in2,
    in3,
    in4
 
);
	
output  [63:0]                                      sum;
output  [63:0]                                      carry;

input   [31:0]                                      in1;
input   [31:0]                                      in2;
input   [31:0]                                      in3;
input   [31:0]                                      in4;
input												sign_in2;
input												sign_in3;

assign	sum[15:0]	=	in1[15:0];
assign	carry[15:0]	=	16'h0;

CSA3_2 inst16(.sum(sum[16]),	.carry(carry[16]),	.in1(in1[16]),	.in2(in2[ 0]),	.in3(in3[ 0]));
CSA3_2 inst17(.sum(sum[17]),	.carry(carry[17]),	.in1(in1[17]),	.in2(in2[ 1]),	.in3(in3[ 1]));
CSA3_2 inst18(.sum(sum[18]),	.carry(carry[18]),	.in1(in1[18]),	.in2(in2[ 2]),	.in3(in3[ 2]));
CSA3_2 inst19(.sum(sum[19]),	.carry(carry[19]),	.in1(in1[19]),	.in2(in2[ 3]),	.in3(in3[ 3]));
CSA3_2 inst20(.sum(sum[20]),	.carry(carry[20]),	.in1(in1[20]),	.in2(in2[ 4]),	.in3(in3[ 4]));
CSA3_2 inst21(.sum(sum[21]),	.carry(carry[21]),	.in1(in1[21]),	.in2(in2[ 5]),	.in3(in3[ 5]));
CSA3_2 inst22(.sum(sum[22]),	.carry(carry[22]),	.in1(in1[22]),	.in2(in2[ 6]),	.in3(in3[ 6]));
CSA3_2 inst23(.sum(sum[23]),	.carry(carry[23]),	.in1(in1[23]),	.in2(in2[ 7]),	.in3(in3[ 7]));
CSA3_2 inst24(.sum(sum[24]),	.carry(carry[24]),	.in1(in1[24]),	.in2(in2[ 8]),	.in3(in3[ 8]));
CSA3_2 inst25(.sum(sum[25]),	.carry(carry[25]),	.in1(in1[25]),	.in2(in2[ 9]),	.in3(in3[ 9]));
CSA3_2 inst26(.sum(sum[26]),	.carry(carry[26]),	.in1(in1[26]),	.in2(in2[10]),	.in3(in3[10]));
CSA3_2 inst27(.sum(sum[27]),	.carry(carry[27]),	.in1(in1[27]),	.in2(in2[11]),	.in3(in3[11]));
CSA3_2 inst28(.sum(sum[28]),	.carry(carry[28]),	.in1(in1[28]),	.in2(in2[12]),	.in3(in3[12]));
CSA3_2 inst29(.sum(sum[29]),	.carry(carry[29]),	.in1(in1[29]),	.in2(in2[13]),	.in3(in3[13]));
CSA3_2 inst30(.sum(sum[30]),	.carry(carry[30]),	.in1(in1[30]),	.in2(in2[14]),	.in3(in3[14]));
CSA3_2 inst31(.sum(sum[31]),	.carry(carry[31]),	.in1(in1[31]),	.in2(in2[15]),	.in3(in3[15]));

CSA3_2 inst32(.sum(sum[32]),	.carry(carry[32]),	.in1(in4[ 0]),	.in2(in2[16]),	.in3(in3[16]));
CSA3_2 inst33(.sum(sum[33]),	.carry(carry[33]),	.in1(in4[ 1]),	.in2(in2[17]),	.in3(in3[17]));
CSA3_2 inst34(.sum(sum[34]),	.carry(carry[34]),	.in1(in4[ 2]),	.in2(in2[18]),	.in3(in3[18]));
CSA3_2 inst35(.sum(sum[35]),	.carry(carry[35]),	.in1(in4[ 3]),	.in2(in2[19]),	.in3(in3[19]));
CSA3_2 inst36(.sum(sum[36]),	.carry(carry[36]),	.in1(in4[ 4]),	.in2(in2[20]),	.in3(in3[20]));
CSA3_2 inst37(.sum(sum[37]),	.carry(carry[37]),	.in1(in4[ 5]),	.in2(in2[21]),	.in3(in3[21]));
CSA3_2 inst38(.sum(sum[38]),	.carry(carry[38]),	.in1(in4[ 6]),	.in2(in2[22]),	.in3(in3[22]));
CSA3_2 inst39(.sum(sum[39]),	.carry(carry[39]),	.in1(in4[ 7]),	.in2(in2[23]),	.in3(in3[23]));
CSA3_2 inst40(.sum(sum[40]),	.carry(carry[40]),	.in1(in4[ 8]),	.in2(in2[24]),	.in3(in3[24]));
CSA3_2 inst41(.sum(sum[41]),	.carry(carry[41]),	.in1(in4[ 9]),	.in2(in2[25]),	.in3(in3[25]));
CSA3_2 inst42(.sum(sum[42]),	.carry(carry[42]),	.in1(in4[10]),	.in2(in2[26]),	.in3(in3[26]));
CSA3_2 inst43(.sum(sum[43]),	.carry(carry[43]),	.in1(in4[11]),	.in2(in2[27]),	.in3(in3[27]));
CSA3_2 inst44(.sum(sum[44]),	.carry(carry[44]),	.in1(in4[12]),	.in2(in2[28]),	.in3(in3[28]));
CSA3_2 inst45(.sum(sum[45]),	.carry(carry[45]),	.in1(in4[13]),	.in2(in2[29]),	.in3(in3[29]));
CSA3_2 inst46(.sum(sum[46]),	.carry(carry[46]),	.in1(in4[14]),	.in2(in2[30]),	.in3(in3[30]));
CSA3_2 inst47(.sum(sum[47]),	.carry(carry[47]),	.in1(in4[15]),	.in2(in2[31]),	.in3(in3[31]));

CSA3_2 inst48(.sum(sum[48]),	.carry(carry[48]),	.in1(in4[16]),	.in2(sign_in2),	.in3(sign_in3));
CSA3_2 inst49(.sum(sum[49]),	.carry(carry[49]),	.in1(in4[17]),	.in2(sign_in2),	.in3(sign_in3));
CSA3_2 inst50(.sum(sum[50]),	.carry(carry[50]),	.in1(in4[18]),	.in2(sign_in2),	.in3(sign_in3));
CSA3_2 inst51(.sum(sum[51]),	.carry(carry[51]),	.in1(in4[19]),	.in2(sign_in2),	.in3(sign_in3));
CSA3_2 inst52(.sum(sum[52]),	.carry(carry[52]),	.in1(in4[20]),	.in2(sign_in2),	.in3(sign_in3));
CSA3_2 inst53(.sum(sum[53]),	.carry(carry[53]),	.in1(in4[21]),	.in2(sign_in2),	.in3(sign_in3));
CSA3_2 inst54(.sum(sum[54]),	.carry(carry[54]),	.in1(in4[22]),	.in2(sign_in2),	.in3(sign_in3));
CSA3_2 inst55(.sum(sum[55]),	.carry(carry[55]),	.in1(in4[23]),	.in2(sign_in2),	.in3(sign_in3));
CSA3_2 inst56(.sum(sum[56]),	.carry(carry[56]),	.in1(in4[24]),	.in2(sign_in2),	.in3(sign_in3));
CSA3_2 inst57(.sum(sum[57]),	.carry(carry[57]),	.in1(in4[25]),	.in2(sign_in2),	.in3(sign_in3));
CSA3_2 inst58(.sum(sum[58]),	.carry(carry[58]),	.in1(in4[26]),	.in2(sign_in2),	.in3(sign_in3));
CSA3_2 inst59(.sum(sum[59]),	.carry(carry[59]),	.in1(in4[27]),	.in2(sign_in2),	.in3(sign_in3));
CSA3_2 inst60(.sum(sum[60]),	.carry(carry[60]),	.in1(in4[28]),	.in2(sign_in2),	.in3(sign_in3));
CSA3_2 inst61(.sum(sum[61]),	.carry(carry[61]),	.in1(in4[29]),	.in2(sign_in2),	.in3(sign_in3));
CSA3_2 inst62(.sum(sum[62]),	.carry(carry[62]),	.in1(in4[30]),	.in2(sign_in2),	.in3(sign_in3));
CSA3_2 inst63(.sum(sum[63]),	.carry(carry[63]),	.in1(in4[31]),	.in2(sign_in2),	.in3(sign_in3));


endmodule