#!/usr/bin/perl

use lib "./lib";
use JSON;

use strict;
use warnings;

binmode STDOUT, ":utf8";
use utf8;

if (!@ARGV) {
	die("gen-headers.pl <mbim_foo.json>\n");
}

my $json;
{
	local $/; #Enable 'slurp' mode
	open my $fh, "<", $ARGV[0];
	$json = <$fh>;
	close $fh;
        $json =~ s/^\s*\/\/.*$//mg;
}

my $data = decode_json($json);


my $id = 1;

sub gen_foreach_field($)
{
	my $field = shift;
	my $format;

	if ($field->{format} eq "guint32") {
		$format = "uint32_t";
	} elsif ($field->{format} eq "guint64") {
		$format = "uint64_t";
	} elsif ($field->{format} eq "struct") {
		$format = "struct ". lc $field->{"struct-type"};
	} elsif ($field->{format} eq "uuid") {
		print "\tuint8_t " . lc $field->{name} . "[16];\n";
		return;
	} elsif ($field->{format} eq "ipv4") {
		print "\tuint8_t " . lc $field->{name} . "[4];\n";
		return;
	} elsif ($field->{format} eq "ipv6") {
		print "\tuint8_t " . lc $field->{name} . "[16];\n";
		return;
	} elsif ($field->{format} eq "struct-array") {
		print "\t/* struct " . lc $field->{"struct-type"}  . " */\n";
		$format = "uint32_t";
	} elsif ($field->{format} eq "string") {
		$format = "struct mbim_string";
	} else {
		print "\t/* array type: " . $field->{format} . " */\n";
		$format = "uint32_t";
	}
	if ($field->{"public-format"}) {
		print "\t/* enum " . $field->{"public-format"} . " */\n";
	}
	print "\t" . $format . " " . lc $field->{name} . ";\n";
}

sub gen_struct($$)
{
	my $struct = shift;
	my $entry = shift;

	$struct =~ s/ /_/g;
	print "struct " . lc $struct . " {\n";
	foreach my $field (@{$entry}) {
		gen_foreach_field($field);
	}
	print "} __attribute__((packed));\n\n";
}

sub gen_foreach_struct($)
{
	my $entry = shift;

	if ($entry->{contents} && @{$entry->{contents}} > 0) {
		my $struct = $entry->{name};
		gen_struct($struct, $entry->{contents});
		return;
	}

	print "/*\n * ID: " . $id . "\n * Command: " . $entry->{name} . "\n */\n\n";
	my $define = "mbim_cmd_" . $entry->{service} . "_" . $entry->{name};
	$define =~ s/ /_/g;
	print "#define " . uc $define . "\t" . $id . "\n\n";

	$id = $id + 1;
	# basic connect has no sequential numbering. ugly hack alert
	if ($id == 17) {
		$id = 19;
	}

	if ($entry->{query} && @{$entry->{query}} > 0) {
		my $struct = "mbim_" . $entry->{service} . "_" . $entry->{name} . "_q";
		gen_struct($struct, $entry->{query});
	}

	if ($entry->{response} && @{$entry->{response}} > 0) {
		my $struct = "mbim_" . $entry->{service} . "_" . $entry->{name} . "_r";
		gen_struct($struct, $entry->{response});
	}

	if ($entry->{set} && @{$entry->{set}} > 0) {
		my $struct = "mbim_" . $entry->{service} . "_" . $entry->{name} . "_s";
		gen_struct($struct, $entry->{set});
	}

	if ($entry->{notification} && @{$entry->{notification}} > 0) {
		my $struct = "mbim_" . $entry->{service} . "_" . $entry->{name} . "_n";
		gen_struct($struct, $entry->{notification});
	}
}

sub gen_foreach_command($)
{
	my $data = shift;

	foreach my $entry (@$data) {
		my $args = [];
		my $fields = [];

		if ($entry->{type} eq 'Command') {
			gen_foreach_struct($entry);
		}
		if ($entry->{type} eq 'Struct') {
			gen_foreach_struct($entry);
		}
	}
}

gen_foreach_command($data);
