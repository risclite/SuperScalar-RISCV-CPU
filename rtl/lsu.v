/////////////////////////////////////////////////////////////////////////////////////
//
//Copyright 2020  Li Xinbing
//
//Licensed under the Apache License, Version 2.0 (the "License");
//you may not use this file except in compliance with the License.
//You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
//Unless required by applicable law or agreed to in writing, software
//distributed under the License is distributed on an "AS IS" BASIS,
//WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//See the License for the specific language governing permissions and
//limitations under the License.
//
/////////////////////////////////////////////////////////////////////////////////////

`include "define.v"
module lsu(

    input                                                                    clk,
    input                                                                    rst,
	
    output                                                                   dmem_req,
	output                                                                   dmem_cmd,
	output `N(2)                                                             dmem_width,
	output `N(`XLEN)                                                         dmem_addr,
	output `N(`XLEN)                                                         dmem_wdata,
	input  `N(`XLEN)                                                         dmem_rdata,
	input                                                                    dmem_resp,
	input                                                                    dmem_err,	

	input                                                                    lsu_initial,
	input  `N(`MMBUF_PARA_LEN)                                               lsu_para,
	input  `N(`XLEN)                                                         lsu_addr,
	input  `N(`XLEN)                                                         lsu_wdata,
	output                                                                   lsu_ready,
    output                                                                   lsu_finished,
	output                                                                   lsu_status,
	output `N(`XLEN)                                                         lsu_rdata,
	input                                                                    lsu_ack,	

    input                                                                    clear_pipeline

);



    //---------------------------------------------------------------------------
    //signal defination
    //---------------------------------------------------------------------------
    reg              req_sent;
    reg  `N(4)       req_para;

    //---------------------------------------------------------------------------
    //statements area
    //---------------------------------------------------------------------------	
		
	//dmem request
	assign     dmem_req = lsu_initial & lsu_ready & ~clear_pipeline;
	assign     dmem_cmd = lsu_para>>3;
	assign   dmem_width = lsu_para;
	assign    dmem_addr = lsu_addr & ( {`XLEN{1'b1}}<<dmem_width );
    assign   dmem_wdata = lsu_wdata;

	`FFx(req_sent,1'b0)
	if ( ~req_sent|dmem_resp )
	    req_sent <= dmem_req;
	else;
	
    `FFx(req_para,0)
	if ( ~req_sent|dmem_resp )
	    req_para <= lsu_para;
	else;
	
	wire `N(`XLEN)   unsigned_word = req_para[0] ? dmem_rdata[15:0] : dmem_rdata[7:0];
	wire `N(`XLEN)     signed_word = req_para[0] ? { {16{dmem_rdata[15]}},dmem_rdata[15:0] } : { {24{dmem_rdata[7]}},dmem_rdata[7:0] };
	wire `N(`XLEN)        get_word = req_para[2] ? unsigned_word : ( req_para[1] ? dmem_rdata : signed_word );
	wire `N(`XLEN)        out_word = req_para[3] ? 0 : get_word;
	
	wire                  out_resp = req_sent & dmem_resp; 
	wire `N(`XLEN)       out_rdata = out_resp ? out_word : 0;
	wire                out_status = out_resp ? dmem_err : 0;
	
	//lsu buffer
	reg  `N(`LSUBUF_LEN*`XLEN)  lsubuf_rdata;
	reg  `N(`LSUBUF_LEN)        lsubuf_status;
	reg  `N(`LSUBUF_OFF)        lsubuf_length;
	
	wire `N(`LSUBUF_LEN*`XLEN)   incoming_rdata = lsubuf_rdata|(out_rdata<<(lsubuf_length*`XLEN));
	wire `N(`LSUBUF_LEN)        incoming_status = lsubuf_status|(out_status<<lsubuf_length);
	wire `N(`LSUBUF_OFF)        incoming_length = lsubuf_length + out_resp;
	
	assign                            lsu_rdata = incoming_rdata;
	assign                           lsu_status = incoming_status;
	assign                         lsu_finished = incoming_length!=0;
	
	`FFx(lsubuf_rdata,0)
	lsubuf_rdata <= clear_pipeline ? 0 : ( incoming_rdata>>( lsu_ack*`XLEN) );
	
	`FFx(lsubuf_status,0)
	lsubuf_status <= clear_pipeline ? 0 : ( incoming_status>>lsu_ack );
	
	wire `N(`LSUBUF_OFF)           total_length = incoming_length - lsu_ack; 
	
	`FFx(lsubuf_length,0 )
	lsubuf_length <= clear_pipeline ? 0 : total_length;
	
	assign lsu_ready = ~(|incoming_status) & ( total_length<`LSUBUF_LEN ) & ( ~req_sent|dmem_resp );

endmodule

