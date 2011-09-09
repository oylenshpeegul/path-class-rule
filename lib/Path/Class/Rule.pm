use 5.008001;
use strict;
use warnings;

package Path::Class::Rule;
# ABSTRACT: File finder using Path::Class
# VERSION

# Dependencies
use autodie 2.00;
use Path::Class;
use Scalar::Util qw/blessed reftype/;
use List::Util qw/first/;

#--------------------------------------------------------------------------#
# class methods
#--------------------------------------------------------------------------#

sub new {
  return bless { item_filter => sub {1} }, shift;
}

sub add_helper {
  my ($class, $name, $coderef) = @_;
  $class = ref $class || $class;
  if ( ! $class->can($name) ) {
    no strict 'refs';
    *$name = sub {
      my $self = shift;
      my $rule = $coderef->(@_);
      $self->add_rule( $rule )
    };
  }
}

#--------------------------------------------------------------------------#
# object methods
#--------------------------------------------------------------------------#

sub add_rule {
  my ($self, $rule) = @_;
  # XXX rule must be coderef
  if ( my $filter = $self->{item_filter} ) {
    $self->{item_filter} = sub { $filter->(@_) && $rule->(@_) };
  }
  else {
    $self->{item_filter} = $rule;
  }
  return $self;
}

my %defaults = (
  follow_symlinks => 1,
  depthfirst => 0,
);

sub iter {
  my $self = shift;
  my $args =  ref($_[0])  && !blessed($_[0])  ? shift
            : ref($_[-1]) && !blessed($_[-1]) ? pop : {};
  my $opts = { %defaults, %$args };
  my @queue = map { dir($_) } @_ ? @_ : '.';
  my $filter = $self->{item_filter};
  my $stash = $self->{stash};
  my %seen;

  return sub {
    LOOP: {
      my $item = shift @queue
        or return;
      if ( ! $opts->{follow_symlinks} ) {
        redo LOOP if -l $item;
      }
      local $_ = $item;
      my ($interest, $prune) = $filter->($item, $stash);
      if ($item->is_dir && ! $seen{$item}++ && ! $prune) {
        if ( $opts->{depthfirst} ) {
          my @next = sort $item->children;
          push @next, $item if $opts->{depthfirst} < 0; # repeat for postorder
          unshift @queue, @next;
          redo LOOP if $opts->{depthfirst} < 0;
        }
        else {
          push @queue, sort $item->children;
        }
      }
      return $item
        if $interest;
      redo LOOP;
    }
  };
}

sub all {
  my $self = shift;
  my $iter = $self->iter(@_);
  my @results;
  while ( my $item = $iter->() ) {
    push @results, $item;
  }
  return @results;
}

#--------------------------------------------------------------------------#
# common helpers
#--------------------------------------------------------------------------#

sub _regexify {
  my $re = shift;
  return ref($_) && reftype($_) eq 'REGEXP' ? $_ : qr/\b\Q$_\E\b/;
}

my %simple_helpers = (
  is_dir => sub { $_->is_dir },
  is_file => sub { ! $_->is_dir },
);

my %complex_helpers = (
  skip_dirs => sub {
    my @patterns = map { _regexify($_) } @_;
    return sub {
      my $f = shift;
      return (0,1) if $f->is_dir && first { $f =~ $_} @patterns;
      return 1;
    }
  },
);

while ( my ($k,$v) = each %complex_helpers ) {
  __PACKAGE__->add_helper( $k, $v );
}

while ( my ($k,$v) = each %simple_helpers ) {
  __PACKAGE__->add_helper( $k, sub { return $v } );
}

1;

=for Pod::Coverage method_names_here

=head1 SYNOPSIS

  use Path::Class::Rule;

  my $rule = Path::Class::Rule->new; # match anything
  $rule->is_file->not_empty;         # add/chain rules

  # iterator interface
  my $next = $rule->iter( @dirs, \%options);
  while ( my $file = $next->() ) {
    ...
  }

  # list interface
  for my $file ( $rule->all( @dirs, \%options ) {
    ...
  }

=head1 DESCRIPTION

There are many other file finding modules out there.  They all have various
features/deficiencies, depending on one's preferences and needs.  Here are
some features of this one:

=for :list
* uses iterators
* returns L<Path::Class> objects
* custom rules are given L<Path::Class> objects
* breadth-first (default) or pre- or post-order depth-first
* follows symlinks (by default, but can be disabled)
* provides an API for extensions

=head1 USAGE

=head2 C<new>

=head2 C<all>

=head2 C<iter>

=head1 RULES

=head2 C<add_rule>

=head2 C<is_file>

=head2 C<is_dir>

=head2 C<skip_dirs>

=head1 EXTENDING

XXX talk about how to extend this with new rules/helpers, e.g.

=head2 C<add_helper>

  package Path::Class::Rule::Foo;
  use Path::Class::Rule;
  Path::Class::Rule->add_helper(
    is_foo => sub {
      my @args = @_; # can use to customize rule
      return sub {
        my ($item) = shift;
        return $item->basename =~ /^foo$/;
      }
    }
  );

XXX talk about how to prune based on second return value

=head1 SEE ALSO


=for :list
* L<File::Find>
* L<File::Find::Node>
* L<File::Find::Rule>
* L<File::Finder>
* L<File::Next>
* L<Path::Class::Iterator>

=cut

# vim: ts=2 sts=2 sw=2 et:
