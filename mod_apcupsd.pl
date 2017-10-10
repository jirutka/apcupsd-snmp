#!/usr/bin/perl
#
# Copyright (c) 2011 Jakub Jirutka (jakub@jirutka.cz)
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or (at your
# option) any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the  GNU Lesser General Public License for
# more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

###############################################################################
#
#                        Net-SNMP module for apcupsd
#
#
# Net-SNMP module for monitoring APC UPSes without SNMP support. It reads output 
# from apcupsd (/sbin/apcaccess) and writes it into appropriate OIDs like UPSes 
# with built-in SNMP support.
# 
# 
# To load this into a running agent with embedded perl support turned on, simply 
# put the following line to your snmpd.conf file:
#
#   perl do "/path/to/mod_apcupsd.pl";
#
# Net-snmp must be compiled with Perl support and apcupsd properly configured 
# and running!
#
#
# You can download MIB file of PowerNet (APC) from 
# http://www.michaelfmcnamara.com/files/mibs/powernet401.mib
#
# OID numbers for PowerNet-MIB: http://www.oidview.com/mibs/318/PowerNet-MIB.html
#
# If you want to edit this, set tab size in your editor to 4!
#
#
# @author: Jakub Jirutka <jakub@jirutka.cz>
# @version: 1.0
# @date: 2011-07-31
#

BEGIN {
    print STDERR "Starting mod_apcupsd.pl\n";
    $agent || die "No \$agent defined\n";
}

use feature ('switch');
use NetSNMP::OID (':all');
use NetSNMP::agent (':all');
use NetSNMP::ASN (':all');



#################### SETTINGS ###################


# Set to 1 to get extra debugging information.
$debugging = 0;

# How often fetch data from /sbin/apcaccess (in seconds)?
my $fetch_interval = 20;

# Base OID of APC UPS tree to hook onto.
my $base_oid = '.1.3.6.1.4.1.318.1.1.1';

# OIDs mapping
my $mapping = [
#   Apcupsd name    OID suffix  Data type           OID name
    ['APCMODEL',    '1.1.1.0',  ASN_OCTET_STR],     # upsBasicIdentModel
    ['UPSNAME',     '1.1.2.0',  ASN_OCTET_STR],     # upsBasicIdentName
    ['FIRMWARE',    '1.2.1.0',  ASN_OCTET_STR],     # upsAdvIdentFirmwareRevision
    ['SERIALNO',    '1.2.3.0',  ASN_OCTET_STR],     # upsAdvIdentSerialNumber
    ['TONBATT',     '2.1.2.0',  ASN_TIMETICKS],     # upsBasicBatteryTimeOnBattery
    ['BATTDATE',    '2.1.3.0',  ASN_OCTET_STR],     # upsBasicBatteryLastReplaceDate
    ['BCHARGE',     '2.2.1.0',  ASN_GAUGE],         # upsAdvBatteryCapacity
    ['ITEMP',       '2.2.2.0',  ASN_GAUGE],         # upsAdvBatteryTemperature
    ['TIMELEFT',    '2.2.3.0',  ASN_TIMETICKS],     # upsAdvBatteryRunTimeRemaining
    ['NOMBATTV',    '2.2.7.0',  ASN_INTEGER],       # upsAdvBatteryNominalVoltage
    ['BATTV',       '2.2.8.0',  ASN_INTEGER],       # upsAdvBatteryActualVoltage  //should be ASN_INTEGER according to new ver. of MIB
    ['LINEV',       '3.2.1.0',  ASN_GAUGE],         # upsAdvInputLineVoltage
    ['LINEFREQ',    '3.2.4.0',  ASN_GAUGE],         # upsAdvInputFrequency
    ['LASTXFER',    '3.2.5.0',  ASN_INTEGER],       # upsAdvInputLineFailCause
    ['OUTPUTV',     '4.2.1.0',  ASN_GAUGE],         # upsAdvOutputVoltage
    ['LOADPCT',     '4.2.3.0',  ASN_GAUGE],         # upsAdvOutputLoad
    ['NOMOUTV',     '5.2.1.0',  ASN_INTEGER],       # upsAdvConfigRatedOutputVoltage
    ['HITRANS',     '5.2.2.0',  ASN_INTEGER],       # upsAdvConfigHighTransferVolt
    ['LOTRANS',     '5.2.3.0',  ASN_INTEGER],       # upsAdvConfigLowTransferVolt
    ['ALARMDEL',    '5.2.4.0',  ASN_INTEGER],       # upsAdvConfigAlarm
    ['RETPCT',      '5.2.6.0',  ASN_INTEGER],       # upsAdvConfigMinReturnCapacity
    ['SENSE',       '5.2.7.0',  ASN_INTEGER],       # upsAdvConfigSensitivity
    ['MINTIMEL',    '5.2.8.0',  ASN_TIMETICKS],     #? upsAdvConfigLowBatteryRunTime
    ['DWAKE',       '5.2.9.0',  ASN_TIMETICKS],     # upsAdvConfigReturnDelay
    ['DSHUTD',      '5.2.10.0', ASN_TIMETICKS],     # upsAdvConfigShutoffDelay
    ['STESTI',      '7.2.1.0',  ASN_INTEGER],       # upsAdvTestDiagnosticSchedule
    ['SELFTEST',    '7.2.3.0',  ASN_INTEGER],       # upsAdvTestDiagnosticsResults //according to apcstatus.c, or date and time of last self test according to manual?!
    ['STATUS',      '4.1.1.0',  ASN_INTEGER]        # upsBasicOutputStatus
];

# Maps apcupsd values to enum types according to MIB.
# Mainly based on apcupsd sources (apcstatus.c, drv_powernet.c) and PowerNet MIB.
my %enums = (
    # STATUS => upsBasicOutputStatus
    "$base_oid.4.1.1.0" => {
        'UNKNOWN' => 1,   # unknown
        'ONLINE'  => 2,   # onLine
        'ONBATT'  => 3,   # onBattery
        'BOOST'   => 4,   # onSmartBoost
        'TRIM'    => 12,  # onSmartTrim
    },

    # SELFTEST => upsAdvTestDiagnosticsResults
    "$base_oid.7.2.3.0" => {
        'OK'    => 1,   # ok
        'BT'    => 2,   # failed //it's NOT in drv_powernet.c
        'NG'    => 3,   # invalidTest
        'IP'    => 4,   # testInProgress
        'NO'    => undef,   # ! NONE
        'WN'    => undef,   # ! WARNING
        '??'    => undef    # ! UNKNOWN 
    },

    # STESTI => upsAdvTestDiagnosticSchedule
    "$base_oid.7.2.1.0" => {
        'None'  => 1,   # unknown
        '336'   => 2,   # biweekly
        '168'   => 3,   # weekly
        'ON'    => 4,   # atTurnOn
        'OFF'   => 5    # never
    },

    # SENSE => upsAdvConfigSensitivity
    "$base_oid.5.2.7.0" => {
        'Auto Adjust'   => 1,   # auto
        'Low'           => 2,   # low
        'Medium'        => 3,   # medium
        'High'          => 4,   # high
        'Unknown'       => undef
    },

    # ALARMDEL -> upsAdvConfigAlarm
    "$base_oid.5.2.4.0" => {
        '30 seconds'    => 1,   # timed
        '5 seconds'     => 1,   # timed
        'Always'        => 1,   # timed
        'Low Battery'   => 2,   # atLowBattery
        'No alarm'      => 3    # never
    },

    # LASTXFER => upsAdvInputLineFailCause
    "$base_oid.3.2.5.0" => {
        'No transfers since turnon'         => 1,   # noTransfer
        'High line voltage'                 => 2,   # highLineVoltage
        'Low line voltage'                  => 4,   # blackout
        'Line voltage notch or spike'       => 8,   # largeMomentarySpike
        'Automatic or explicit self test'   => 9,   # selfTest
        'Unacceptable line voltage changes' => 10,  # rateOfVoltageChange
        'Forced by software'                => undef,
        'Input frequency out of range'      => undef,
        'UNKNOWN EVENT'                     => undef
    }
);

# TODO upsBasicBatteryStatus, NOMPOWER




#################### INITIALIZATION ###################


# Hashmap for apcupsd names => OIDs
my %name_oid;

# Hashmap for OID => types
my %oid_type;

# Build hashmaps
foreach my $row (@$mapping) {
    my ($name, $oid, $type) = @$row;
    $oid = "$base_oid.$oid";
    $name_oid{$name} = $oid;
    $oid_type{$oid} = $type;
}

# Delete mapping array (we have hashmaps now)
undef $mapping;


# Timestamp of last data fetch
my $last_fetch;
    
# Fetched values from /sbin/apcaccess
my %data;


# Fetch data for the first time so we can build
# OID chain for actually available values.
&fetch_data;

# Chain of our OIDs in lexical order for GETNEXT
my %oid_chain;

# First OID in chain
my $first_oid = 0;

# Build OID chain
my $prev_oid;
foreach my $oid (&oid_lex_sort(keys(%data))) {
    if (!$first_oid) {
        $first_oid = $oid;
    } else {
        $oid_chain{$prev_oid} = $oid;
    }
    $prev_oid = $oid;
}


# Base OID to register
$reg_oid = new NetSNMP::OID($base_oid);

# Register in the master agent we're embedded in.
$agent->register('mod_apcupsd', $reg_oid, \&snmp_handler);
print STDERR "Registering at $base_oid \n" if ($debugging);




#################### SUBROUTINES ###################


# Fetch data from /sbin/apcaccess and convert for SNMP.
# This routine stores values in variable %data and fetch it again
# only when it's called after more than $fetch_interval seconds
# since last fetch.
sub fetch_data {
    my $elapsed = time() - $last_fetch;

    if ($elapsed < $fetch_interval) {
        print STDERR "It's $elapsed sec since last update, interval is "
                . "$fetch_interval\n" if ($debugging);
        return 0;
    }

    print STDERR "Fetching data from /sbin/apcaccess\n" if ($debugging);
    open AC, '/sbin/apcaccess status localhost |'
            || die "FATAL: can't run \"/sbin/apcaccess\": $!\n";

    my $line;
    while (defined($line = <AC>)) {
        chomp $line;
        if ($line !~ /^(\w+)\s*:\s*(.*\w)/) { next; }

        my $oid = $name_oid{$1};
        my $value = &convert_value($oid, $2) if $oid;
        $data{$oid} = $value if (defined $value);
    }

    close AC;
    $last_fetch = time();

    return 1;
}

# Convert given raw value from /sbin/apcaccess to proper SNMP value according 
# to data type defined in MIB.
# Given value must be without beginning and end whitespaces and only *value*,
# not whole row!
sub convert_value {
    my ($oid, $raw) = @_;

    # Convert values representing enums
    # If enum value is undef, returns 0.
    if (exists $enums{$oid}) {
        my $enum = $enums{$oid}{$raw};
        return (defined $enum ? $enum : 0);
    }

    # Convert other values according to their data type in MIB
    given ($oid_type{$oid}) {
        when ([ASN_INTEGER]) {
            return ($raw =~ /(\d+)/g)[0];
        }
        when ([ASN_GAUGE]) {
            return ($raw =~ /(\d+(?:\.\d+)?)/g)[0];
        }
        when ([ASN_TIMETICKS]) {
            my ($val, $unit) = ($raw =~ /(\d+(?:\.\d+)?)\s+(\w+)/g);
            return &convert_time($val, $unit);
        }
        default { 
            return $raw;
        }
    }
}

# Convert time in given unit (seconds, minutes or hours) to miliseconds.
sub convert_time {
    my ($val, $unit) = @_;

    given ($unit) {
        when (m/^seconds/i) { 
            return $val * 100; 
        }
        when (m/^minutes/i) { 
            return $val * 6000; 
        }
        when (m/^hours/i) { 
            return $val * 360000; 
        }
        default {
            return $val;
        }
    }
}


# Subroutine that handle the incoming requests to our part of the OID tree.  
# This subroutine will get called for all requests within the OID space 
# under the registration oid made above.
sub snmp_handler {
    my ($handler, $registration_info, $request_info, $requests) = @_;
    my $request;

    print STDERR "refs: ", join(", ", ref($handler), ref($registration_info),
            ref($request_info), ref($requests)), "\n" if ($debugging);

    print STDERR "Processing a request of type " 
            . $request_info->getMode() . "\n" if ($debugging);

    &fetch_data;

    for($request = $requests; $request; $request = $request->next()) {
        # This is way how to convert NetSNMP::OID to numeric OID
        my $oid = '.' . join('.', $request->getOID()->to_array());
        print STDERR "Processing request of $oid\n" if ($debugging);

        # Mode GET (for single entry)
        if ($request_info->getMode() == MODE_GET) {
            if (exists($data{$oid})) {
                my $value = $data{$oid};

                print STDERR "  Returning: $value\n" if ($debugging);
                $request->setValue($oid_type{$oid}, $value);
            
            # Workaround for requests without "index"
            } elsif (exists($data{"$oid.0"})) {
                my $new_oid = "$oid.0";
                my $value = $data{$new_oid};

                print STDERR "  Returning for $new_oid: $value\n" if ($debugging);
                $request->setOID($new_oid);
                $request->setValue($oid_type{$new_oid}, $value);
            }

        # Mode GETNEXT (for walking)
        } elsif ($request_info->getMode() == MODE_GETNEXT) {
            if (exists($oid_chain{$oid})) {
                my $next_oid = $oid_chain{$oid};
                my $value = $data{$next_oid};

                print STDERR "  Returning next OID $next_oid: $value\n" if ($debugging);
                $request->setOID($next_oid);
                $request->setValue($oid_type{$next_oid}, $value);


            } elsif ($request->getOID() <= $reg_oid) {
                my $value = $data{$first_oid};

                print STDERR "  Returning first OID $first_oid: $value\n" if ($debugging);
                $request->setOID($first_oid);
                $request->setValue($oid_type{$first_oid}, $value);


            } else {
                print STDERR "Illegal request\n" if ($debugging);
            }
        }
    }

    print STDERR "Processing finished\n" if ($debugging);
}


# Sort OIDs lexicographically
# See http://www.perlmonks.org/?node_id=524035
sub oid_lex_sort(@) {
    return @_ unless (@_ > 1);

    map { $_->[0] }
    sort { $a->[1] cmp $b->[1] }
    map {
        my $oid = $_;
        $oid =~ s/^\.//o;
        $oid =~ s/ /\.0/og;
        [$_, pack('N*', split('\.', $oid))]
    } @_;
}
