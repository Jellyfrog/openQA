# Copyright (C) 2017-2018 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.

package OpenQA::Parser::Result;
# Base class that holds the test result
# Used while parsing from format X to Whatever

use Mojo::Base -base;
use OpenQA::Parser::Results;
use OpenQA::Parser;

use Mojo::JSON qw(decode_json encode_json);
use Carp 'croak';
use Mojo::File 'path';
use Scalar::Util qw(blessed reftype);

sub new {
    return shift->SUPER::new(@_) unless @_ > 1 && reftype $_[1] && reftype $_[1] eq 'HASH' && !blessed $_[1];

    my ($class, @args) = @_;
    OpenQA::Parser::_restore_tree_section($args[0]);
    $class->SUPER::new(@args);
}

sub get { OpenQA::Parser::Result::Node->new(val => shift->{shift()}) }

sub to_json   { encode_json shift }
sub from_json { shift->new(decode_json shift()) }
sub to_hash {
    my $self = shift;
    return {
        map {
                $_ => blessed $self->{$_} && $self->{$_}->can("to_hash") ? $self->{$_}->to_hash
              : blessed $self->{$_} && $self->{$_}->can("to_array") ? $self->{$_}->to_array
              : $self->{$_}
          }
          sort keys %{$self}};
}

sub to_el {
    my $self = shift;

    return {
        map { $_ => blessed $self->{$_} && $self->{$_}->can("_gen_tree_el") ? $self->{$_}->_gen_tree_el : $self->{$_} }
        sort keys %{$self}};
}

sub _gen_tree_el {
    my $el = shift;
    return {OpenQA::Parser::DATA_FIELD() => $el->to_el, OpenQA::Parser::TYPE_FIELD() => ref $el};
}

sub write {
    my ($self, $path) = @_;
    croak __PACKAGE__ . ' write() requires a path' unless $path;
    path($path)->spurt($self->to_json);
}

*TO_JSON     = \&to_hash;
*write_json  = \&write;
*_restore_el = \&OpenQA::Parser::_restore_el;

# Separate package is done to avoid unpleasant AUTOLOAD situations
{
    package OpenQA::Parser::Result::Node;
    use Mojo::Base 'OpenQA::Parser::Result';
    has 'val';
    sub get { $_[0]->new(val => $_[0]->val->{$_[1]}) }

    sub AUTOLOAD {
        our $AUTOLOAD;
        my $fn = $AUTOLOAD;
        $fn =~ s/.*:://;
        return if $fn eq "DESTROY";
        return shift->get($fn);
    }
}

=encoding utf-8

=head1 NAME

OpenQA::Parser::Result - Baseclass of parser result

=head1 SYNOPSIS

    use OpenQA::Parser::Result;

    my $result = OpenQA::Parser::Result->new();

=head1 DESCRIPTION

OpenQA::Parser::Result is the base object representing a result.
Elements of the parser tree that represent a HASH needs to inherit this class.

=head1 METHODS

OpenQA::Parser::Result inherits all methods from L<Mojo::Base>
and implements the following new ones:

=head2 get()

    use OpenQA::Parser::Result;

    my $result = OpenQA::Parser::Result->new({ foo => { bar => 'baz' }});
    my $section = $result->get('foo');
    my $baz = $section->get('bar')->val();

Returns a L<OpenQA::Parser::Result::Node> object, which represent a subsection of the hash.
L<OpenQA::Parser::Result::Node> exposes only C<get()> and C<val()> methods and uses AUTOLOAD
features for sub-tree resolution.

C<get()> is used for getting further tree sub-sections,
it always returns a new L<OpenQA::Parser::Result::Node> which is a subportion of the result.
C<val()> returns the associated value.

=head2 write()

    use OpenQA::Parser::Result;

    my $result = OpenQA::Parser::Result->new({ foo => { bar => 'baz' }});
    $result->write('to_file.json');

It will encode and write the result as JSON.

=head2 TO_JSON

    my $hash = $result->TO_JSON;

Alias for L</"to_hash">.

=head2 to_json()

    use OpenQA::Parser::Result;

    my $result = OpenQA::Parser::Result->new({ foo => { bar => 'baz' }});
    my $json = $result->to_json();

It will encode and return a string that is the JSON representation of the result.

=head2 from_json()

    use OpenQA::Parser::Result;

    my $result = OpenQA::Parser::Result->new()->from_json($json_data);

It will restore the result and return a new result object representing it.

=head2 to_hash()

    use OpenQA::Parser::Result;

    my $result = OpenQA::Parser::Result->new({ foo => { bar => 'baz' }});
    my $json = $result->to_hash();

Turn object into hash reference.

=head2 to_el()

    use OpenQA::Parser::Result;

    my $result = OpenQA::Parser::Result->new({ foo => { bar => 'baz' }});
    my $el = $result->to_el();

It will encode the result and return a parser tree leaf representation.

=cut

1;
