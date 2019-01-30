#!/usr/bin/perl

use GDBM_File ;
my ($filename, $filename2, %hashDB, %hashDB2, $key, $val);

$filename = './cqp4nlgKWDB.gdbm';


tie %hashDB, 'GDBM_File', $filename, &GDBM_WRCREAT, 0640;
# Use the %hash array.

# %hashDB = (
#     "apple"  => "red,0.5,6.0",
#     "orange" => "orange,0.5,6.0",
#     "grape"  => "purple,0.5,6.0",
#     "watermelon"  => "redNblack,0.5,6.0",
# );
# $hashDB{"melon"} = "yellow,0.5,6.0";


$i = 0;
my %hashNDocsWord;
my %hashNSentWord;

foreach my $line (<STDIN>) {
    $i++;
    if ($i % 10000 == 0){ print STDERR "$i :: $line \n"};
    chomp $line;
    if ($line =~ /^(.+)\t(.+)\t(.+)$/){
        $word = $1;
        $pos = $2;
        $lemma = $3;

    };
    print "$lemma\n";


}


untie %hashDB ;

my $filename2 = "./cqp4nlgKWDB.gdbm";
tie %hashDB2, 'GDBM_File', $filename2, &GDBM_READER, 0640; 

while (($key, $val) = each %hashDB2) {
    print "$key::$val\n";
}

untie %hashDB2;
