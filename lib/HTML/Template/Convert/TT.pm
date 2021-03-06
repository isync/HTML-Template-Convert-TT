package HTML::Template::Convert::TT;

use strict;
use warnings;

require Exporter;
use Carp;

our @ISA = qw(Exporter);
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	convert	
	print_params
);

our $VERSION = '0.05';


sub parse_opts {
    my $argsref = shift;
    my $options = shift;
    for (my $x = 0; $x < @{$argsref}; $x += 2) {
      defined(${$argsref}[($x + 1)]) or croak(
        "function called with odd number of option parameters - should be of the form option => value");
      $options->{lc(${$argsref}[$x])} = ${$argsref}[($x + 1)]; 
    }
    return $options;
}
sub convert {
	my $fname = shift;
	my %opts = @_;

	my $source;
	if(ref($fname)) {
		# user passed a scalar-ref
		$source = $$fname;
	}else{
		# open file for user
		open FH, $fname or die "convert: error opening $fname: $!";
		# read whole file
		undef $/;
		$source = <FH>;
	}
	my @chunk = split /(?=<)/, $source;
	close FH;
	my $opts = {};
	%$opts = (
               loop_context_vars => 0,
			   generate_params => 0,
              );
	$opts = parse_opts([@_], $opts);
	my $text;
	my ($tag, $test);
	my @stack;
	my %push= ( 
		VAR => 0,
		LOOP => 1,
		INCLUDE => 0,
		IF => 1,
		ELSE => 0,
		UNLESS => 1
	);
	my %ctx_vars;
	@ctx_vars{qw/__first__ __last__ __counter__/} = qw/loop.first loop.last loop.count/;
	$ctx_vars{__odd__} = 'loop.count mod 2';
	$ctx_vars{__inner__} = '1 - (loop.first + loop.last - loop.first*loop.last)';
	my $gen_params = {};
	for(@chunk) {
		my ($name, $default, %escape);
		if (/^<
			(?:!--\s*)?
			(?:
				(?i:TMPL_
					(VAR|LOOP|INCLUDE|IF|UNLESS|ELSE) # $1
				)
				\s*
			)

			(.*?) # parameters

			(?:--)?>                    
			(.*) # $3
			/sx)  {
				my ($tag, $rest) = (uc $1, $3);
				$_ = $2;
				pos = 0;
				while (/\G
					(?i:
						\b
						(DEFAULT|NAME|ESCAPE)
						\s*=\s*
						
					)?
					(?:
						"([^"]+)"
						|
						'([^']+)'
						|
						([^\s]+)
					)
					\s*
					/xgc) 
				{
					my $val = defined $2? $2: defined $3? $3: $4;
					chomp $val;
					if (defined $1 and uc $1 ne 'NAME') {
						if(uc $1 eq 'DEFAULT') {
							die "DEFAULT parameter has already defined" if defined $default;
							$default = $val; 
						}
						else {
							die "Invalid ESCAPE parameter" unless
								$val =~ /0|1|html|url|js|none/i;
							$escape{lc $val} = 1;
						}
					}
					else {
						die "NAME parameter has already defined" if defined $name;
						$name = $val;
					}
				}
				my $case_name = $name;
				#$name = lc $name;
				$name = $ctx_vars{lc $name} if exists $ctx_vars{lc $name} and $opts->{loop_context_vars};
				die "Invalid parameter syntax($1)". pos if /\G(.+)/g;
				push @stack, $tag if $push{$tag};
				if ($tag eq 'VAR') {
					$text .= "[% DEFAULT $name = '$default' %]"
						if defined $default;

					my $filter = '';
					$filter .= " | html | replace('\\\'', '\&#39;')" 
						if exists $escape{html} or exists $escape{1};
					$filter .= " | uri" if exists $escape{url}; 
					$filter .= 
						" | replace('\\'', '\\\\\\'')".
						" | replace('\"', '\\\"')".
						" | replace('\\n', '\\\\n')".
						" | replace('\\r', '\\\\r')"
						if exists $escape{js};
						#$name = 'loop.count' if $opts->{loop_context_vars} and $name eq '__counter__';
					die "Empty 'NAME' parameter" if $name eq '';
					$text .= "[% $name$filter %]";
					$gen_params->{$name} = $name;
				}
				elsif ($tag eq 'LOOP') {
					$text .= "[% FOREACH $name %]" 
						if $name or
							die "Empty 'NAME' parameter";
					 my $sub_params = { 'parent hash' => $gen_params, 'child name' => $name };
					$gen_params = $sub_params;
				}
				elsif ($tag eq 'INCLUDE') {
					if($opts{resolve_includes}){
						$text .= convert($case_name, %$opts)
							if $name or die "Empty 'NAME' parameter";
							%$gen_params = (%$gen_params, %${$opts->{gen_params}}) if ref $opts->{gen_params};
					}else{
						$text .= "[% INCLUDE '$name' %]" 
							if $name or
								die "Empty 'NAME' parameter";
						 my $sub_params = { 'parent hash' => $gen_params, 'child name' => $name };
						$gen_params = $sub_params;
					}
				}
				elsif ($tag eq 'IF' or $tag eq 'UNLESS') {
					die "Empty 'NAME' parameter" if $name eq '';
					$text .= "[% $tag $name %]";
				}
				else { # ELSE TAG
					die "ELSE tag without IF/UNLESS first"
						unless 
							@stack and 
							$stack[$#stack] =~ /IF|UNLESS/;
					$text .= '[% ELSE %]';

				}
				$text .= $rest;
		}
		elsif (/^<(?:!--\s*)?\/TMPL_(LOOP|IF|UNLESS)\s*(?:--)?>(.*)/si) {
			$tag = uc $1;
			die "/TMPL_$tag tag without TMPL_$tag first" 
				unless @stack;
			die "Unexpected /TMPL_$tag tag " 
				unless $tag = pop @stack;
			$text .= "[% END %]$2";
			if(uc $tag eq 'LOOP') {
				my $sub_param = $gen_params;
				$gen_params = $sub_param->{'parent hash'};
				my $key = $$sub_param{'child name'};
				delete $$sub_param{'parent hash'};
				delete $$sub_param{'child name'};
				$gen_params->{$key} = [ $sub_param ];
			}
		}
		else {
			die "Syntax error in TMPL_* tag" 
				if /^<(?:!--\s*)\/?TMPL_/i;
			$text .= $_;
		}
	}

	${$opts->{gen_params}} = $gen_params if ref $opts->{gen_params};
	return $text;
}

sub print_params {
		$\ = "\n";
		my $hash = shift;
		my $outline = shift;
		$outline = '' unless defined $outline;

		for(keys %$hash) {
				my $val = $$hash{$_}; 
				if(ref($val) eq 'ARRAY') {
					print "$outline$_ =>";
					print_params($_, $outline."\t") for(@$val);
				}
				else {
					print "$outline'$_'";
				}
		}
		undef $\ unless $outline;
}

# Preloaded methods go here.

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

HTML::Template::Convert::TT	- translates HTML::Template syntax into Template Toolkit

=head1 SYNOPSIS

  use HTML::Template::Convert::TT;
  use Template;

  my $ht_string = 'Hello, <TMPL_VAR wonderfull> world!';

  $tt_string = convert(\$ht_string);

  my $tt = Template->new;
  $tt->process(\$tt_string, { wonderfull => "wonderful" });

=head1 DESCRIPTION

This module translates L<HTML::Template> templates into L<Template::Toolkit> syntax.

You'll probably use it in a short service script, to convert your yout HT templates
to TT2 syntax out of band:

  #!perl
  # convert_ht2tt.pl

  use HTML::Template::Convert::TT;
  my $tt = convert($ARGV[0]);
  print $tt;

And then you'd do:

  $ convert_ht2tt.pl views/template.ht > views/template.tt

=head2 FUNCTIONS

B<convert>

If you pass a scalar, convert() assumes it's a filename, opens it and parses its contents.
But you can also pass the raw template by calling convert() with a scalar reference.

Until version 0.04 INCLUDE'ed files in templates were read and included for output, which
in version 0.05 is now the other way round. Pass "resolve_includes" => 1 in options to change
this.

=head2 EXPORT

convert($text, \$options)
convert('text', \$options)

=head1 SEE ALSO

Formerly, this code lived at L<http://code.google.com/p/html-template-convert/> which is
closed/ read-only now.

=head1 AUTHOR

A. D. Solovets, E<lt>asolovets@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009, 2016 A. D. Solovets and contributors.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.

=cut
