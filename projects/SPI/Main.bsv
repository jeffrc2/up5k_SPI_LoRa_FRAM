import FRAM::*;
import LoRa::*;

interface MainIfc;
	method Action uartIn(Bit#(8) data);
	method ActionValue#(Bit#(8)) uartOut;
	method Bit#(3) rgbOut;
	
	method Bit#(3) spi0_out;
	method Bit#(3) spi1_out;
	method Action spi0_in(Bit#(1) miso0);
	method Action spi1_in(Bit#(1) miso1);
endinterface


module mkMain(MainIfc);
	FRAMIfc fram1 <- mkFRAMMaster;
	LoRaIfc lora0 <- mkLoRaMaster;

	Clock curclk <- exposeCurrentClock;

	method Bit#(3) spi0_out;//LoRa output pins
		return {lora0.pins.ncs, lora0.pins.mosi, lora0.pins.sclk};
	endmethod
	
	method Bit#(3) spi1_out; //fram output pins
		return {fram1.pins.ncs, fram1.pins.mosi, fram1.pins.sclk};
	endmethod
	
	method Action spi0_in(Bit#(1) miso0); //LoRa input pin
		lora0.pins.miso(miso0);
	endmethod
	
	method Action spi1_in(Bit#(1) miso1); //fram input pin
		fram1.pins.miso(miso1);
	endmethod
	
	method ActionValue#(Bit#(8)) uartOut;
		return 0;
	endmethod
	
	method Bit#(3) rgbOut;
		return 0;
	endmethod
	
endmodule
