#!/usr/bin/perl
# creating a gdbm file from a tab separated format
use GDBM_File ;
my ($filename, $filename2, %hashDB, %hashDB2, $key, $val);

$filename = './cqp4nlgDBGen02TemplatesX01.gdbm';
# splitting on the first tab;

tie %hashDB, 'GDBM_File', $filename, &GDBM_WRCREAT, 0640;


$i = 0;

    foreach my $line (<STDIN>) {
    $i++;
    # if ($i % 10000 == 0){ print STDERR "$i :: $line \n"};
    chomp $line;
    if ($line =~ /^(.+?)\t(.+)$/){
        $word = $1;
        $rest = $2;
        # $lemma = $3;
        $hashDB{"$word"} = $rest ;
        
        if ($i % 10000 == 0){ 
            print STDERR "$word :: $rest\n";
            # $hashDB{"$word"} = $rest ;
            
        };

    };
    
    # print "$word;$rest\n";


}


untie %hashDB ;


