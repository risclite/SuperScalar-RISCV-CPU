
`include "define.v"


module ssrv_memory
#(
    parameter SCR1_AHB_WIDTH = 32 
)
 (

    input                                      clk,
	input                                      rst,

    // Instruction Memory Interface
    // input     [3:0]                           imem_hprot,
    // input     [2:0]                           imem_hburst,
    input      [2:0]                           imem_hsize,
    input      [1:0]                           imem_htrans,
    input      [SCR1_AHB_WIDTH-1:0]            imem_haddr,
    output                                     imem_hready,
    output     [SCR1_AHB_WIDTH-1:0]            imem_hrdata,
    output                                     imem_hresp,

    // Memory Interface
    // input     [3:0]                           dmem_hprot,
    // input     [2:0]                           dmem_hburst,
    input      [2:0]                           dmem_hsize,
    input      [1:0]                           dmem_htrans,
    input      [SCR1_AHB_WIDTH-1:0]            dmem_haddr,
    input                                      dmem_hwrite,
    input      [SCR1_AHB_WIDTH-1:0]            dmem_hwdata,
    output                                     dmem_hready,
    output     [SCR1_AHB_WIDTH-1:0]            dmem_hrdata,
    output                                     dmem_hresp

);

    wire `N(32) iport_rdata, dport_rdata; 

    //iport

    wire iport_rden = imem_htrans[1] & (imem_haddr[31:16]==0);
	
	wire `N(14) iport_addr = imem_haddr>>2;
	
	reg iport_ready;
	`FFx(iport_ready,0)
	iport_ready <= iport_rden;
	
	assign imem_hready = 1;
	
	assign imem_hrdata = iport_rdata;
	
	assign imem_hresp = 1'b0;
	
	//dport
	
	wire dport_rd_en = dmem_htrans[1] & ~dmem_hwrite  & (dmem_haddr[31:16]==0);
	
	wire dport_wr_en = dmem_htrans[1] & dmem_hwrite  & (dmem_haddr[31:16]==0);

	wire `N(14) dport_addr = dmem_haddr>>2;
	
	wire `N(4) dport_byte_enable = ( dmem_hsize==3'b000 ) ? ( 1'b1<<dmem_haddr[1:0] )      : (
	                               ( dmem_hsize==3'b001 ) ? ( 2'b11<<(dmem_haddr[1]*2) )   : 
								                              4'b1111
									);

    reg dnext_rd_en;
	`FFx(dnext_rd_en,1'b0)
	dnext_rd_en <= dport_rd_en;
	
	reg `N(14) dnext_rd_addr;
	`FFx(dnext_rd_addr,0)
	dnext_rd_addr <= dport_addr;
	
	reg `N(4) dnext_rd_byte_enable;
	`FFx(dnext_rd_byte_enable,0)
	dnext_rd_byte_enable <= dport_byte_enable;
	
	reg `N(5) dnext_rd_para;
	`FFx(dnext_rd_para,0)
	dnext_rd_para <= { dmem_hsize,dmem_haddr[1:0] };
	
	
	
    reg dnext_wr_en;
	`FFx(dnext_wr_en,1'b0)
	dnext_wr_en <= dport_wr_en;
	
	reg `N(14) dnext_wr_addr;
	`FFx(dnext_wr_addr,0)
	dnext_wr_addr <= dport_addr;
	
	reg `N(4) dnext_wr_byte_enable;
	`FFx(dnext_wr_byte_enable,0)
	dnext_wr_byte_enable <= dport_byte_enable;
	
	
	
	reg dport_collision;
	`FFx(dport_collision,0)
	dport_collision <= dnext_wr_en & dport_rd_en;
	
	assign dmem_hready = ~dport_collision;
	
	
	
	wire `N(14) dcomb_addr = dnext_wr_en ? dnext_wr_addr : ( dport_collision ? dnext_rd_addr : dport_addr );
	
	wire `N(4) dcomb_byte_enable = dnext_wr_en ? dnext_wr_byte_enable : ( dport_collision ? dnext_rd_byte_enable : dport_byte_enable );
	
	wire dcomb_rd_en = dnext_wr_en ? 1'b0 : ( dport_collision ? 1'b1 : dport_rd_en );
	
	wire dcomb_wr_en = dnext_wr_en ? 1'b1 : ( dport_collision ? 1'b0 : 1'b0 );
	
	
    reg `N(5) dcomb_rd_para;
	`FFx(dcomb_rd_para,0)
	dcomb_rd_para <= dport_collision ? dnext_rd_para :  { dmem_hsize,dmem_haddr[1:0] };

    assign dmem_hrdata = ( dcomb_rd_para[4:2]==3'b000 ) ? { 4{ dport_rdata[`IDX(dcomb_rd_para[1:0],8)] } } : (
                         ( dcomb_rd_para[4:2]==3'b001 ) ? { 2{ dport_rdata[`IDX(dcomb_rd_para[1],16)]  } } :
                                                               dport_rdata
                          );

	assign dmem_hresp = 1'b0;					  
	

	
    dualram i_dram (
	    .address_a    (    iport_addr                  ),
	    .address_b    (    dcomb_addr                  ),
	    .byteena_b    (    dcomb_byte_enable           ),
	    .clock        (    clk                         ),
	    .data_a       (    32'h0                       ),
	    .data_b       (    dmem_hwdata                 ),
	    .rden_a       (    iport_rden                  ),
	    .rden_b       (    dcomb_rd_en                 ),
	    .wren_a       (    1'b0                        ),
	    .wren_b       (    dcomb_wr_en                 ),
	    .q_a          (    iport_rdata                 ),
	    .q_b          (    dport_rdata                 )
	);	

/*
    reg dmem_print;
	`FFx(dmem_print,0)
	dmem_print <= dmem_htrans[1] & dmem_hwrite & ( dmem_haddr==32'hF0000000 );

    always@* begin
	    if ( dmem_print )
	        $write("%c", dmem_hwdata[7:0]);	
	end
*/

endmodule