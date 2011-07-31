# Net-SNMP module for apcupsd

This is Net-SNMP module for monitoring APC UPSes without SNMP support. It reads
output from apcupsd (/sbin/apcaccess) and writes it into appropriate OIDs like
UPSes with built-in SNMP support.


## Installation
 
To load this into a running agent with embedded Perl support turned on, simply 
put the following line to your snmpd.conf file:

	perl do "/path/to/mod_apcupsd.pl";

Net-snmp must be compiled with Perl support and apcupsd properly configured 
and running!


## Use

Try `snmpwalk -v 2c -c public <host> .1.3.6.1.4.1.318.1.1.1` and you should
get something like:

	$ snmpwalk -v 2c -c public localhost .1.3.6.1.4.1.318.1.1.1
	PowerNet-MIB::upsBasicIdentModel.0 = STRING: "Back-UPS RS 500"
	PowerNet-MIB::upsBasicIdentName.0 = STRING: "grid"
	PowerNet-MIB::upsAdvIdentFirmwareRevision.0 = STRING: "30.j2.I USB FW:j2"
	PowerNet-MIB::upsAdvIdentSerialNumber.0 = STRING: "BB0314005xxx"
	PowerNet-MIB::upsBasicBatteryTimeOnBattery.0 = Timeticks: (0) 0:00:00.00
	PowerNet-MIB::upsBasicBatteryLastReplaceDate.0 = STRING: "2009-02-26"
	PowerNet-MIB::upsAdvBatteryCapacity.0 = Gauge32: 100
	PowerNet-MIB::upsAdvBatteryTemperature.0 = Gauge32: 29
	PowerNet-MIB::upsAdvBatteryRunTimeRemaining.0 = Timeticks: (190200) 0:31:42.00
	PowerNet-MIB::upsAdvBatteryNominalVoltage.0 = INTEGER: 12
	PowerNet-MIB::upsAdvBatteryActualVoltage.0 = INTEGER: 13
	PowerNet-MIB::upsAdvInputLineVoltage.0 = Gauge32: 228
	PowerNet-MIB::upsAdvInputFrequency.0 = Gauge32: 49
	PowerNet-MIB::upsAdvInputLineFailCause.0 = INTEGER: blackout(4)
	PowerNet-MIB::upsAdvOutputVoltage.0 = Gauge32: 230
	PowerNet-MIB::upsAdvOutputLoad.0 = Gauge32: 22
	PowerNet-MIB::upsAdvConfigRatedOutputVoltage.0 = INTEGER: 230
	PowerNet-MIB::upsAdvConfigHighTransferVolt.0 = INTEGER: 254
	PowerNet-MIB::upsAdvConfigLowTransferVolt.0 = INTEGER: 198
	PowerNet-MIB::upsAdvConfigAlarm.0 = INTEGER: atLowBattery(2)
	PowerNet-MIB::upsAdvConfigMinReturnCapacity.0 = INTEGER: 0
	PowerNet-MIB::upsAdvConfigSensitivity.0 = INTEGER: high(4)
	PowerNet-MIB::upsAdvConfigLowBatteryRunTime.0 = Timeticks: (24000) 0:04:00.00
	PowerNet-MIB::upsAdvConfigReturnDelay.0 = Timeticks: (0) 0:00:00.00
	PowerNet-MIB::upsAdvConfigShutoffDelay.0 = Timeticks: (0) 0:00:00.00
	PowerNet-MIB::upsAdvTestDiagnosticSchedule.0 = INTEGER: unknown(1)
	PowerNet-MIB::upsAdvTestDiagnosticsResults.0 = INTEGER: 0
	
or if you like numeric OIDs:

	snmpwalk -v 2c -c public -On localhost .1.3.6.1.4.1.318.1.1.1
	.1.3.6.1.4.1.318.1.1.1.1.1.1.0 = STRING: "Back-UPS RS 500"
	.1.3.6.1.4.1.318.1.1.1.1.1.2.0 = STRING: "grid"
	.1.3.6.1.4.1.318.1.1.1.1.2.1.0 = STRING: "30.j2.I USB FW:j2"
	.1.3.6.1.4.1.318.1.1.1.1.2.3.0 = STRING: "BB0314005158"
	.1.3.6.1.4.1.318.1.1.1.2.1.2.0 = Timeticks: (0) 0:00:00.00
	.1.3.6.1.4.1.318.1.1.1.2.1.3.0 = STRING: "2009-02-26"
	.1.3.6.1.4.1.318.1.1.1.2.2.1.0 = Gauge32: 100
	.1.3.6.1.4.1.318.1.1.1.2.2.2.0 = Gauge32: 29
	.1.3.6.1.4.1.318.1.1.1.2.2.3.0 = Timeticks: (184800) 0:30:48.00
	.1.3.6.1.4.1.318.1.1.1.2.2.7.0 = INTEGER: 12
	.1.3.6.1.4.1.318.1.1.1.2.2.8.0 = INTEGER: 13
	.1.3.6.1.4.1.318.1.1.1.3.2.1.0 = Gauge32: 228
	.1.3.6.1.4.1.318.1.1.1.3.2.4.0 = Gauge32: 49
	.1.3.6.1.4.1.318.1.1.1.3.2.5.0 = INTEGER: blackout(4)
	.1.3.6.1.4.1.318.1.1.1.4.2.1.0 = Gauge32: 230
	.1.3.6.1.4.1.318.1.1.1.4.2.3.0 = Gauge32: 21
	.1.3.6.1.4.1.318.1.1.1.5.2.1.0 = INTEGER: 230
	.1.3.6.1.4.1.318.1.1.1.5.2.2.0 = INTEGER: 254
	.1.3.6.1.4.1.318.1.1.1.5.2.3.0 = INTEGER: 198
	.1.3.6.1.4.1.318.1.1.1.5.2.4.0 = INTEGER: atLowBattery(2)
	.1.3.6.1.4.1.318.1.1.1.5.2.6.0 = INTEGER: 0
	.1.3.6.1.4.1.318.1.1.1.5.2.7.0 = INTEGER: high(4)
	.1.3.6.1.4.1.318.1.1.1.5.2.8.0 = Timeticks: (24000) 0:04:00.00
	.1.3.6.1.4.1.318.1.1.1.5.2.9.0 = Timeticks: (0) 0:00:00.00
	.1.3.6.1.4.1.318.1.1.1.5.2.10.0 = Timeticks: (0) 0:00:00.00
	.1.3.6.1.4.1.318.1.1.1.7.2.1.0 = INTEGER: unknown(1)
	.1.3.6.1.4.1.318.1.1.1.7.2.3.0 = INTEGER: 0

You can also query only one OID:

	$ snmpwalk -v 2c -c public grid .1.3.6.1.4.1.318.1.1.1.2.2.3.0
	PowerNet-MIB::upsAdvBatteryRunTimeRemaining.0 = Timeticks: (190200) 0:31:42.00
	

## What can by improved

* Reimplement snmp_handler to correctly support walking through subtrees of 
.1.3.6.1.4.1.318.1.1.1 (e.g. .1.3.6.1.4.1.318.1.1.1.2). Currently it can 
list subtrees only on .1.3.6.1.4.1.318.1.1.1 and leafs.

* Add remaining OIDs that apcupsd could get data for. I included only OIDs for 
my APC Back-UP RS 500.

* Implement support for setting values and traps.

Feel free to contribute! I don't intend to work on it.


## Important notes

* Download PowerNet (APC) MIB file: 
[http://www.michaelfmcnamara.com/files/mibs/powernet401.mib](powernet401.mib).

* I'm not skilled Perl programmer, this is my first Perl script I ever wrote.
So if you find something weird in it, please let me know about it and fix it.
However it's working perfectly fine for me, so I hope it's ok.
