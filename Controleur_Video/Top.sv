`default_nettype none

module Top #(parameter HDISP = 800, parameter VDISP = 480)

(
    // Les signaux externes de la partie FPGA
	input  wire         FPGA_CLK1_50,
	input  wire  [1:0]	KEY,
	output logic [7:0]	LED,
	input  wire	 [3:0]	SW,
    // Les signaux du support matériel son regroupés dans une interface
    hws_if.master       hws_ifm,
    video_if.master     video_ifm  //ajout de l'interface video
);

//====================================
//  Déclarations des signaux internes
//====================================
  wire        sys_rst;   // Le signal de reset du système
  wire        sys_clk;   // L'horloge système a 100Mhz
  wire        pixel_clk; // L'horloge de la video 32 Mhz

//=======================================================
//  La PLL pour la génération des horloges
//=======================================================

sys_pll  sys_pll_inst(
		   .refclk(FPGA_CLK1_50),   // refclk.clk
		   .rst(1'b0),              // pas de reset
		   .outclk_0(pixel_clk),    // horloge pixels a 32 Mhz
		   .outclk_1(sys_clk)       // horloge systeme a 100MHz
);

//=============================
//  Les bus Wishbone internes
//=============================
wshb_if #( .DATA_BYTES(4)) wshb_if_sdram  (sys_clk, sys_rst);
wshb_if #( .DATA_BYTES(4)) wshb_if_stream (sys_clk, sys_rst);
wshb_if #( .DATA_BYTES(4)) wshb_if_mire (sys_clk,sys_rst);
wshb_if #( .DATA_BYTES(4)) wshb_if_vga (sys_clk,sys_rst);

//=============================
//  Le support matériel
//=============================
hw_support hw_support_inst (
    .wshb_ifs (wshb_if_sdram),
    .wshb_ifm (wshb_if_stream),
    .hws_ifm  (hws_ifm),
	.sys_rst  (sys_rst), // output
    .SW_0     ( SW[0] ),
    .KEY      ( KEY )
 );

//=============================
// On neutralise l'interface
// du flux video pour l'instant
// Neutralisation annulee
//=============================
/*assign wshb_if_stream.ack = 1'b1;
assign wshb_if_stream.dat_sm = '0 ;
assign wshb_if_stream.err =  1'b0 ;
assign wshb_if_stream.rty =  1'b0 ;*/

//=============================
// On neutralise l'interface SDRAM
// pour l'instant 
// Neutralisation annul
//=============================
/*assign wshb_if_sdram.stb  = 1'b0;
assign wshb_if_sdram.cyc  = 1'b0;
assign wshb_if_sdram.we   = 1'b0;
assign wshb_if_sdram.adr  = '0  ;
assign wshb_if_sdram.dat_ms = '0 ;
assign wshb_if_sdram.sel = '0 ;
assign wshb_if_sdram.cti = '0 ;
assign wshb_if_sdram.bte = '0 ;*/

//--------------------------
//------- Code Eleves ------
//--------------------------


`ifdef SIMULATION
  localparam hcmpt=50; //On racourcit le nombre de périodes d'horloge pour que la led change d'etat toutes les 50 periodes au lieu de 50 M
  localparam hcmpt_pixel=16;
`else
  localparam hcmpt=50000000; //la led change d'état tous les 50 millions de période d'horloges de sys_clk soit 0,5s (hors SIMULATION)
  localparam hcmpt_pixel=16000000;
`endif

//signaux internes
logic [26:0] count = 0 ; //compteur pour la led [1]
logic [26:0] count_pixel = 0 ; //compteur pour la led [2]

logic D1 = 0; //entrée de la 1e bascule
logic Q1; // sortie de la 1e bascule
logic pixel_rst; // sortie de la 2e bascule

//Instanciation module vga
vga #(.HDISP(HDISP), .VDISP(VDISP)) vga_instance(.pixel_clk(pixel_clk), .pixel_rst(pixel_rst), .video_ifm(video_ifm), .wshb_ifm(wshb_if_vga));

//Instanciation module mire
//mire #(.HDISP(HDISP), .VDISP(VDISP)) mire_instance(.wshb_if_mire(wshb_if_mire));

//Instanciation module wshb_intercon
wshb_intercon wshb_intercon_instance (.wshb_ifs_mire(wshb_if_stream), .wshb_ifs_vga(wshb_if_vga), .wshb_ifm_sdram(wshb_if_sdram));

always_comb 
begin 
    LED[0]=KEY[0];
end

always_ff @(posedge sys_clk) begin : LED_1

    count<=count+1;

    if (sys_rst) //reset synchrone avec sys_clk
    begin
        count<=0;
        LED[1]<=0;
    end

    else if (count==hcmpt)
    begin
        LED[1]<= 1 - LED[1];
        count<=0;
    end

end

always_ff @(posedge pixel_clk or posedge sys_rst) begin : GEN_PIXEL

    if (sys_rst) //les deux bascules sont mises à 1 au front montant de sys_rst
    begin
        Q1<=1;
        pixel_rst<=1;
    end

    else
    begin
        Q1<=D1;
        pixel_rst<=Q1;
    end
end

always_ff @(posedge pixel_clk) begin : LED_2

    count_pixel<=count_pixel+1;

    if (pixel_rst) // reset synchrone avec pixel_clk
    begin
        LED[2]<=0;
        count_pixel<=0;
    end

    else if (count_pixel==hcmpt_pixel)
    begin
        LED[2] = 1 - LED[2];
        count_pixel<=0;
    end
end

endmodule
