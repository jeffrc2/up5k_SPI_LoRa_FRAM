import Clocks :: *;
import Vector::*;

import Main::*;

import Uart::*;

import "BDPI" function Action bdpiSwInit();


interface BsvTopIfc;
	(* always_ready *)
	method Bit#(1) blue;
	(* always_ready *)
	method Bit#(1) green;
	(* always_ready *)
	method Bit#(1) red;
	
	method Bit#(1) spi0_cs;
	method Bit#(1) spi0_mosi;
	method Action spi0_miso(Bit#(1) miso0);
	method Bit#(1) spi0_sclk;
	
	method Bit#(1) spi1_cs;
	method Bit#(1) spi1_mosi;
	method Action spi1_miso(Bit#(1) miso1);
	method Bit#(1) spi1_sclk;
	
	(* always_ready *)
	method Bit#(1) serial_txd;
	(* always_enabled, always_ready, prefix = "", result = "serial_rxd" *)
	method Action serial_rx(Bit#(1) serial_rxd);
endinterface

module mkBsvTop(BsvTopIfc);
	UartIfc uart <- mkUart(2500);
	MainIfc hwmain <- mkMain;

	rule relayUartIn;
		Bit#(8) d <- uart.user.get;
		hwmain.uartIn(d);
	endrule
	rule relayUartOut;
		let d <- hwmain.uartOut;
		uart.user.send(d);
	endrule


	method Bit#(1) blue;
		return hwmain.rgbOut()[2];
	endmethod
	method Bit#(1) green;
		return hwmain.rgbOut()[1];
	endmethod
	method Bit#(1) red;
		return hwmain.rgbOut()[0];
	endmethod
	
	method Bit#(1) spi0_cs;
		return hwmain.spi0_out()[0];
	endmethod
	
	method Bit#(1) spi0_mosi;
		return hwmain.spi0_out()[1];
	endmethod
	
	method Bit#(1) spi0_sclk;
		return hwmain.spi0_out()[2];
	endmethod
	
	method Bit#(1) spi1_cs;
		return hwmain.spi1_out()[0];
	endmethod
	
	method Bit#(1) spi1_mosi;
		return hwmain.spi1_out()[1];
	endmethod
	
	method Bit#(1) spi1_sclk;
		return hwmain.spi1_out()[2];
	endmethod
	
	method Action spi0_miso(Bit#(1) miso0);
		hwmain.spi0_in(miso0);
	endmethod
	
	method Action spi1_miso(Bit#(1) miso1);
		hwmain.spi1_in(miso0);
	endmethod
	
	method Bit#(1) serial_txd;
		return uart.serial_txd;
	endmethod
	method Action serial_rx(Bit#(1) serial_rxd);
		uart.serial_rx(serial_rxd);
	endmethod
endmodule

module mkBsvTop_bsim(Empty);
	UartUserIfc uart <- mkUart_bsim;
	MainIfc hwmain <- mkMain;
	Reg#(Bool) initialized <- mkReg(False);
	rule doinit ( !initialized );
		initialized <= True;
		bdpiSwInit();
	endrule

	rule relayUartIn;
		Bit#(8) d <- uart.get;
		hwmain.uartIn(d);
	endrule
	rule relayUartOut;
		let d <- hwmain.uartOut;
		uart.send(d);
	endrule
endmodule
