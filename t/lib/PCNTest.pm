use 5.010;
use strict;
use warnings;
package PCNTest;
use Path::Class;
use File::Temp; 

use parent 'Exporter';
our @EXPORT = qw/make_tree/;

sub make_tree {
  my $td = File::Temp->newdir;
  for ( @_ ) {
    my $item = /\/$/ ? dir($td, $_) : file($td, $_);
    if ( $item->is_dir ) {
      $item->mkpath;
    }
    else {
      $item->parent->mkpath;
      $item->touch;
    }
  }
  return $td;
}


1;

