#!/bin/sh

echo q | depak script/podite podite.fatpack --overwrite --stripper --squish \
	--debug \
	--trace-method=require \
	--include-dir lib \
	--exclude EV \
	--exclude Encode::ConfigLocal \
	--exclude Log::Agent \
	--exclude Net::DNS::Native \
	--exclude Sub::Util \
	--exclude common::sense \
	--exclude Net::SSLeay
