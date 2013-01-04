#!/usr/bin/perl -wl

use strict;
use JSON;

my @factions;
my %factions;
my @cults = qw(EARTH FIRE WATER AIR);
my @ledger = ();
my %map = ();
my @error = ();

my %setups = (
    Alchemists => { C => 15, W => 3, P1 => 5, P2 => 7,
                    WATER => 1, FIRE => 1, color => 'black',
                    buildings => {
                        D => { cost => { W => 1, C => 2 } },
                        TP => { cost => { W => 2, C => 3 } },
                        TE => { cost => { W => 2, C => 5 } },
                        SH => { cost => { W => 4, C => 6 } },
                        SA => { cost => { W => 4, C => 6 } },
                    }},
    Auren => { C => 15, W => 3, P1 => 5, P2 => 7,
               WATER => 1, AIR => 1, 'ACTA' => 1,
               color => 'green',
               buildings => {
                   D => { cost => { W => 1, C => 2 } },
                   TP => { cost => { W => 2, C => 3 } },
                   TE => { cost => { W => 2, C => 5 } },
                   SH => { cost => { W => 4, C => 6 } },
                   SA => { cost => { W => 4, C => 8 } },
               }},
    Swarmlings => { C => 20, W => 8, P1 => 3, P2 => 9,
                    FIRE => 1, EARTH => 1,
                    WATER => 1, AIR => 1, color => 'blue',
                    buildings => {
                        D => { cost => { W => 2, C => 3 } },
                        TP => { cost => { W => 3, C => 4 } },
                        TE => { cost => { W => 3, C => 6 } },
                        SH => { cost => { W => 5, C => 8 } },
                        SA => { cost => { W => 5, C => 8 } },
                    }},
    Nomads => { C => 15, W => 2, P1 => 5, P2 => 7,
                FIRE => 1, EARTH => 1, color => 'yellow',
                ACTN => 1,
                buildings => {
                    D => { cost => { W => 1, C => 2 } },
                    TP => { cost => { W => 2, C => 3 } },
                    TE => { cost => { W => 2, C => 5 } },
                    SH => { cost => { W => 4, C => 8 } },
                    SA => { cost => { W => 4, C => 6 } },
                }},
    Engineers => { C => 10, W => 2, P1 => 3, P2 => 9, color => 'gray',
                buildings => {
                    D => { cost => { W => 1, C => 1 } },
                    TP => { cost => { W => 1, C => 2 } },
                    TE => { cost => { W => 1, C => 4 } },
                    SH => { cost => { W => 3, C => 6 } },
                    SA => { cost => { W => 3, C => 6 } },
                }},
);

my %pool = (
    # Resources
    C => 1000,
    W => 1000,
    P => 1000,
    VP => 1000,

    # Power
    P1 => 10000,
    P2 => 10000,
    P3 => 10000,

    # Cult tracks
    EARTH => 100,
    FIRE => 100,
    WATER => 100,
    AIR => 100,
    );

$pool{"ACT$_"}++ for 1..6;
$pool{"BON$_"}++ for 1..9;
$map{"BON$_"}{C} = 0 for 1..9;
$pool{"FAV$_"}++ for 1..4;
$pool{"FAV$_"} += 3 for 5..12;

for my $cult (@cults) {
    $map{"${cult}1"} = { gain => { $cult => 3 } };
    $map{"${cult}$_"} = { gain => { $cult => 2 } } for 2..4;
}

my %favors = (
    FAV1 => { gain => { FIRE => 3 }, income => {} },
    FAV2 => { gain => { WATER => 3 }, income => {} },
    FAV3 => { gain => { EARTH => 3 }, income => {} },
    FAV4 => { gain => { AIR => 3 }, income => {} },

    FAV5 => { gain => { FIRE => 2 }, income => {} }, # Town
    FAV6 => { gain => { WATER => 2 }, income => {} }, # +1 cult
    FAV7 => { gain => { EARTH => 2 }, income => { W => 1, PW => 1} },
    FAV8 => { gain => { AIR => 2 }, income => { PW => 4} },

    FAV9 => { gain => { FIRE => 1 }, income => { C => 3} },
    FAV10 => { gain => { WATER => 1 }, income => {} }, # vp: 3*TP
    FAV11 => { gain => { EARTH => 1 }, income => {} }, # vp: 2*D
    FAV12 => { gain => { AIR => 1 }, income => {} }, # vp: TPs
);

my @map = qw(brown gray green blue yellow red brown black red green blue red black E
             yellow x x brown black x x yellow black x x yellow E
             x x black x gray x green x green x gray x x E
             green blue yellow x x red blue x red x red brown E
             black brown red blue black brown gray yellow x x green black blue E
             gray green x x yellow green x x x brown gray brown E
             x x x gray x red x green x yellow black blue yellow E
             yellow blue brown x x x blue black x gray brown gray E
             red black gray blue red green yellow brown gray x blue green red E); 
my @bridges = ();

{
    my $ri = 0;
    for my $row ('A'..'I') {
        my $col = 1;
        for my $ci (0..13) {
            my $color = shift @map;
            last if $color eq 'E';
            if ($color ne 'x') {
                $map{"$row$col"}{color} = $color;
                $map{"$row$col"}{row} = $ri;
                $map{"$row$col"}{col} = $ci;
                $col++;
            }
        }
        $ri++;
    }
}

sub setup {
    my $faction = ucfirst shift;

    die "Unknown faction: $faction\n" if !$setups{$faction};

    $factions{$faction} = $setups{$faction};    
    $factions{$faction}{P} ||= 0;
    $factions{$faction}{P1} ||= 0;
    $factions{$faction}{P2} ||= 0;
    $factions{$faction}{P3} ||= 0;

    for (@cults) {
        $factions{$faction}{$_} ||= 0;
    }

    $factions{$faction}{D} = 8;
    $factions{$faction}{TP} = 4;
    $factions{$faction}{SH} = 1;
    $factions{$faction}{TE} = 3;
    $factions{$faction}{SA} = 1;
    $factions{$faction}{VP} = 20;

    push @factions, $faction;
}

sub command;

sub command {
    my ($faction, $command) = @_;
    my $type;

    if ($command =~ /^([+-])(\d*)(\w+)$/) {
        die "Need faction for command $command\n" if !$faction;
        my ($sign, $count) = (($1 eq '+' ? 1 : -1),
                              ($2 eq '' ? 1 : $2));
        $type = uc $3;

        if ($type eq 'PW') {
            for (1..$count) {
                if ($sign > 0) {
                    if ($factions{$faction}{P1}) {
                        $factions{$faction}{P1}--;
                        $factions{$faction}{P2}++;
                        $type = 'P1';
                    } elsif ($factions{$faction}{P2}) {
                        $factions{$faction}{P2}--;
                        $factions{$faction}{P3}++;
                        $type = 'P2';
                    } else {
                        return $count - 1;
                    }
                } else {
                    $factions{$faction}{P1}++;
                    $factions{$faction}{P3}--;
                    $type = 'P3';
                }
            }

            return $count;
        } else {
            my $orig_value = $factions{$faction}{$type};

            $pool{$type} -= $sign * $count;
            $factions{$faction}{$type} += $sign * $count;

            if ($pool{$type} < 0) {
                die "Not enough '$type' in pool after command '$command'\n";
            }

            if ($type =~ /^FAV/) {
                my %gain = %{$favors{$type}{gain}};

                for (keys %gain) {
                    command $faction, "+$gain{$_}$_";
                }
            }

            if ($type =~ /FIRE|WATER|EARTH|AIR/) {
                my $new_value = $factions{$faction}{$type};
                if ($orig_value <= 2 && $new_value > 2) {
                    command $faction, "+1pw";
                }
                if ($orig_value <= 4 && $new_value > 4) {
                    command $faction, "+2pw";
                }
                if ($orig_value <= 6 && $new_value > 6) {
                    command $faction, "+2pw";
                }
                if ($orig_value <= 9 && $new_value > 9) {
                    command $faction, "+3pw";
                }
            }
        }

        if ($type =~ /^BON/) {
            $factions{$faction}{C} += $map{$type}{C};
            $map{$type}{C} = 0;
        }
    } elsif ($command =~ /^(free\s+)?(\w+)->(\w+)$/) {
        die "Need faction for command $command\n" if !$faction;

        my $free = $1;
        $type = uc $2;
        my $where = uc $3;
        die "Unknown location '$where'" if !$map{$where};

        my $oldtype = $map{$where}{building};
        if ($oldtype) {
            $factions{$faction}{$oldtype}++;
        }

        if (exists $map{$where}{gain}) {
            my %gain = %{$map{$where}{gain}};
            for my $type (keys %gain) {
                command $faction, "+$gain{$type}$type";
                delete $gain{$type};
            }
        }

        if (!$free and
            exists $factions{$faction}{buildings}{$type}{cost}) {
            my %cost = %{$factions{$faction}{buildings}{$type}{cost}};

            for my $type (keys %cost) {
                command $faction, "-$cost{$type}$type";
            }
        }

        $map{$where}{building} = $type;
        $map{$where}{color} = $factions{$faction}{color};

        $factions{$faction}{$type}--;
    } elsif ($command =~ /^burn (\d+)$/) {
        die "Need faction for command $command\n" if !$faction;
        $factions{$faction}{P2} -= 2*$1;
        $factions{$faction}{P3} += $1;
        $type = 'P2';
    } elsif ($command =~ /^leech (\d+)$/) {
        die "Need faction for command $command\n" if !$faction;
        my $pw = $1;
        my $actual_pw = command $faction, "+${pw}PW";
        my $vp = $actual_pw - 1;

        command $faction, "-${vp}VP";
    } elsif ($command =~ /^(\w+):(\w+)$/) {
        my $where = uc $1;
        my $color = lc $2;
        $map{$where}{color} = $color;
    } elsif ($command =~ /^bridge (\w+):(\w+)$/) {
        die "Need faction for command $command\n" if !$faction;

        my $from = uc $1;
        my $to = uc $2;
        push @bridges, {from => $from, to => $to, color => $factions{$faction}{color}};
    } elsif ($command =~ /^pass (\w+)$/) {
        die "Need faction for command $command\n" if !$faction;
        my $bon = $1;

        $factions{$faction}{passed} = 1;
        for (keys %{$factions{$faction}}) {
            next if !$factions{$faction}{$_};

            if (/^BON/) {
                command $faction, "-$_"
            }
        }
        command $faction, "+$bon"
    } elsif ($command =~ /^block (\w+)$/) {
        my $where = uc $1;
        if ($where !~ /^ACT/) {
            $where .= "/$faction";
        }
        if ($map{$where}{blocked}) {
            die "Action space $where is blocked"
        }
        $map{$where}{blocked} = 1;
    } elsif ($command =~ /^action (\w+)$/) {
        my $where = uc $1;
        my $name = $where;
        if ($where !~ /^ACT/) {
            $where .= "/$faction";
        }

        my %act = (
            ACT1 => { cost => { PW => 3 }, gain => {}},
            ACT2 => { cost => { PW => 3 }, gain => { P => 1 } },
            ACT3 => { cost => { PW => 4 }, gain => { W => 2 } },
            ACT4 => { cost => { PW => 4 }, gain => { C => 7 } },
            ACT5 => { cost => { PW => 4 }, gain => {} },
            ACT6 => { cost => { PW => 6 }, gain => {} },
            ACTA => { cost => {}, gain => {} },
            ACTN => { cost => {}, gain => {} },
            BON1 => { cost => {}, gain => {} },
            BON2 => { cost => {}, gain => {} },
            FAV6 => { cost => {}, gain => {} },
            );
        
        if ($act{$name}) {
            my %cost = %{$act{$name}{cost}};
            for my $currency (keys %cost) {
                command $faction, "-$cost{$currency}$currency";
            }
            my %gain = %{$act{$name}{gain}};
            for my $currency (keys %gain) {
                command $faction, "+$gain{$currency}$currency";
            }
        } else {
            die "Unknown action $name";
        }

        if ($map{$where}{blocked}) {
            die "Action space $where is blocked"
        }
        $map{$where}{blocked} = 1;
    } elsif ($command =~ /^clear$/) {
        $map{$_}{blocked} = 0 for keys %map;
        $factions{$_}{passed} = 0 for keys %factions;
        for (1..9) {
            if ($pool{"BON$_"}) {
                $map{"BON$_"}{C}++;
            }
        }
    } elsif ($command =~ /^setup (\w+)$/) {
        setup $1;
    } elsif ($command =~ /delete (\w+)$/) {
        delete $pool{uc $1};
    } else {
        die "Could not parse command '$command'.\n";
    }

    if ($type and $faction) {
        if ($factions{$faction}{$type} < 0) {
            die "Not enough '$type' in $faction after command '$command'\n";
        }
    }
}

sub handle_row {
    local $_ = shift;

    # Comment
    if (s/#(.*)//) {
        push @ledger, { comment => $1 };
    }

    s/\s+/ /g;

    my $prefix = '';

    if (s/^(.*?)://) {
        $prefix = ucfirst lc $1;
    }

    my @commands = split /[.]/, $_;

    for (@commands) {
        s/^\s+//;
        s/\s+$//;
        s/(\W)\s(\w)/$1$2/g;
        s/(\w)\s(\W)/$1$2/g;
    }

    @commands = grep { /\S/ } @commands;

    return if !@commands;

    if ($factions{$prefix} or $prefix eq '') {
        my @fields = qw(VP C W P P1 P2 P3 PW D TP TE SH SA
                        FIRE WATER EARTH AIR CULT);
        my %old_data = map { $_, $factions{$prefix}{$_} } @fields; 

        for my $command (@commands) {
            command $prefix, lc $command;
        }

        my %new_data = map { $_, $factions{$prefix}{$_} } @fields;

        if ($prefix) {
            $old_data{PW} = $old_data{P2} + 2 * $old_data{P3};
            $new_data{PW} = $new_data{P2} + 2 * $new_data{P3};

            $old_data{CULT} = $old_data{FIRE} +  $old_data{WATER} + $old_data{EARTH} + $old_data{AIR};
            $new_data{CULT} = $new_data{FIRE} +  $new_data{WATER} + $new_data{EARTH} + $new_data{AIR};

            my %delta = map { $_, $new_data{$_} - $old_data{$_} } @fields;
            my %pretty_delta = map { $_, ($delta{$_} ?
                                          sprintf "%+d [%d]", $delta{$_}, $new_data{$_} :
                                          '')} @fields;
            if ($delta{PW}) {
                $pretty_delta{PW} = sprintf "%+d [%d/%d/%d]", $delta{PW}, $new_data{P1}, $new_data{P2}, $new_data{P3};
            }

            if ($delta{CULT}) {
                $pretty_delta{CULT} = sprintf "%+d [%d/%d/%d/%d]", $delta{CULT}, $new_data{FIRE}, $new_data{WATER}, $new_data{EARTH}, $new_data{AIR};
            }

            push @ledger, { faction => $prefix,
                            commands => (join ". ", @commands),
                            map { $_, $pretty_delta{$_} } @fields};
        }
    } else {
        die "Unknown prefix: '$prefix' (expected one of ".
            (join ", ", keys %factions).
            ")\n";
    }
}

sub print_pretty {
    local *STDOUT = *STDERR;
    for (@factions) {
        my %f = %{$factions{$_}};

        print ucfirst $_, ":";
        print "  VP: $f{VP}";
        print "  Resources: $f{C}c / $f{W}w / $f{P}p, $f{P1}/$f{P2}/$f{P3} power";
        print "  Buildings: $f{D} D, $f{TP} TP, $f{TE} TE, $f{SH} SH, $f{SA} SA";
        print "  Cults: $f{FIRE} / $f{WATER} / $f{EARTH} / $f{AIR}";

        for (1..9) {
            if ($f{"BON$_"}) {
                print "  Bonus: $_";
            }
        }

        for (1..12) {
            if ($f{"FAV$_"}) {
                print "  Favor: $_";
            }
        }
    }

    for my $cult (@cults) {
        printf "%-8s", "$cult:";
        for (1..4) {
            my $key = "$cult$_";
            printf "%s / ", ($map{"$key"}{building} or ($_ == 1 ? 3 : 2));
        }
        print "";
    }
}

sub print_json {
    my $out = encode_json {
        order => \@factions,
        map => \%map,
        factions => \%factions,
        pool => \%pool,
        bridges => \@bridges,
        ledger => \@ledger,
        error => \@error,
    };

    print $out;
}

while (<>) {
    eval { handle_row $_ };
    if ($@) {
        chomp;
        push @error, "Error on line $. [$_]:";
        push @error, "$@\n";
        last;
    }
}

print_pretty;
print_json;

if (@error) {
    print STDERR $_ for @error;
    exit 1;
}
