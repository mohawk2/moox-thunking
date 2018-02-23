package MooX::Thunking;

our $VERSION = '0.08';

# this bit would be MooX::Utils but without initial _ on func name
use strict;
use warnings;
use Moo ();
use Moo::Role ();
use Carp qw(croak);
#use base qw(Exporter);
#our @EXPORT = qw(override_function);
sub _override_function {
  my ($target, $name, $func) = @_;
  my $orig = $target->can($name) or croak "Override '$target\::$name': not found";
  my $install_tracked = Moo::Role->is_role($target) ? \&Moo::Role::_install_tracked : \&Moo::_install_tracked;
  $install_tracked->($target, $name, sub { $func->($orig, @_) });
}
# end MooX::Utils;

use Types::TypeTiny -all;
use Type::Utils -all;
use Class::Method::Modifiers qw(install_modifier);
sub import {
  my $target = scalar caller;
  _override_function($target, 'has', sub {
    my ($orig, $namespec, %opts) = @_;
    $orig->($namespec, %opts), return if $opts{is} ne 'thunked';
    $opts{is} = 'rwp';
    $opts{isa} = union [ CodeLike, $opts{isa} ] if $opts{isa};
    $orig->($namespec, %opts); # so we have method to modify
    for my $name (ref $namespec ? @$namespec : $namespec) {
      my $resolved_name = "_${name}_resolved";
      $orig->($resolved_name, is => 'rw'); # cache whether resolved
      install_modifier $target, 'before', $name => sub {
        my $self = shift;
        return if @_; # attempt at setting, hand to auto
        return if $self->$resolved_name; # already resolved
        $self->$resolved_name(1);
        local $@;
        return if !eval { CodeLike->($self->{$name}); 1 }; # not a thunk
        my $setter = "_set_$name";
        $self->$setter($self->{$name}->());
      };
    }
  });
}

=head1 NAME

MooX::Thunking - Allow Moo attributes to be "thunked"

=head1 SYNOPSIS

  package Thunking;
  use Moo;
  use MooX::Thunking;
  use Types::TypeTiny -all;
  use Types::Standard -all;
  has children => (
    is => 'thunked',
    isa => ArrayRef[InstanceOf['Thunking']],
    required => 1,
  );

  package main;
  my $obj;
  $obj = Thunking->new(children => sub { [$obj] });

=head1 DESCRIPTION

This is a L<Moo> extension. It allows another value for the C<is>
parameter to L<Moo/has>: "thunked". If used, this will allow you to 
transparently provide either a real value for the attribute, or a
L<Types::TypeTiny/CodeLike> that when called will return such a real
value.

Note that in earlier versions of this module (up to 0.06), any C<isa>
had to pass a C<CodeLike>. This is now taken care of by this module. It
will continue to do the right thing if no C<isa> is supplied.

=head1 AUTHOR

Ed J

=head1 LICENCE

The same terms as Perl itself.

=cut

1;
