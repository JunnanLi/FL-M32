/* The reproduction of Multer from wdzs

    This module is designed for generating every three bits.
    
    Version list:
    1st version
        2022/08/14 by winetrs wen
 */

module PP_Decoder_Last (
    input   [15:0]                              src1,
    input                                       p0,
    input                                       sign,
    output  [15:0]                              g
);

assign g = (~sign) & p0 ? src1 : 0;		//LL0819


endmodule
