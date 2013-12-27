#!/usr/bin/perl -w

use strict;
use warnings;

use Getopt::Long;
use Math::Trig qw(great_circle_distance deg2rad);
use Math::Round;

use Smart::Comments;
use YAML;

my ($file, $lat_centre, $long_centre, $radius, $distance, $keys) = (undef, undef, undef, undef, undef, 2);
GetOptions(
    "file=s"        => \$file,
    "lat-centre=f"  => \$lat_centre,
    "long-centre=f" => \$long_centre,
    "radius=i"      => \$radius,
    "distance"      => \$distance,
    "keys=i"        => \$keys,
);

### centre lat: $lat_centre
### centre long: $long_centre

my $document = do {
    local $/ = undef;
    open my $fh, "<", $file
        or die "could not open $file: $!";
    <$fh>;
};

## $document

my @all_portal_data = $document =~ m{<div class="pl_content pl_broad">(.*?)</div>}gs;

### found: scalar(@all_portal_data) . " entries"

my $portals = {};

foreach my $portal_data ( @all_portal_data ) {
    ## $portal_data
    $portal_data =~ m{data-plat="(.*?)" data-plng="(.*?)">(.*?)</span>.*?\((.*?)\)}gs
      or die "unable to parse portal data";
    my ($lat, $long, $name, $address) = ($1, $2, $3, $4);

    # Notice the 90 - latitude: phi zero is at the North Pole.
    my @L = (deg2rad($long),        deg2rad(90 - $lat));
    my @T = (deg2rad($long_centre), deg2rad(90 - $lat_centre));
    my $distance = round( great_circle_distance(@L, @T, 6378 * 1000) ); # equatorial radius of 6378 km

    my $identifier = join('', split('\.', $lat)).join('', split('\.', $long));

    $portals->{$identifier} = {
        lat      => $lat,
        long     => $long,
        name     => $name,
        address  => $address,
        distance => $distance,
    } if $distance < $radius;
}

my $ordered = [
    map { $portals->{$_} }
#    sort { $portals->{$a}->{distance} <=> $portals->{$b}->{distance} }
    sort { $portals->{$a}->{name} cmp $portals->{$b}->{name} }
    keys %{$portals}
];

## $ordered
### found: scalar(keys %{$portals}) . " portals"

### --------------------------------
foreach my $portal (@{$ordered}) {
    print join('', split('\.', $portal->{name})); print ", ";
    printf '%f', $portal->{lat};
    print ", "; printf '%f', $portal->{long};
    print ", $keys"; # for maxfield script
    print ", ". $portal->{distance}."m" if $distance; 
    print "\n";
}


