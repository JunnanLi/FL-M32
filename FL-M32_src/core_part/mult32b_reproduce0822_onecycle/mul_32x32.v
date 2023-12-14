/* The reproduction of Multer from wdzs

    This module is designed for a 32bit x 32bit multiplier.
    This design is based on Booth multiply method.
    
    Version list:
    1st version
        2022/08/18 by yh
*/

module Mul_32x32(
    // input
    clk, 
    rst_n, 
//	G_stall,		//0
//	IH_Flush,		//0
 //   valid,			//1
	SIMD,			//0
    src1, 
    src2,
    sign1, 			//0
    sign2,			//0
	dst_1,
	dst_2,
	dst_3,
	dst_4,
    // output
    dst64
);

input                                           clk;
input                                           rst_n;
//input                                           G_stall;
//input                                           IH_Flush;
//input                                           valid;
input   [31:0]                                  src1;
input   [31:0]                                  src2;
input                                           sign1;
input                                           sign2;
input                                           SIMD; 


output  [31:0]                                  dst_1;
output  [31:0]                                  dst_2;
output  [31:0]                                  dst_3;
output  [31:0]                                  dst_4;

output  [63:0]                                  dst64;

wire    [15:0]                                  src1_1=src1[15:0];
wire    [15:0]                                  src2_1=src2[15:0];
wire                                            sign1_1=SIMD&sign1;
wire                                            sign2_1=SIMD&sign2;
wire    [31:0]                                  dst_1; 

wire    [15:0]                                  src1_2=src1[15:0];
wire    [15:0]                                  src2_2=src2[31:16];
wire                                            sign1_2=SIMD&sign1;
wire                                            sign2_2=sign2;
wire    [31:0]                                  dst_2; 

wire    [15:0]                                  src1_3=src1[31:16];
wire    [15:0]                                  src2_3=src2[15:0];
wire                                            sign1_3=sign1;
wire                                            sign2_3=SIMD&sign2;
wire    [31:0]                                  dst_3; 

wire    [15:0]                                  src1_4=src1[31:16];
wire    [15:0]                                  src2_4=src2[31:16];
wire                                            sign1_4=sign1;
wire                                            sign2_4=sign2;
wire    [31:0]                                  dst_4; 


Mul_16x16      Mul_16x16_1(
	.clk	(clk		),
	.rst_n	(rst_n		),
//	.G_stall(G_stall	),
//	.valid	(valid		),
	.src1	(src1_1		),
	.src2	(src2_1		),
	.sign1	(sign1_1	),
	.sign2	(sign2_1	),
	.dst	(dst_1		)
);
	
	
	
Mul_16x16      Mul_16x16_2(
	.clk	(clk		),
	.rst_n	(rst_n		),
//	.G_stall(G_stall	),
//	.valid	(valid		),
	.src1	(src1_2		),
	.src2	(src2_2		),
	.sign1	(sign1_2	),
	.sign2	(sign2_2	),
	.dst	(dst_2		)
);


Mul_16x16      Mul_16x16_3(
	.clk	(clk		),
	.rst_n	(rst_n		),
//	.G_stall(G_stall	),
//	.valid	(valid		),
	.src1	(src1_3		),
	.src2	(src2_3		),
	.sign1	(sign1_3	),
	.sign2	(sign2_3	),
	.dst	(dst_3		)
);

Mul_16x16      Mul_16x16_4(
	.clk	(clk		),
	.rst_n	(rst_n		),
//	.G_stall(G_stall	),
//	.valid	(valid		),
	.src1	(src1_4		),
	.src2	(src2_4		),
	.sign1	(sign1_4	),
	.sign2	(sign2_4	),
	.dst	(dst_4		)
);


//sign pre-treatment
wire temp1=sign1	&	src1[31]&(|src2[15:0]);
wire temp2=sign2	&	src2[31]&(|src1[15:0]);


//latch for sign pre-treatment
//reg E1_temp1;
//reg E1_temp2;
//always @(posedge clk or negedge rst_n)
//	begin
//		if(~rst_n)
//		begin
//			E1_temp1	<=1'b0;
//			E1_temp2	<=1'b0;
//		end
//		else if((~G_stall)&(valid))
//		begin
//			E1_temp1	<=temp1;
//			E1_temp2	<=temp2;
//		
//		end
//	
//	end 
	
	
//reg E1_valid;
//always @(posedge clk or negedge rst_n)	
//	begin
//		if(~rst_n)
//		begin
//			E1_valid	<=1'b0;
//			
//		end
//		else if((~G_stall))
//		begin
//			E1_valid<=valid	&~IH_Flush;
//		end
//	end
	
//	//latch2
//	reg 			E2_temp1;
//	reg				E2_temp2;
//	reg	[31:0]		E2_dst_1;
//	reg	[31:0]		E2_dst_2;
//	reg	[31:0]		E2_dst_3;
//	reg	[31:0]		E2_dst_4;
//	
//	always @(posedge clk or negedge rst_n)
//	begin
//		if(~rst_n)
//		begin
//			E2_temp1	<=1'b0;
//			E2_temp2	<=1'b0;
//			E2_dst_1	<=32'b0;
//			E2_dst_2	<=32'b0;
//			E2_dst_3	<=32'b0;
//			E2_dst_4	<=32'b0;
//			
//		end
//		else if((~G_stall)&(E1_valid))
//		begin
//			E2_temp1	<=E1_temp1;
//			E2_temp2	<=E1_temp1;
//			E2_dst_1	<=dst_1;
//			E2_dst_2	<=dst_2;
//			E2_dst_3	<=dst_3;
//			E2_dst_4	<=dst_4;
//		end 
//	end 
	
	
	wire	[63:0]		sum_4rd;   //43
	wire	[63:0]		carry_4rd;  //41
	
	Compressor_4rd Compressor_4rd(
	//outputs
	.sum		(sum_4rd),
	.carry		(carry_4rd),
	//inputs
//	.sign_in2	(E2_temp2),
//	.sign_in3	(E2_temp1),
//	.in1		(E2_dst_1),
//	.in2		(E2_dst_2),
//	.in3		(E2_dst_3),
//	.in4		(E2_dst_4)
	.sign_in2	(temp2),
	.sign_in3	(temp1),
	.in1		(dst_1),
	.in2		(dst_2),
	.in3		(dst_3),
	.in4		(dst_4)
	);
	
assign  dst64	=	sum_4rd	+	{carry_4rd[62:0],1'b0};

endmodule
