`define DEL 3
module rxtx
#(parameter baud = 9600,
            mhz = 25
  )
 (
            clk,
			rst,
			rx,
			tx_vld,
			tx_data,
			
			rx_vld,
			rx_data,
			tx,
			txrdy
			);

input        clk;
input        rst;
input        rx;
input        tx_vld;
input  [7:0] tx_data;

output       rx_vld;
output [7:0] rx_data;
output       tx;
output       txrdy;

/***********************************/
reg          rx_dly;
reg    [13:0] rx_cnt;
reg          data_vld;
reg    [3:0] data_cnt;
reg          rx_vld;
reg    [7:0] rx_data;
reg    [7:0] tx_rdy_data;
reg          tran_vld;
reg    [3:0] tran_cnt;
reg          tx;
wire         txrdy;
/***********************************/
wire         rx_change;
wire         rx_en;

/***********************************/

localparam period = (mhz*1000000)/baud,
           half = period/2;

reg rx1,rx2,rx3,rxx;
always @ ( posedge clk ) begin
    rx1 <= #`DEL rx;
	rx2 <= #`DEL rx1;
	rx3 <= #`DEL rx2;
	rxx <= #`DEL rx3;
	end


always @ ( posedge clk  )
   rx_dly <= #`DEL rxx;

assign rx_change = (rxx != rx_dly );

always @ ( posedge clk or posedge rst )
if ( rst )
    rx_cnt <= #`DEL 0;
else if ( rx_change | ( rx_cnt==period ) )
    rx_cnt <= #`DEL 0;
else
    rx_cnt <= #`DEL rx_cnt + 1'b1;

assign rx_en = ( rx_cnt==half );

always @ ( posedge clk or posedge rst )
if ( rst )
    data_vld <= #`DEL 1'b0;
else if ( rx_en & ~rxx & ~data_vld )
    data_vld <= #`DEL 1'b1;
else if ( data_vld & ( data_cnt==4'h9 ) & rx_en )
    data_vld <= #`DEL 1'b0;
else;

always @ ( posedge clk or posedge rst )
if ( rst )
    data_cnt <= #`DEL 4'b0;
else if ( data_vld )
    if ( rx_en )
        data_cnt <= #`DEL data_cnt + 1'b1;
	else;
else 	
    data_cnt <= #`DEL 4'b0;

always @ ( posedge clk or posedge rst )
if ( rst )
    rx_data <= #`DEL 7'b0;
else if ( data_vld & rx_en & ~data_cnt[3] )
    rx_data <= #`DEL {rxx,rx_data[7:1]}; 
else;

always @ ( posedge clk or posedge rst )
if ( rst )
    rx_vld <= #`DEL 1'b0;
else
    rx_vld <= #`DEL data_vld & rx_en & ( data_cnt==4'h9);

always @ ( posedge clk or posedge rst )
if ( rst )
    tx_rdy_data <= #`DEL 8'b0;
else if ( tx_vld & txrdy )
    tx_rdy_data <= #`DEL tx_data;
else;

always @ ( posedge clk or posedge rst )
if ( rst )
    tran_vld <= #`DEL 1'b0;
else if ( tx_vld )
    tran_vld <= #`DEL 1'b1;
else if ( tran_vld & rx_en & ( tran_cnt== 4'd10 ) )
    tran_vld <= #`DEL 1'b0;
else;

always @ ( posedge clk or posedge rst )
if ( rst )
    tran_cnt <= #`DEL 4'b0;
else if ( tran_vld )
    if( rx_en )
	    tran_cnt <= #`DEL tran_cnt + 1'b1;
	else;
else
    tran_cnt <= #`DEL 4'b0;

always @ ( posedge clk or posedge rst )
if ( rst )
    tx <= #`DEL 1'b1;
else if ( tran_vld )
    if ( rx_en )
    case ( tran_cnt )
    4'd0 : tx <= #`DEL 1'b0;
    4'd1 : tx <= #`DEL tx_rdy_data[0];
    4'd2 : tx <= #`DEL tx_rdy_data[1];   	
    4'd3 : tx <= #`DEL tx_rdy_data[2];
    4'd4 : tx <= #`DEL tx_rdy_data[3];
    4'd5 : tx <= #`DEL tx_rdy_data[4];
    4'd6 : tx <= #`DEL tx_rdy_data[5];   	
    4'd7 : tx <= #`DEL tx_rdy_data[6];
    4'd8 : tx <= #`DEL tx_rdy_data[7];
	4'd9: tx <= #`DEL ^tx_rdy_data;
	4'd10: tx <= #`DEL 1'b1;
	default: tx <= #`DEL 1'b1;
	endcase
	else;
else
    tx<= #`DEL 1'b1;

assign txrdy = ~tran_vld;

	
endmodule
