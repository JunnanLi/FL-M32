/* The reproduction of Multer from wdzs
    
    Version list:
    1st version
        2022/08/14 by winetrs wen
*/

module PP_Decoder(
    // input
    src1,
    p0,
    p1,
    p2,

    // output
    g,
    S,
    E
);

input   [16:0]                              src1;
input                                       p0;
input                                       p1;
input                                       p2;

output  [16:0]                              g;
output                                      S;
output                                      E;


reg     [16:0]                              g1;
wire                                        get_zero;

assign get_zero = (p0 & p1 & p2) | (~p0 & ~p1 & ~p2); // product is zero
assign S = (~(p0&p1)) & p2; // product is minus
assign E = get_zero | (src1[16] & S) | (~src1[16] & ~S); // product has same sign with multi_num
assign g = S ? (~g1) : g1; // get product

always @ (*) begin
    if ((~p2)&p1&p0 | p2&(~p1)&(~p0)) begin
        g1 = {src1[15:0], 1'b0};
    end
    else if (p0&p1&p2 | (~p0)&(~p2)&(~p2)) begin
        g1 = 'b0;
    end
    else begin
        g1 = src1;
    end
end

endmodule
