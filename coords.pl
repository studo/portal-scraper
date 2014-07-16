#!/usr/bin/perl -w

use strict;
use warnings;

use Getopt::Long;
use Math::Trig qw(great_circle_distance deg2rad);
use Math::Round;

use Smart::Comments;
use YAML;

my ($file, $lat_centre, $long_centre, $radius, $distance, $maxfield) = (undef, undef, undef, undef, undef, undef);
GetOptions(
    "file=s"        => \$file,
    "lat-centre=f"  => \$lat_centre,
    "long-centre=f" => \$long_centre,
    "radius=i"      => \$radius,
    "distance"      => \$distance,
    "maxfield"      => \$maxfield,
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

my @all_portal_data = $document =~ m{<tr class="(?:res|enl|neutral)">(.*?)</tr>}gs;

### found: scalar(@all_portal_data) . " entries"

my $portals = {};

my $longest_name = 0;
foreach my $portal_data ( @all_portal_data ) {
    ## $portal_data
    $portal_data =~ m{<a\sondblclick="window\.zoomToAndShowPortal\('.*?',\s\[(.*?),(.*?)\]\);return\sfalse"\sonclick="window\.renderPortalDetails\('.*?'\);return\sfalse"\shref=".*?">(.*?)</a>}gs
      or die "unable to parse portal data";
    my ($lat, $long, $name) = ($1, $2, $3);

    my $distance;
    if ( $long_centre && $lat_centre ) {
        # Notice the 90 - latitude: phi zero is at the North Pole\s
        my @L = (deg2rad($long),        deg2rad(90 - $lat));
        my @T = (deg2rad($long_centre), deg2rad(90 - $lat_centre));
        $distance = round( great_circle_distance(@L, @T, 6378 * 1000) ); # equatorial radius of 6378 km
    }

    if ($maxfield) {
        $name = join('', split('\.|,', $name));
        $lat  = join('', split('\.', $lat));
        my $lat_length = length $lat;
        my $lat_missing = 8 - $lat_length;
        while ( $lat_missing > 0 ) {
            $lat = $lat * 10;
            $lat_missing--;
        }
        $long = join('', split('\.', $long));
        my $long_length = length $long;
        my $long_missing = 8 - $long_length;
        while ( $long_missing > 0 ) {
            $long = $long * 10;
            $long_missing--;
        }
    }

    my $identifier = join('', split('\.', $lat)).join('', split('\.', $long));
    $portals->{$identifier} = {
        lat      => $lat,
        long     => $long,
        name     => $name,
        distance => $distance,
    } if !$distance || ($distance && $distance < $radius);

    $longest_name = length($name) if length($name) > $longest_name;
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
$longest_name++; $longest_name++;
foreach my $portal (@{$ordered}) {
    printf "%-${longest_name}s", $portal->{name}.',';
    if ($maxfield) {
        print $portal->{lat}, ', ', $portal->{long};
    }
    else {
        printf '%f, %f', $portal->{lat}, $portal->{long};
    }
    print ", 0" if $maxfield;
    print ", ". $portal->{distance}."m" if $distance;
    print "\n";
}
