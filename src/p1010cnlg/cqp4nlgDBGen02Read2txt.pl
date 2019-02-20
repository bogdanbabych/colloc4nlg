#!/usr/bin/perl
# creating a gdbm file from a tab separated format
use GDBM_File ;
my ($filename, $filename2, %hashDB, %hashDB2, $key, $val);


my $filename2 = './cqp4nlgKW2Templates01.gdbm';
tie %hashDB2, 'GDBM_File', $filename2, &GDBM_READER, 0640; 

while (($key, $val) = each %hashDB2) {
    print "$key\t$val\n";
}

untie %hashDB2;
