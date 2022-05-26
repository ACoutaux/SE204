module mire #(parameter HDISP = 800, parameter VDISP = 480)

(   wshb_if.master    wshb_if_mire  //Interface wishbone pour mire en modport master
);

logic [5:0] cpt_pixel; //compteur pour les pixels d'une capacite de 64
logic [$clog2(HDISP) : 0] cpt_pixel_screen; //compteur de pixels pour affiche sur l'edran

always_ff @(posedge wshb_if_mire.clk) begin : generation_signaux_controle
    if (wshb_if_mire.rst)
    begin
        wshb_if_mire.cyc <= 0; //si il y a un reset on n'envoie pas de requete d'ecriture
        wshb_if_mire.stb <= 0;
        cpt_pixel <= 0; //initialisation du compteur
    end
    else 
        if (cpt_pixel < 63)
        begin
            cpt_pixel <= cpt_pixel + 1;
            wshb_if_mire.cyc <= 1;
            wshb_if_mire.stb <= 1;     
        end
        else
        begin //on ne genere rien tous les 64 pixels
            cpt_pixel <= 0;
            wshb_if_mire.cyc <= 0;
            wshb_if_mire.stb <= 0;
        end
end

always_ff @(posedge wshb_if_mire.clk) begin : generation_mire
    if (wshb_if_mire.rst)
        cpt_pixel_screen <= 0;
    else if (cpt_pixel_screen < HDISP/2)
    begin
        wshb_if_mire.dat_ms <= {8'd255,8'd255,8'd255}; //pixels blancs
        if (wshb_if_mire.ack) begin
            cpt_pixel_screen <= cpt_pixel_screen + 1;
        end
    end
    else
    begin
        wshb_if_mire.dat_ms = {8'd255,8'd0,8'd0}; //pixels rouges
        if (cpt_pixel_screen == HDISP-1)
            cpt_pixel_screen <= 0;
        else if (wshb_if_mire.ack)
            cpt_pixel_screen <= cpt_pixel_screen + 1;
    end
end

// Gestion des adresses

always_ff @(posedge wshb_if_mire.clk) begin : controleur_adresses
    if (wshb_if_mire.rst) //l'adresse est remise a 0 si il y a un reset 
        wshb_if_mire.adr <= 0;
    else if (wshb_if_mire.ack)
        begin
        if (wshb_if_mire.adr >= 4 * (VDISP * HDISP - 1)) //l'adresse est remise a 0 si on a atteint l'adresse max de la memoire
            wshb_if_mire.adr <= 0;
        else
            wshb_if_mire.adr <= wshb_if_mire.adr + 4; //on incremente l'adresse de 4 a partir de 0 a chaque ack
        end
end

endmodule