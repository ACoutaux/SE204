module vga #(parameter HDISP = 800, parameter VDISP = 480)
            (input wire pixel_clk,
            input wire pixel_rst,
            video_if.master     video_ifm,
            wshb_if.master      wshb_ifm); //interface wishbone avec le modport master

//Déclaration des constantes    
localparam HFP = 40;
localparam HPULSE = 48;
localparam HBP = 40;
localparam VFP = 13;
localparam VPULSE = 3;
localparam VBP = 29;

//Parametres fifo
localparam DEPTH_WIDTH = 8; //la fifo peut contenir 256 donnees
localparam DATA_WIDTH = 32; //les donnees contenues dans la fifo font 32 bits

//Déclaration et initialisation des compteurs
logic [$clog2(HDISP+HBP+HPULSE+HFP)-1 : 0] cpt_pixels ;
logic [$clog2(VDISP+VBP+VPULSE+VFP)-1 : 0] cpt_lignes ;

//Declaration param instance fifo_vga
logic fifo_vga_read;
logic fifo_vga_wfull; //signal qui indique si la fifo est pleine
logic fifo_vga_walmost_full;

logic fifo_was_full; //signal pour indiquer si la fifo a deja ete pleine

logic wfull_synchro; //signal wfull de la fifo synchro avec l'horloge pixel_clk
logic Q1; //signal de sortie de la 1e bascule utilisee pour la synchro

//Instanciation FIFO
async_fifo #(.DEPTH_WIDTH(DEPTH_WIDTH), .DATA_WIDTH(DATA_WIDTH), .ALMOST_FULL_THRESHOLD(8'd224)) fifo_vga 
(.rst(wshb_ifm.rst), 
.rclk(pixel_clk),
.read(fifo_vga_read),
.rdata(video_ifm.RGB),
.rempty(),
.wclk(wshb_ifm.clk),
.wdata(wshb_ifm.dat_sm),
.write(wshb_ifm.ack),
.wfull(fifo_vga_wfull),
.walmost_full(fifo_vga_walmost_full));

//Assignations valeurs interface wshb_if

//assign    wshb_ifm.dat_ms = 32'hBABECAFE;
//assign    wshb_ifm.adr = '0;
//assign    wshb_ifm.cyc = ~ fifo_vga_wfull; //si la fifo est pleine cyc est mis a l'etat bas

always_ff @(wshb_ifm.clk ) begin : cyc_synchrone //on genere le cyc de maniere synchrone et en hysteresis
    if (wshb_ifm.rst)
        wshb_ifm.cyc <= 0;
    else if (~fifo_vga_walmost_full)
        wshb_ifm.cyc <= 1;
    else if (fifo_vga_wfull)
        wshb_ifm.cyc <= 0;
end

assign    wshb_ifm.sel = 4'b1111; //masque pour selectionner les 4 octets
assign    wshb_ifm.stb = ~ fifo_vga_wfull; //si la fifo est pleine stb est mis a l'etat bas
assign    wshb_ifm.we = 1'b0; //write enable desactive
assign    wshb_ifm.cti = '0; //cycle classique
assign    wshb_ifm.bte = '0;

//Horloges
assign video_ifm.CLK = pixel_clk;

//Generation des compteurs delignes et pixels

always_ff @(posedge pixel_clk) begin : compteurs
    if (pixel_rst) //reset synchrone avec pixel_clk
    begin
        cpt_pixels <= 0;
        cpt_lignes <= 0;
    end
    else begin
        
        if (cpt_pixels == (HDISP+HFP+HPULSE+HBP)-1) //remise à zero compteur pixels
        begin
            
            cpt_pixels <= 0;
            if (cpt_lignes == (VDISP+VPULSE+VFP+VBP)-1) //remise à zero compteur lignes
                cpt_lignes <= 0;
            else
                cpt_lignes <= cpt_lignes + 1;
        end
        else
            cpt_pixels <= cpt_pixels + 1;
    end
end

// Generation des signaux vga

always_ff @(posedge pixel_clk) begin : blank
    video_ifm.BLANK <= (cpt_pixels > HFP+HPULSE+HBP-1 && cpt_lignes > VFP+VPULSE+VBP-1);
end

always_ff @(posedge pixel_clk) begin : hs
    video_ifm.HS <= ~(cpt_pixels>=HFP && cpt_pixels<HPULSE+HFP);      
end

always_ff @(posedge pixel_clk) begin : vs
    video_ifm.VS <= ~(cpt_lignes>VFP-1 && cpt_lignes <= VFP+VPULSE-1);   
end

// Synchro des signaux wishbone et vga

always_ff @(posedge pixel_clk ) begin : synchro
    if(pixel_rst)
    begin
        wfull_synchro <= 0;
        Q1 <= 0;
    end
    else
    begin
        Q1 <= fifo_vga_wfull;
        wfull_synchro <= Q1;
    end
end


// Generation des signaux de controle de la fifo

assign fifo_vga_read = fifo_was_full && video_ifm.BLANK; //on commence a lire seulement si on est dans l'ecran d'affichage et si la fifo a deja ete pleine

always_ff @(posedge pixel_clk) begin : generate_fifo_was_full //genere le signal fifo_was_full qui est a 1 si la fifo a deja ete pleine 1 fois
    if (wshb_ifm.rst)
        fifo_was_full <= 0;
    else if (wfull_synchro)
        fifo_was_full <= 1;
end

// Gestion des adresses

always_ff @(posedge wshb_ifm.clk) begin : controleur
    if (wshb_ifm.rst) //l'adresse est remise a 0 si il y a un reset 
        wshb_ifm.adr <= 0;
    else if (wshb_ifm.ack)
        begin
        if (wshb_ifm.adr >= 4 * (VDISP * HDISP - 1)) //l'adresse est remise a 0 si on a atteint l'adresse max de la memoire
            wshb_ifm.adr <= 0;
        else
            wshb_ifm.adr <= wshb_ifm.adr + 4; //on incremente l'adresse de 4 a partir de 0 a chaque ack
        end
end

endmodule