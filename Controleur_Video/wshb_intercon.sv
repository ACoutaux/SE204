module wshb_intercon (
    wshb_if.slave wshb_ifs_mire,
    wshb_if.slave wshb_ifs_vga,
    wshb_if.master wshb_ifm_sdram); //Ports wishbones relies aux modules mire vga et a la sdram


logic jeton; //jeton pour arbitrer entre le module mire et le module vga

always_ff @(posedge wshb_ifm_sdram.clk) begin : gestion_jeton
    if (wshb_ifm_sdram.rst)
        jeton <= 0;
    else if (~jeton && ~wshb_ifs_mire.cyc)
        jeton <= 1;
    else if (jeton && ~wshb_ifs_vga.cyc)
        jeton <= 0;
end

always@(*) //arbitrage entre vga et mire
begin
    wshb_ifm_sdram.sel = 4'b1111;
    if (jeton)
    begin
        wshb_ifm_sdram.we = 0; //ecriture desactivee si vga a le jeton
        wshb_ifm_sdram.cyc = wshb_ifs_vga.cyc;
        wshb_ifm_sdram.stb = wshb_ifs_vga.stb;
        wshb_ifm_sdram.adr = wshb_ifs_vga.adr;
        wshb_ifs_vga.ack = wshb_ifm_sdram.ack;
        wshb_ifs_vga.dat_sm = wshb_ifm_sdram.dat_sm;
        wshb_ifs_vga.err = wshb_ifm_sdram.err;
        wshb_ifs_mire.ack = 0;
    end
    else
    begin
        wshb_ifm_sdram.we = 1; //ecriture activee si mire a le jeton
        wshb_ifs_mire.ack = wshb_ifm_sdram.ack;
        wshb_ifm_sdram.adr = wshb_ifs_mire.adr;
        wshb_ifm_sdram.dat_ms = wshb_ifs_mire.dat_ms;
        wshb_ifm_sdram.cyc = wshb_ifs_mire.cyc;
        wshb_ifs_mire.err = wshb_ifm_sdram.err;
        wshb_ifm_sdram.stb = wshb_ifs_mire.stb;
        wshb_ifs_vga.ack = 0;
    end
end

endmodule