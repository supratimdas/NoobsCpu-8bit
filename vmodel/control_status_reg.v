/*********************************************************** 
* File Name     : control_status_reg.v
* Description   : this implements the control & status reg
* Organization  : NONE 
* Creation Date : 01-09-2019
* Last Modified : Friday 19 June 2020 06:37:57 PM IST
* Author        : Supratim Das (supratimofficio@gmail.com)
************************************************************/ 

/****************************STATUS_REGISTER BIT MAP*******************************
 *|    7    |    6    |    5    |    4    |    3    |    2    |    1    |    0    |
 *+---------+---------+---------+---------+---------+---------+---------+---------+
 *|  RSVD   |  RSVD   |  RSVD   |  I/TRP  |    Z    |   NZ    | ST-OVF  |   OVF   |
 *+---------+---------+---------+---------+---------+---------+---------+---------+
 */

/****************************CONTROL_REGISTER BIT MAP*******************************
 *|    7    |    6    |    5    |    4    |    3    |    2    |    1    |    0    |
 *+---------+---------+---------+---------+---------+---------+---------+---------+
 *|  RSVD   |  RSVD   |  RSVD   | SP_MSB10| SP_MSB9 | SP_MSB8 |  BCNZ   |   BCZ   |
 *+---------+---------+---------+---------+---------+---------+---------+---------+
 */

module control_status_reg (
	clk,
	reset_,

	I_TRP,		//interrupt/trap
	I_TRP_en,	//interrupt/trap en

	Z,			//zero
	Z_en,		//zero flag enable

	NZ,			//non-zero
	NZ_en,		//non-zero flag en

	ST_OVF,		//stack overflow
	ST_OVF_en,	//stack overflow en

	OVF,		//overflow
	OVF_en,		//overflow en

	SP_MSB10,	//stack pointer msb10
	SP_MSB9,	//stack pointer msb9
	SP_MSB8,	//stack pointer msb8
	SP_MSB_en,	//update stack pointer en

	BC_en,		//branch condition enable
	BCNZ,		//branch condition non-zero
	BCZ,		//brench condition zero

	CREG,		//Control Reg output
	SREG		//Status Reg output
);

	input clk;
	input reset_;

	input I_TRP;		//interrupt/trap
	input I_TRP_en;	//interrupt/trap en

	input Z;			//zero
	input Z_en;		//zero flag enable

	input NZ;			//non-zero
	input NZ_en;		//non-zero flag en

	input ST_OVF;		//stack overflow
	input ST_OVF_en;	//stack overflow en

	input OVF;		//overflow
	input OVF_en;		//overflow en

	input SP_MSB10;	//stack pointer msb10
	input SP_MSB9;	//stack pointer msb9
	input SP_MSB8;	//stack pointer msb8
	input SP_MSB_en;	//update stack pointer en

	input BC_en;		//branch condition enable
	input BCNZ;		//branch condition non-zero
	input BCZ;		//brench condition zero

	output [7:0] CREG;		//Control Reg output
	output [7:0] SREG;		//Status Reg output

	reg [7:0] cr; //control register
	reg [7:0] sr; //status register

	reg [7:0] cr_next;
	reg [7:0] sr_next;

	always @(posedge clk) begin
		if(!reset_) begin
			cr <= 8'd0;
			sr <= 8'd0;
		end
		else begin
			cr <= cr_next;
			sr <= sr_next;
		end
	end

	always @(*) begin
		cr_next = cr;
		sr_next = sr;

		//update status flags
		if(I_TRP_en)
			sr_next[4] = I_TRP;

		if(Z_en)
			sr_next[3] = Z;

		if(NZ_en)
			sr_next[2] = NZ;

		if(ST_OVF_en)
			sr_next[1] = ST_OVF;

		if(OVF_en)
			sr_next[0] = OVF;

		//update control flags
		if(SP_MSB_en) begin
			cr[4:2] = {SP_MSB10, SP_MSB9, SP_MSB8};
		end

		if(BC_en) begin
			cr[1:0] = {BCNZ, BCZ};
		end
	end

	assign CREG = cr_next;
	assign SREG = sr_next;

endmodule

