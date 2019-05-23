/////////////////////////////////////////////////////////////////////////////////////
//
//Copyright 2019  Li Xinbing
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
module mprf(
    //system signals
    input                            clk,
	input                            rst,
    
	//from membuf
	input  `N(5)                     mem_sel,
	input  `N(`XLEN)                 mem_data,
	
	//from alu/alu_mul
	input  `N(`EXEC_LEN*5)           rg_sel,
	input  `N(`EXEC_LEN*`XLEN)       rg_data,

	//between alu/alu_mul
	input  `N(`EXEC_LEN*5)           rs0_sel,
	input  `N(`EXEC_LEN*5)           rs1_sel,    	
	output `N(`EXEC_LEN*`XLEN)       rs0_data,
	output `N(`EXEC_LEN*`XLEN)       rs1_data
);


    reg `N(`XLEN) r [31:1];
	
	generate
	genvar i;
    for (i=1;i<=31;i=i+1) begin:u_rf
        `FFx(r[i],0) begin:u_r
		    integer n;
		    if ( i==mem_sel )
			    r[i] <= mem_data;
			for(n=0;n<`EXEC_LEN;n=n+1)
			    if (i==rg_sel[`IDX(n,5)])
				    r[i] <= rg_data[`IDX(n,`XLEN)];
		end
    end

    for(i=0;i<`EXEC_LEN;i=i+1) begin:u_out
	    assign rs0_data[`IDX(i,`XLEN)] = (rs0_sel[`IDX(i,5)]==0) ? 0 : r[rs0_sel[`IDX(i,5)]];
	    assign rs1_data[`IDX(i,`XLEN)] = (rs1_sel[`IDX(i,5)]==0) ? 0 : r[rs1_sel[`IDX(i,5)]];		
	end
	endgenerate
	
endmodule
