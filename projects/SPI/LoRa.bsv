import SPI::*;
// This module only sends data through LoRa in implicit header mode, and does not receive.

interface LoRaPins;
	method Bit#(1) sclk;
	method Bit#(1) mosi;
	method Action miso(Bit#(1) x); 
	method Bit#(1) ncs;
endinterface

interface LoRaIfc;
	//configuration
	method Action setSPISclkDiv(Bit#(16) d);
	// method Action setLoRaFreq(Bit#(16) f);
	//method Action setLoRaSpreadingFactor(Bit#(16) sf);
	
	//transmission
	method Action beginPacket(); //start packet
	method Action endPacket(); //end packet
	//method ActionValue#(Bit#(8)) get(); //retrieve value.
	method Action put(Bit#(8) x); //put value in packet.
	
	interface LoRaPins pins;
	
endinterface


module mkLoRaMaster(LoRaIfc);
	let clock <- exposeCurrentClock();
	SPIMaster spi <- mkSPIMaster;
	
	
	Reg#(Bool) init <- mkReg(False); //initialization
	//Reg#(Bool) frequency <- mkReg(False); //frequency initialization
	Reg#(Bool) tx_base_addr_init <- mkReg(False); //tx_base_addr set to 0 for LoRA 
 	Reg#(Bool) rx_base_addr_init <- mkReg(False); //rx_base_addr set to 0 for LoRA
	//Reg#(Bool) lna_boost_init <- mkReg(False); //lna set to 0x03
	//Reg#(Bool) auto_agc_init <- mkReg(False); //reg_modem_config_3 to 4
	//Reg#(Bool) tx_power_init <- mkReg(False); //reg_pa_dac to 0x84
	//Reg#(Bool) pa_config_init <- mkReg(False); //reg_pa_config to 15
	//Reg#(Bool) ocp_init <- mkReg(False); //ocp 0x20 | (0x1F & 11)
	
	Reg#(Bit#(32)) shiftReg <- mkReg(0); //LoRa shift register; maximum payload 4-byte packet size for now, with 4 left over for requests.
	Reg#(Bit#(8)) pktCount <- mkReg(0); //packet index in the shift register; corresponds to a byte. (0, 8, 16, 32[full])
	Reg#(Bit#(8)) payload_len <- mkReg(0); // value to store the current payload value when packet is finished.
	
	Reg#(Bool) packet <- mkReg(False); //packet preparation state
	Reg#(Bool) transmitting <- mkReg(False);
	Reg#(Bool) transmit_reg_fifo <- mkReg(False); //transmit fifo register first
	Reg#(Bool) transmit_shiftValue <- mkReg(False); //then transfer shift register, alternating with fifo until shift register is empty.
	Reg#(Bool) transmit_reg_payload_len <- mkReg(False);//then transmit payload register
	Reg#(Bool) transmit_payload_len <- mkReg(False); //then transmit payload_len

	Reg#(Bool) transmit_reg_op_mode <- mkReg(False); //then transmit operation register
	Reg#(Bool) transmit_tx_op_code <- mkReg(False); //finally transmit the opcode to run.
	
	Reg#(Bool) transmit_reg_irq_flags <- mkReg(False);
	Reg#(Bool) checkTxDone <- mkReg(False);

	Reg#(Bool) spi_lock <- mkReg(False); //locks when SPI is busy
	//Reg#(Bool) sf <- mkReg(False); //spreading factor set
	
	//Reg#(Bit#(8)) payload_len <- mkReg(0); //length of packet in bytes
	
	rule doInit(!init); //initialization step.
		spi.setNcs(1);
		spi.setCpol(0);
		spi.setCpha(0);
		spi.setSclkDiv(2);
		init <= True;
	endrule
	
	rule transmitRegFIFO(transmit_reg_fifo);
		spi.put(0); //hardcoded FIFO value on the shield.
		transmit_reg_fifo <= False;
		transmit_shiftValue <= True;
	endrule
	
	rule transmitShiftVal(transmit_shiftValue);
		spi.put(shiftReg[7:0]);
		shiftReg <= shiftReg >> 8;
		transmit_shiftValue <= False;
		if (pktCount > 1) begin //run another.
			transmit_reg_fifo <= True;
			pktCount <= pktCount - 1;
		end else begin
			pktCount <= 0;
			transmit_reg_payload_len <= True;
		end
	endrule
	
	rule transmitRegPayloadLen(transmit_reg_payload_len);
		spi.put(8'b00100010);
		transmit_reg_payload_len <= False;
		transmit_payload_len <= True;
	endrule
	
	rule transmitPayloadLen(transmit_payload_len);
		spi.put(payload_len);
		payload_len <= 0;
		transmit_payload_len <= False;
		transmit_reg_op_mode <= True;
	endrule
	
	rule transmitRegOpMode(transmit_reg_op_mode);
		spi.put(8'b00000001);
		transmit_reg_op_mode <= False;
		transmit_tx_op_code <= True;
	endrule
	
	rule transmitOpMode(transmit_tx_op_code);
		spi.put(8'b00001000 | 8'b00000011); //MODE_LONG_RANGE_MODE | MODE_TX 
		transmit_tx_op_code <= False;
		transmit_reg_irq_flags <= True;
	endrule
	
	rule transmitRegIRQFlag(transmit_reg_irq_flags);
		spi.put(8'b00010010);
		transmit_reg_irq_flags <= False;
		checkTxDone <= True;
	endrule
	
	rule checkTx(init && checkTxDone);
		let result <- spi.get();
		if ((result & 8'b00001000) == 0) begin
			spi.setNcs(1);
		end
		checkTxDone <= False;
	endrule

	method Action beginPacket() if (!packet);
		packet <= True;
	endmethod
		
	method Action put(Bit#(8) x) if (packet);
		shiftReg[(pktCount+1)*8-1:(pktCount)*8] <= x;
		pktCount <= pktCount + 1;
	endmethod
	
	method Action endPacket() if (packet && pktCount > 0);
		packet <= False;
		payload_len <= pktCount;
		spi.setNcs(0);
		transmit_reg_fifo <= True;
	endmethod
	
	method Action setSPISclkDiv(Bit#(16) d);
        spi.setSclkDiv(d);
    endmethod
	
	// method Action setLoRaFreq(Bit#(16) d) if (ncsReg == 1);
        // sclkDiv <= d;
    // endmethod
	
	interface LoRaPins pins;
        method Bit#(1) sclk;
            return spi.pins.sclk;
        endmethod
        method Bit#(1) mosi;
            return spi.pins.mosi;
        endmethod
        method Action miso(Bit#(1) x);
            spi.pins.miso(x);
        endmethod
        method Bit#(1) ncs;
            return spi.pins.ncs;
        endmethod
        //interface Clock deleteme_unused_clock = clock;
    endinterface	
	

endmodule

