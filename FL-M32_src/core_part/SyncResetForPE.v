//--------------------------------------------
// Description:   Synchronize the reset signal in the clock domain    -
// Language:      Verilog-2001               -
// Author:                      -
// Date:          2022-12-01 16:54:59
//--------------------------------------------

module SyncResetForPE(
  input rstn
, input clk
, input conf_en
, input start_en
, output reg rstn_clk
);

reg tmp0;
reg tmp1;

always@(posedge clk or negedge rstn) begin
  if (~rstn) begin
    rstn_clk <= 1'b0;
    tmp0 <= 1'b0;
    tmp1 <= 1'b0;
  end
  else begin
    tmp0 <= start_en & (~conf_en);
    tmp1 <= tmp0;
    rstn_clk <= tmp1;
  end
end

endmodule