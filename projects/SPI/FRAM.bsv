import SPI::*;

interface FRAMPins;
	method Bit#(1) sclk;
	method Bit#(1) mosi;
	method Action miso(Bit#(1) x); 
	method Bit#(1) ncs;
endinterface

interface FRAMIfc;
	//configuration
	//method Action setSPISclkDiv(Bit#(16) d);
	
	method Action writeEnable(Bit#(1) en);
	method Action readReq(Bit#(32)addr); //retrieve value from addr.
	method Action writeReq(Bit#(32) addr, Bit#(8) x); //put 8-bit value in addr.
	method Bit#(8) readFetch();
	
	interface FRAMPins pins;
	
endinterface

module mkFRAMMaster(FRAMIfc);
	let clock <- exposeCurrentClock();
	SPIMaster spi <- mkSPIMaster;
	
	Reg#(Bool) init <- mkReg(False); 
	Reg#(Bool) writeEn <- mkReg(False);
	Reg#(Bool) idle <- mkReg(True);
	Reg#(Bit#(48)) buffer <- mkReg(0);
	Reg#(Bit#(8)) counter <- mkReg(0);
	
	Reg#(Bool) readWait <- mkReg(False);
	Reg#(Bool) readReady <- mkReg(False);
	
	Reg#(Bit#(8)) readResult <- mkReg(0);
	
	rule doInit(!init); //initialization step.
		spi.setNcs(1);
		spi.setCpol(0);
		spi.setCpha(0);
		spi.setSclkDiv(2);
		init <= True;
		idle <= False;
	endrule
	
	rule load(init && !idle && counter != 0);
		spi.put(buffer[7:0]);
		buffer <= buffer >> 8;
		if (counter > 1) begin
			counter <= counter - 1;
		end else begin
			counter <= 0;
			if (!writeEn) begin //wait for value
				readWait <= True;
			end else begin
				spi.setNcs(1);
				idle <= True;
			end
		end
	endrule
	
	rule fetch(init && !idle && readWait);
		let result <- spi.get();
		readResult <= result;
		readWait <= False;
		readReady <= True;
		spi.setNcs(1);
		idle <= True;
	endrule
	
	method Action writeEnable(Bit#(1) en);
		if (en == 1) begin
			writeEn <= True;
			spi.put(8'b00000110); //OPCODE_WREN
		end else begin
			writeEn <= False;
			spi.put(8'b00000100); //OPCODE_WRDI
		end
	endmethod
	
	method Action writeReq(Bit#(32) addr, Bit#(8) x) if (writeEn && idle);
		buffer[7:0] <= 8'b00000010; //OPCODE_WRITE
		buffer[15:8] <= addr[31:24];
		buffer[23:16] <= addr[23:16];
		buffer[31:24] <= addr[15:8];
		buffer[39:32] <= addr[7:0];
		buffer[47:40] <= x;
		counter <= 6;
		idle <= False;
		spi.setNcs(0);
	endmethod
	
	method Action readReq(Bit#(32) addr) if (idle);
		buffer[7:0] <= 8'b00000011; //OPCODE_READ
		buffer[15:8] <= addr[31:24];
		buffer[23:16] <= addr[23:16];
		buffer[31:24] <= addr[15:8];
		buffer[39:32] <= addr[7:0];
		counter <= 5;
		idle <= False;
		spi.setNcs(0);
		readReady <= False;
	endmethod
	
	method Bit#(8) readFetch() if (readReady);
		return readResult;
	endmethod
	
	interface FRAMPins pins;
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
    endinterface		
	
endmodule

