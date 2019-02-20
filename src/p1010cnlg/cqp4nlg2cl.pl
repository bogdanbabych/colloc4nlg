#!/usr/bin/perl
#CGI script for accessing CWB files
#die "unknown error\n"
use utf8;
use CGI;
use CGI::Carp qw/fatalsToBrowser/;
use Encode qw/encode decode/;
use GDBM_File;
use CWB::CQP;
use CWB::CL;
use Getopt::Long;
use lib("/corpora/tools");
use smallutils;
use cqpquery4nlg2cl;

#use strict;

$CGI::POST_MAX = 50 * 1024; # avoid denial-of-service attacks (accept max. 50k of POST data)
$spammessagelimit=1000;
binmode( STDOUT, ":utf8" );


$is_cgi = defined $ENV{'GATEWAY_INTERFACE'};



readconffile('/corpora/tools/cqp.conf');
readmessagefile('/corpora/tools/messages.conf');

$|=1;

$originalquery=""; # the search string
$parallel;

$cgiquery = new CGI;



$corpuslist=uc(  $cgiquery->param("c") || $cgiquery->param("corpuslist") );
if ($corpuslist) { # CGI run
    $cqpsyntaxonly=$cgiquery->param("cqpsyntaxonly");
    $defaultattrname=$cgiquery->param("searchpositional") || $cgiquery->param("da") || $defaultattrname;

    @parallel=$cgiquery->param("parallel");
    $parallel=uc(join(',',@parallel));

    $originalquery= $cgiquery->param("q") || $cgiquery->param("searchstring");
    die if length($originalquery)>$spammessagelimit;
    $contextsize=$cgiquery->param("cs") || $cgiquery->param("contextsize")|| $contextsize;
    $sort1option=$cgiquery->param("sort1") || $cgiquery->param("s1");
    $sort2option=$cgiquery->param("sort2") || $cgiquery->param("s2");
    $terminate=$cgiquery->param("terminate") || $cgiquery->param("t") || $terminate;
    $terminate=min($terminate,$terminatemax);

    $transliterateout=$cgiquery->param("transliterateout");
    $transliteratein=$cgiquery->param("transliteratein");
    $showtranslations=$cgiquery->param("showtranslations");  # this is for interfacing a dictionary
    $annot=$cgiquery->param("annot");

    $collocationstat=(lc($cgiquery->param("searchtype") eq 'colloc'));
# collocations for NLG
    $collocation4nlg=(lc($cgiquery->param("searchtype") eq 'colloc4nlg'));

    $nlgOutputPhrase0=(lc($cgiquery->param("nlgOutputType") eq 'nlgOutputPhrase'));
    $nlgOutputSentence0=(lc($cgiquery->param("nlgOutputType") eq 'nlgOutputSentence'));
    $nlgOutputSentenceFile0=$cgiquery->param("nlgOutputSentenceFile");
    
    
    $nlgFilterTemplate0 =$cgiquery->param("nlgFilterTemplate");

    # collocation statistics still should work
    # if($collocation4nlg){ # $collocationstat = $collocation4nlg;  };
    
    
    
    
    
    $mistat=$cgiquery->param("mistat");
    $dstat=$cgiquery->param("dstat");
    $tstat=$cgiquery->param("tstat");
    $llstat=$cgiquery->param("llstat");
    $cutoff=$cgiquery->param("cutoff") || $cutoff;
    $collocspanleft=$cgiquery->param("collocspanleft") || $cgiquery->param("cleft");
    $collocspanright=$cgiquery->param("collocspanright") || $cgiquery->param("cright");
    $collocfilter=$cgiquery->param("collocfilter") || $cgiquery->param("cfilter");

# collocations for NLG
    $collocspanleft1=$cgiquery->param("collocspanleft1") || $cgiquery->param("cleft1");
    $collocspanright1=$cgiquery->param("collocspanright1") || $cgiquery->param("cright1");
    $collocfilter1=$cgiquery->param("collocfilter1") || $cgiquery->param("cfilter1");

    $collocspanleft2=$cgiquery->param("collocspanleft2") || $cgiquery->param("cleft2");
    $collocspanright2=$cgiquery->param("collocspanright2") || $cgiquery->param("cright2");
    $collocfilter2=$cgiquery->param("collocfilter2") || $cgiquery->param("cfilter2");

    $collocspanleft3=$cgiquery->param("collocspanleft3") || $cgiquery->param("cleft3");
    $collocspanright3=$cgiquery->param("collocspanright3") || $cgiquery->param("cright3");
    $collocfilter3=$cgiquery->param("collocfilter3") || $cgiquery->param("cfilter3");

    $collocspanleft4=$cgiquery->param("collocspanleft4") || $cgiquery->param("cleft4");
    $collocspanright4=$cgiquery->param("collocspanright4") || $cgiquery->param("cright4");
    $collocfilter4=$cgiquery->param("collocfilter4") || $cgiquery->param("cfilter4");
    
    $keywordposition4nlg0=$cgiquery->param("keywordposition4nlg") || $cgiquery->param("keywordposition4nlg");
    $noofsentences4nlg=$cgiquery->param("noofsentences4nlg") || $cgiquery->param("noofsentences4nlg");
    $noofsentences4nlg5=$cgiquery->param("noofsentences4nlg5") || $cgiquery->param("noofsentences4nlg5");
    
    $noofsentences4nlg0 = $noofsentences4nlg + 0; # make sure this is the number
    $noofsentences4nlg50 = $noofsentences4nlg5 + 0; # make sure this is the number
   
    $printproofcolloc4nlg0=$cgiquery->param("printproofcolloc4nlg");
    $printproofscores4nlg0=$cgiquery->param("printproofscores4nlg");
    $rankproofcolloc4nlg0=$cgiquery->param("rankproofcolloc4nlg");
    
    $printcartesianpr4nlg0=$cgiquery->param("printcartesianpr4nlg");
    $onlycombinedcores4nlg0=$cgiquery->param("onlycombinedcores4nlg");
    
    $kwText4nlg0=$cgiquery->param("kwText4nlg");
    $kwTextBrief4nlg0=$cgiquery->param("kwTextBrief4nlg");
    $kwTextTfIdf4nlg0=$cgiquery->param("kwTextTfIdf4nlg");
    
    $nlg4Keyword = $cgiquery->param("nlg4Keyword");
    

    $learningrestrictlist=$cgiquery->param("learningrestrictlist");
    $encoding=$cgiquery->param("encoding") || $encoding;
#    $similaritysearch=$cgiquery->param("f");
    $debuglevel=$cgiquery->param('debuglevel') || $debuglevel;

    
    

} else { # non-CGI
    undef $cgiquery;
    GetOptions ('template=s' => \$nlgFilterTemplate0, 'keyword=s' => \$nlg4Keyword);
    # GetOptions ('D=s' => \$corpuslist, 'parallel=s' => \$parallel, 'align=i' => \$showhorizontal, 'q=s' => \$originalquery, 's1=s' => \$sort1option, 's2=s' => \$sort2option, 'ini=s' => \$inifile, 'context=s' => \$contextsize, 
	# 'terminate=i' => \$terminate, 'coll=i' => \$collocationstat, 'vector=i' => \$maxvector, 'measure=s' => \$measure, 
	# 'leftspan=i' => \$collocspanleft, 'rightspan=i' => \$collocspanright, 'filter=s' => \$collocfilter, 'dictionary=s' => \$dictionary, 
	# 'span=i' => \$spansize, 'help' => \$help);
    # $corpuslist=uc($corpuslist);
    # if ($parallel) {
	# @parallel=split ',',$parallel;
    # };


    # if ($collocationstat || $collocation4nlg) {
	# $contextsizecl='1w';
	# if ($measure) {
	#     $mistat=$measure=~/M/;
	#     $tstat=$measure=~/T/;
	#     $llstat=$measure=~/L/;
	# } else {
	#     $llstat=1;
	# }
    # }
    # if (-r $inifile) {
	# require($inifile);
    # }
}



if(not $is_cgi){
    readconffile('./cqp4nlg2cl.conf');
    

}else{
    $is_cgi++;
    $debugStr4ngl = "";
    $debugStr4ngl .= "\$corpuslist = $corpuslist; <br>\n";
    $debugStr4ngl .= "\$cqpsyntaxonly = $cqpsyntaxonly; <br>\n";
    $debugStr4ngl .= "\$defaultattrname = $defaultattrname; <br>\n";
    $debugStr4ngl .= "\@parallel = @parallel; <br>\n";
    $debugStr4ngl .= "\$parallel = $parallel; <br>\n";
    $debugStr4ngl .= "\$originalquery = $originalquery; <br>\n";
    $debugStr4ngl .= "\$spammessagelimit = $spammessagelimit; <br>\n";
    $debugStr4ngl .= "\$contextsize = $contextsize; <br>\n";
    $debugStr4ngl .= "\$sort1option = $sort1option; <br>\n";
    $debugStr4ngl .= "\$sort2option = $sort2option; <br>\n";
    $debugStr4ngl .= "\$terminate = $terminate; <br>\n";
    $debugStr4ngl .= "\$transliterateout = $transliterateout; <br>\n";
    $debugStr4ngl .= "\$transliteratein = $transliteratein; <br>\n";
    $debugStr4ngl .= "\$showtranslations = $showtranslations; <br>\n";
    $debugStr4ngl .= "\$annot = $annot; <br>\n";
    $debugStr4ngl .= "\$collocationstat = $collocationstat; <br>\n";
    $debugStr4ngl .= "\$collocation4nlg = $collocation4nlg; <br>\n";
    $debugStr4ngl .= "\$nlgOutputPhrase0 = $nlgOutputPhrase0; <br>\n";
    $debugStr4ngl .= "\$nlgOutputSentence0 = $nlgOutputSentence0; <br>\n";
    $debugStr4ngl .= "\$nlgOutputSentenceFile0 = $nlgOutputSentenceFile0; <br>\n";
    $debugStr4ngl .= "\$nlgFilterTemplate0 = $nlgFilterTemplate0; <br>\n";
    $debugStr4ngl .= "\$mistat = $mistat; <br>\n";
    $debugStr4ngl .= "\$dstat = $dstat; <br>\n";
    $debugStr4ngl .= "\$tstat = $tstat; <br>\n";
    $debugStr4ngl .= "\$llstat = $llstat; <br>\n";
    $debugStr4ngl .= "\$cutoff = $cutoff; <br>\n";
    $debugStr4ngl .= "\$collocspanleft = $collocspanleft; <br>\n";
    $debugStr4ngl .= "\$collocspanright = $collocspanright; <br>\n";
    $debugStr4ngl .= "\$collocfilter = $collocfilter; <br>\n";
    $debugStr4ngl .= "\$collocspanleft1 = $collocspanleft1; <br>\n";
    $debugStr4ngl .= "\$collocspanright1 = $collocspanright1; <br>\n";
    $debugStr4ngl .= "\$collocfilter1 = $collocfilter1; <br>\n";
    $debugStr4ngl .= "\$collocspanleft2 = $collocspanleft2; <br>\n";
    $debugStr4ngl .= "\$collocspanright2 = $collocspanright2; <br>\n";
    $debugStr4ngl .= "\$collocfilter2 = $collocfilter2; <br>\n";
    $debugStr4ngl .= "\$collocspanleft3 = $collocspanleft3; <br>\n";
    $debugStr4ngl .= "\$collocspanright3 = $collocspanright3; <br>\n";
    $debugStr4ngl .= "\$collocfilter3 = $collocfilter3; <br>\n";
    $debugStr4ngl .= "\$collocspanleft4 = $collocspanleft4; <br>\n";
    $debugStr4ngl .= "\$collocspanright4 = $collocspanright4; <br>\n";
    $debugStr4ngl .= "\$corpuscollocfilter4list = $collocfilter4; <br>\n";
    $debugStr4ngl .= "\$keywordposition4nlg0 = $keywordposition4nlg0; <br>\n";
    $debugStr4ngl .= "\$noofsentences4nlg = $noofsentences4nlg; <br>\n";
    $debugStr4ngl .= "\$noofsentences4nlg5 = $noofsentences4nlg5; <br>\n";
    $debugStr4ngl .= "\$noofsentences4nlg0 = $noofsentences4nlg0; <br>\n";
    $debugStr4ngl .= "\$noofsentences4nlg50 = $noofsentences4nlg50; <br>\n";
    $debugStr4ngl .= "\$printproofcolloc4nlg0 = $printproofcolloc4nlg0; <br>\n";
    $debugStr4ngl .= "\$printproofscores4nlg0 = $printproofscores4nlg0; <br>\n";
    $debugStr4ngl .= "\$rankproofcolloc4nlg0 = $rankproofcolloc4nlg0; <br>\n";
    $debugStr4ngl .= "\$printcartesianpr4nlg0 = $printcartesianpr4nlg0; <br>\n";
    $debugStr4ngl .= "\$onlycombinedcores4nlg0 = $onlycombinedcores4nlg0; <br>\n";
    $debugStr4ngl .= "\$kwText4nlg0 = $kwText4nlg0; <br>\n";
    $debugStr4ngl .= "\$kwTextBrief4nlg0 = $kwTextBrief4nlg0; <br>\n";
    $debugStr4ngl .= "\$kwTextTfIdf4nlg0 = $kwTextTfIdf4nlg0; <br>\n";
    $debugStr4ngl .= "\$learningrestrictlist = $learningrestrictlist; <br>\n";
    $debugStr4ngl .= "\$encoding = $encoding; <br>\n";
    $debugStr4ngl .= "\$similaritysearch = $similaritysearch; <br>\n";
    $debugStr4ngl .= "\$debuglevel = $debuglevel; <br>\n";
    $debugStr4ngl .= "\$nlg4Keyword = $nlg4Keyword; <br>\n"   
    # $debugStr4ngl .= "\$corpuslist = $corpuslist; <br>\n";

    
}

    
    
    
    
# moved from cgi interface section 
#
    if($collocation4nlg){

        @collocspans4nlg = ();
        push(@collocspans4nlg, "$collocspanleft1~$collocfilter1~$collocspanright1");
        push(@collocspans4nlg, "$collocspanleft2~$collocfilter2~$collocspanright2");
        push(@collocspans4nlg, "$collocspanleft3~$collocfilter3~$collocspanright3");
        # push(@collocspans4nlg, "$collocspanleft4~$collocfilter4~$collocspanright4");
        
    
    };

    if($nlg4Keyword){
        print STDERR "nlg4Keyword = $nlg4Keyword\n";
        my $filename101 = '/data/html/corpuslabs/lab201810cnlg/cqp4nlgDBGen02TemplatesCanada2018.gdbm';
        tie %hashDB1, 'GDBM_File', $filename101, &GDBM_READER, 0640; 
        my $filename102 = '/data/html/corpuslabs/lab201810cnlg/cqp4nlgDBGen02TemplatesBNC1994.gdbm';
        tie %hashDB2, 'GDBM_File', $filename102, &GDBM_READER, 0640;
        
        if(exists $hashDB1{$nlg4Keyword}){
            $nlgFilterTemplate0 = $hashDB1{$nlg4Keyword};
            
        }elsif(exists $hashDB2{$nlg4Keyword}){
            $nlgFilterTemplate0 = $hashDB2{$nlg4Keyword};
            
        }else{
            $nlgFilterTemplate0 = "";
    
        };
        
    
    };

    if($nlgFilterTemplate0){
        $strDebugX = "";
        @nlgFilterTemplate1 = split / /, $nlgFilterTemplate0;
        
        my ($ref_nlgFilterTemplateXPos, $ref_nlgFilterTemplateXLofLStop, $ref_nlgFilterTemplateXLofLGo, $ref_rejectTemp) = prepareNlgFilterTemplateX4NLG(@nlgFilterTemplate1);
        # process the command string: find pos filters, banned lexemes, injected words for positions
        
        
        @nlgFilterTemplateXPos = @{$ref_nlgFilterTemplateXPos};
        @nlgFilterTemplateXLofLStop = @{$ref_nlgFilterTemplateXLofLStop};
        @nlgFilterTemplateXLofLGo = @{$ref_nlgFilterTemplateXLofLGo};
        @rejectTemp = @{$ref_rejectTemp};
        
        @nlgFilterTemplateX1 = @nlgFilterTemplateXPos;
        
        $ICountEl = 0;
        
        # @injectTemp = ();
        foreach my $el (@nlgFilterTemplateXPos){
            $strDebugX = $strDebugX . "\n<br>:: nlgFilterTemplateXPos [ $ICountEl ] = ";
            $strDebugX = $strDebugX .  $nlgFilterTemplateXPos[$ICountEl];
            $strDebugX = $strDebugX .  " :: <br>\n";
            my $ref_LStop = $nlgFilterTemplateXLofLStop[$ICountEl];
            my $ref_LGo = $nlgFilterTemplateXLofLGo[$ICountEl];
            @LStop = @{$ref_LStop};
            @LGo = @{$ref_LGo};
            # $strDebugX = $strDebugX . "    ref_LStop = $ref_LStop ;; ref_LGo = $ref_LGo <br>\n";
            
            foreach my $wStop (@LStop){
                $strDebugX = $strDebugX .  ": wStop=$wStop :<br>\n";
                
            }
            foreach my $wGo (@LGo){
                $strDebugX = $strDebugX .  ": wGo=$wGo :<br>\n";
                
            }
            $ICountEl++;
    
        }
        # $strDebugX = $strDebugX . "     rejectTemp = @rejectTemp <br>\n";
        
        
    }
    
#
# end: moved from cgi interface section 



open(STDLOG, ">>:utf8", "/corpora/query.log") or die "Cannot open the log file.";
print STDLOG "\n\n";

$starttime=scalar(localtime());
print STDLOG "Local time: $starttime; ";
$starttime=time();

if ($debuglevel) {
    open(DEBUGLOG, ">>:utf8", "/corpora/debug.log") or print STDLOG "Attempted write to debug failed: $!\n";
    printdebug("Local time:",scalar(localtime()),"; script $0\n");
};

$curlang=$corpuslang{$corpuslist} || 'en';

if ($curlang eq 'en') { # these are the standard source and target language corpora
    $dict=$dictionaryenru;
    $cname='BNC';
    $newcorpus='RNC2009-MOCKY';
} elsif  ($curlang eq 'ru') {
    $dict=$dictionaryruen;
    $cname='RNC2009-MOCKY';
    $newcorpus='BNC';
};

if ($learningrestrictlist) {
    $learningrestrictstr=getlearningrestrictlist($cgiquery);
}

($contextsize, $contexttype)=$contextsize=~/(\d+)\s*(\w*)/;
$contextsizewords=$contextsize;
if ($contexttype eq 's') {
    $contextsize=min($contextsize,3);
    $contextsizewords=$contextsize*15;
} elsif ($contexttype eq 'c') {
    $charsize=min($contextsize,150);
} else {
    $charsize=min($contextsize*6,30);
    $contexttype='word';
}

#get information about the query with appropriate guessing
$remote_host=getremotehost($cgiquery) if $cgiquery;
#die if $remote_host=~/primacom.net/;
# preprocess the query
#utest($originalquery);
if ($originalquery=~/\xC3[\x80-\xBF]/) {
    $latin1query=1;
    $searchtitle=decode('utf8',"$corpuslist: $originalquery");
    utf8::upgrade($originalquery);
} else {
    utf8::upgrade($originalquery);
    $originalquery=decode('utf8',$originalquery);
    $searchtitle="$corpuslist: $originalquery";
}

if ($is_cgi){ # printing to webpage;
    print "Content-type: text/html\; charset=$encoding\n\n";
    print qq{<html><head><meta http-equiv="Content-Type" content="text/html; charset=$encoding">\n};
    print qq{<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
    <html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
    <head>
    <meta http-equiv="content-type" content="text/html; charset=$encoding" />
    <meta name="Author" content="Serge Sharoff, hacked by Marco Baroni, ripped by Emiliano Guevara" />
    <meta name="Keywords" content="Web Corpus" />
    <title>$searchtitle</title>
    <link href="/corpus.css" rel="stylesheet" type="text/css">
    };
    
    print qq{</head>\n<body>\n<div id="website">};

    # # test printing
    # # print "collocationstat $collocationstat <br>\n";
    # # print "collocation4nlg $collocation4nlg <br>\n";
    # # print "keywordposition4nlg0 = $keywordposition4nlg0 <br>\n";
    # # print "noofsentences4nlg0 = $noofsentences4nlg0 <br>\n";
    # # print "printproofcolloc4nlg0 = $printproofcolloc4nlg0 <br>\n";
    # # print "printcartesianpr4nlg0 = $printcartesianpr4nlg0 <br>\n";
    # # print "rankproofcolloc4nlg0 = $rankproofcolloc4nlg0 <br>\n";
    # # print "printproofscores4nlg0 = $printproofscores4nlg0 <br>\n";
    # # print "onlycombinedcores4nlg0 = $onlycombinedcores4nlg0 <br>\n";
    
    # print "nlgOutputPhrase0 = $nlgOutputPhrase0 <br>\n";
    # print "nlgOutputSentence0 = $nlgOutputSentence0 <br>\n";
    print "nlgFilterTemplate0 = $nlgFilterTemplate0 <br>\n";
    print "is_cgi = $is_cgi<br><br>\n\n";
    
    # print "debugStr4ngl = $debugStr4ngl <br>\n" ;
    
    
    
    # # if($collocation4nlg){
    # #     @searchlist = split /\s+/, $originalquery;
    # #     print "<strong>Query list:</strong><br>";
    # #     foreach $query (@searchlist){
    # #         print "$query";
    # #         print "<br>";
    # #     }
    
    # ## foreach $collocationspan (@collocspans4nlg){ print "CollocSpan: $collocationspan <br>\n" ;}
     
    # #}


} # end: if($is_cgi) {print...}
    
$searchstring=makecqpquery($originalquery);

if ($collocationstat) {
    $terminate=0;
    $contextsize=1;
    $contexttype='word';
    if ($collocspan) {
	$collocspan=min($maxcollocspan,$collocspan);
	$collocspanleft=$collocspan unless defined $collocspanleft;
	$collocspanright=$collocspan unless defined $collocspanright;
    };
    if (($collocfilter) and ($collocfilter=~/\S/)){
	eval {$searchstring=~/$collocfilter/};
	if ($@) {
	    cqperror( $messages{'filter-error'}," $@\n");
	}
    } else {
	undef $collocfilter;
    }
} elsif ($collocation4nlg){
    # duplicating collocationstat
    $terminate=0;
    $contextsize=1;
    $contexttype='word';



} else {
    if ($terminate) {$searchstring.=" cut $terminate"};
}


print STDLOG "corpuslist=$corpuslist; \n";
print STDLOG "Using $learningrestrictlist known words per example. " if $learningrestrictlist;
print STDLOG "remote_host=$remote_host\n" unless $remote_host=~/leeds.ac.uk/;
print STDLOG "$searchstring"; # it'll be followed by the number of occurrences, if we do not die

#print STDOUT "<p><strong>Query</strong>:$searchstring</p>";


if($kwText4nlg0) { # a separate module run before the main routine -- to find keywords / templates and submit them to further processing


    if ($is_cgi){ # printing to webpage;
        print "kwText4nlg0 = $kwText4nlg0 <br>\n";
        print "kwTextBrief4nlg0 = $kwTextBrief4nlg0 <br>\n";
        print "kwTextTfIdf4nlg0 = $kwTextTfIdf4nlg0 <br>\n";
    } # end: if ($is_cgi){  print... }
    
    
}


if ($originalquery=~/^\s*\[?\]?\s*$/) {
    print STDOUT $messages{'empty-condition'};
} elsif (($collocationstat) and ! (($mistat) or ($tstat) or ($llstat))) {
    print STDOUT $messages{'choose-score'};

} elsif ($nlgOutputSentence0) { # sentence-level collocations
    if ($is_cgi){
        # implement functionality for sentence generation here, out of components
        # print "list: @nlgFilterTemplate1 <br>\n";
        # print debug string:
        # print "\n\n<br><br>debug string: <br>\n $strDebugX <br>\n -- end debug string<br>\n\n";
        print "strDebugX = $strDebugX <br>\n\n ";
    };
    
    @nlgFilterTemplateLeft = ();
    @nlgFilterTemplateRight = ();
    $nlgFilterTemplateFocus = '';
    $BoolFocusFound = 0;
    
    # foreach $el (@nlgFilterTemplate1){ # replacing : now the string can hold inject and reject lists...
    $ICountPoS = 0;
    foreach $el (@nlgFilterTemplateX1){
        
        if ($el =~ /^\!(.+)/){
            $nlgFilterTemplateFocus = $1 ;
            # print "focus = $nlgFilterTemplateFocus <br>\n" ;
            # print "found? $BoolFocusFound;<br>\n";
            $BoolFocusFound = 1;
            next;
        }
    
        if($BoolFocusFound){ # elements to the right are added to the end of the array and processed in direct order.
            # print "found? $BoolFocusFound;<br>\n";
            push @nlgFilterTemplateRight, $el;
            # print "rightel: $el<br>\n";
        }else{ # elements to the left are added to the beginning of the array and processed in reverse order
            # print "found? $BoolFocusFound;<br>\n";
            unshift @nlgFilterTemplateLeft, $el;
            # print "leftel: $el<br>\n";
        };
    
    
    }
    # # print "left: @nlgFilterTemplateLeft <br>\n";
    # # print "right: @nlgFilterTemplateRight <br>\n";
    
    $j = 0;
    @LofLNLGColl = (); # list of ranked lists of collocates for each position
    my @LofH4NLGColl; # list of hashes of collocates for each position, with associated scores -- now to be used as the main data structure
    @LFocus = ();
    # initialising focus with the lexical keyword:
    push @LFocus, $nlgFilterTemplateFocus; # each element of this list becomes a searchstring == this will be re-initialised on each stage
    
    foreach $elPoS (@nlgFilterTemplateLeft){ # processing LEFT side of the focus; (RIGHT to be added later;)
        if ($is_cgi){ 
            # print "j= $j <br>\n";
            print "\n<br>$elPoS: ";
        };
        @LFocusNew0 = (); # new focus -- compiling from list of collocates
        if ($is_cgi){ 
            print "LFocus = @LFocus:<br>\n";
        };
        $fc = 0; # focus counter
        foreach $focus (@LFocus){
            # print "<br>\n";
            # print "fc= $fc<br>\n";
            # dynamic moving focus...

            $originalquery = $focus;
            # print "originalquery = $originalquery<br>\n";
            $searchstring=makecqpquery($originalquery);
            # print "searchstring = $searchstring<br>\n";
            
            

            # initialisation of variables (copy code -- move to proper position)
            # ########
            # previously global variables caused problems during repeated collocational search
            # we intialise it here...
            $numoccur = 0;
            $numwords = 0; # not initialised , was doubling corpus size...
            # initialising frequency table, pairs record, etc --> remaining tables in memory caused problems in the past... 
            %pairs = ();
            %freq = ();
            %nlemmas = ();
            $totalpairs = 0;
            $outcount=0;
            $onefrqc = 0; # caused different results for first and further collocations
            
            # initialising collocation tables: have been creating problem for second / third, etc. collocation context, never initialised in cqpquery.*.pm
            %loglikescore = ();
            %miscore = ();
            %dicescore = ();
            %tscore = ();
            # end initialising tables
            
            # initialising query parameters
            # !!!!!!!
            # do main search here:

            $collocspanleft= 1;
            $collocspanright = 0;
            $collocfilter = $elPoS;
            
            # ## print "&nbsp;Details: $collocspanleft ; $collocspanright ; $collocfilter <br>\n";
            @corpuslist=split ',', $corpuslist;
            # already intialised
            # %pairs = ();
            # $numoccur = 0;
           
            ## main run 
            # print " corpuslist = @corpuslist<br>\n";
            foreach $corpus (@corpuslist) {   
                $numoccur+=processcorpus($corpus, $searchstring);   
                # print "numoccur = $numoccur<br>\n";     
            }
            ## main run
            
            print STDLOG "Colloc: left=$collocspanleft, right=$collocspanright, collocfilter=$collocfilter\n";
            $numoccur=$totalpairs;
            # foreach $el (keys %paris){ print "Pair: $el <br>\n"}
            @collocationstr4nlg = showcollocates();
            # print "collocationstr4nlg = @collocationstr4nlg <br>\n";
            my @collocationstr4nlgLocal = @collocationstr4nlg;
            my ($ref_collKWordMatch, $ref_coll4nlgList, $ref_coll4KWordSc) = prepareCollocList4NLG(@collocationstr4nlgLocal); # splitting pairs kw + colloc, only colloc in second list - to be used
            # print "references = $ref_collKWordMatch, $ref_coll4nlgList, $ref_coll4KWordSc <br>\n";
            my %collKWordMatch = %{$ref_collKWordMatch};
            my %coll4KWordSc = %{$ref_coll4KWordSc}; # collocations (keys) and collocation scores (values);
            my @coll4nlgList = @{$ref_coll4nlgList}; # list of collocates for NLG
            # my @coll4nlgList2clean = cleanupCollList4NLG(@coll4nlgList);
            my @coll4nlgList2clean = cleanupCollList4NLG( sort {$coll4KWordSc{$b} <=> $coll4KWordSc{$a}} keys %coll4KWordSc );
            # print "coll4nlgList = @coll4nlgList <br>\n";
            if ($is_cgi){ print "coll4nlgList2clean = @coll4nlgList2clean <br>\n";};
            ## debugging
            my @keysColl4KWordSc = keys(%coll4KWordSc);
            ## print "keys coll4KWordSc = @keysColl4KWordSc <br>\n" ;
            
            unshift @LofLNLGColl, \@coll4nlgList2clean; # udating main data structure: adding to the beginning of the list, reversed!
            # unshift @LofLNLGColl, \@coll4nlgList; # udating main data structure: adding to the beginning of the list, reversed!
            unshift @LofH4NLGColl, \%coll4KWordSc; # udating main data structure (!now Hash!): adding to the beginning of the list, reversed!
            
            
            
            if ($fc < 1){ # limit on the length ??? [look it up!!!]
                # push @LFocusNew0, $coll4nlgList2clean[0]; # at the moment only one el in focus used, to be updated later
                push @LFocusNew0, $coll4nlgList[0]; # at the moment only one el in focus used, to be updated later
                # change this first [???]
                @LFocusNew = prepareFocus4NLG(@LFocusNew0);
            }
            
            
            # !!!!!!!
            # end of main search
            
            
            
            
            $fc++; # for indexing arrays
        }
        @LFocus = @LFocusNew;
        # print "LFocus = @LFocus<br>\n";
        

        $j++; # for indexing arrays
    }
    # print "nlgFilterTemplateFocus = $nlgFilterTemplateFocus<br>\n";
    my @nlgFilterTemplateFocusL3 = ();
    my %nlg4FilterTemplateFocusL3;
    if ($is_cgi){ print "nlgFilterTemplateFocus = $nlgFilterTemplateFocus <br>\n";};
    %nlg4FilterTemplateFocusL3 = ( $nlgFilterTemplateFocus => 1, );
    
    push @nlgFilterTemplateFocusL3, $nlgFilterTemplateFocus;
    push @LofLNLGColl, \@nlgFilterTemplateFocusL3; # the last one -- is pushed to the end of the list
    push @LofH4NLGColl, \%nlg4FilterTemplateFocusL3; # the last one -- is pushed to the end of the list (!now Hash!)
    
    
    
    # random selections:
    
    if ($nlgOutputSentenceFile0){
        if ($is_cgi){ 
            print "Random selection of collocates will be written to file <strong>$nlgOutputSentenceFile0</strong><br><br>\n\n";
        }

        recombineColloc4NLG2File(@LofLNLGColl);
    }

    if ($is_cgi){ 
        print "Random selection of collocates<br><br>\n\n";
    }
    # recombineColloc4NLG(@LofLNLGColl); # print random comibnations on screen - swapped;
    recombineCollocHash4NLG(@LofH4NLGColl); # print comibnations based on scores on screen
    ### recombineColloc4NLG(@LofLNLGColl); # print random comibnations on screen
    

    
    # then here add processing for the right context -- also recursively.
    

} elsif($collocation4nlg) {
    
    @AofPairs = ();
    @LoLColloc = ();
    %hKWords = ();
    foreach $collocationspec (@collocspans4nlg){
        # initialisation of variables
        # ########
        # previously global variables caused problems during repeated collocational search
        # we intialise it here...
        $numoccur = 0;
        $numwords = 0; # not initialised , was doubling corpus size...
        # initialising frequency table, pairs record, etc --> remaining tables in memory caused problems in the past... 
        %pairs = ();
        %freq = ();
        %nlemmas = ();
        $totalpairs = 0;
        $outcount=0;
        $onefrqc = 0; # caused different results for first and further collocations
        
        # initialising collocation tables: have been creating problem for second / third, etc. collocation context, never initialised in cqpquery.*.pm
        %loglikescore = ();
        %miscore = ();
        %dicescore = ();
        %tscore = ();
        # end initialising tables
        
        
        # ## print "--------------cqp4nlg.pl-------------- <br>\n" ;
        if ($printproofcolloc4nlg0){ 
            if ($is_cgi){ print "CollocSpec: $collocationspec <br>\n"; };
            
        };
        
        # continue the loop if collocation context is not specified
        if ($collocationspec =~ /(0)~~(0)/){
            next;
        };
        
        if ($collocationspec =~ /(.+)~(.*)~(.+)/){
            $collocspanleft= $1;
            $collocspanright = $3;
            $collocfilter = $2;
            # ## print "&nbsp;Details: $collocspanleft ; $collocspanright ; $collocfilter <br>\n";
            @corpuslist=split ',', $corpuslist;
            # already intialised
            # %pairs = ();
            # $numoccur = 0;
            foreach $corpus (@corpuslist) {   
                $numoccur+=processcorpus($corpus, $searchstring);
                                    
            }
        

        print STDLOG "Colloc: left=$collocspanleft, right=$collocspanright, collocfilter=$collocfilter\n";
        $numoccur=$totalpairs;
        # foreach $el (keys %paris){ print "Pair: $el <br>\n"}
        @collocationstr4nlg = showcollocates();
        # ## print "<br> ---cqp4nlg: collocationstr4nlg --- : <br> \n";
        # ## print @collocationstr4nlg ;
        # ## print "\n<br>-------end: collocationstr4nlg ---<br>\n";

        
        # print "Debug: <br>\n";
        # print "hPairs: ";
        # print  keys %pairs ;
        # print "<br><br>\n\n";
        
        # %LSavedPairs = %pairs;
        my @collocationstr4nlgLocal = @collocationstr4nlg;
        my ($ref_collKWordMatch, $ref_coll4nlgList, $ref_coll4KWordSc) = prepareCollocList4NLG(@collocationstr4nlgLocal);
        # ## print "ref_collKWordMatch: $ref_collKWordMatch <br>\n"; 
        # ## print "ref_coll4nlgList: $ref_coll4nlgList <br>\n";
        
        my %collKWordMatch = %{$ref_collKWordMatch};
        my %coll4KWordSc = %{$ref_coll4KWordSc}; # hash of collocations (keys) and coll scores (values)
        my @coll4nlgList = @{$ref_coll4nlgList};
        # ## print "<br>\n";
        # ## print "kw:<br>\n";
        # ## print %collKWordMatch;
        # ## print "<br>\n";
        # ## print "colloc:<br>\n";
        # ## print @coll4nlgList;
        # ## print "<br>\n";
        # ## print "<br>\n";
        
        # push @LKWords, @collKWordMatchList;
        keys %collKWordMatch;
        while (my ($key, $value) = each %collKWordMatch){
            $hKWords{$key} += $value;
            
        }
        
        
        # push @AofPairs, \%hSavedPairs;
        # switch to processed list rather than copied list -- substituted
        # push @LoLColloc, \@collocationstr4nlgLocal;
        push @LoLColloc, \@coll4nlgList;
        
        # print "Corp; Search; Occurrences: $corpus $searchstring $numoccur <br>\n";
            
        }
        
    }

    # recombinePairs(@AofPairs);
    # create list of match lemmas from prev
    
    # ## print %hKWords;
    @lKWords = keys %hKWords;
    
    if ($keywordposition4nlg0 eq "last"){
        push (@LoLColloc, \@lKWords);
        
    }elsif($keywordposition4nlg0 eq "first"){
        unshift(@LoLColloc, \@lKWords);
    }elsif((($keywordposition4nlg0 + 0) <= scalar(@LoLColloc)) && (($keywordposition4nlg0 + 0) > -1)){
        $keywordposition4nlg0 += 0;
        splice(@LoLColloc, $keywordposition4nlg0, 0, \@lKWords);   
    }
    
    # introduce ranking here if needed: both conditions needed -- scores + request to use them for ranking
    # create a new list from a hash?
    if($printproofscores4nlg0 && $rankproofcolloc4nlg0){
        if ($is_cgi){ print "Ranked selection of collocates<br><br>\n\n";};
        # recombine collocations wiht scores
        # for each line -- calculate a combined score, record it as a value of a hash
        # sort by values and print / save
        @LoLCollocCartesianProduct = permute(@LoLColloc);
        @lCollocScores = recombineColloc4NLGcartesianproductHashScores(@LoLCollocCartesianProduct); # calculate collocation scores
        # printing the top of the list on screen
        my $k = 0;
        for $line_sc (@lCollocScores){
            $k++;
            if ($k > $noofsentences4nlg0){last;}
            if ($is_cgi){print "$k. $line_sc <br>\n";};
            
            
        }
        if($printcartesianpr4nlg0){ # if there is a file name
            
            recombineColloc4NLGcartesianproductPrintList(@lCollocScores); # print ranked list to file
        }
        
    }elsif($printcartesianpr4nlg0){
        if ($is_cgi){ print "Random selection of collocates, file output link below <br><br>\n\n";};
        recombineColloc4NLG(@LoLColloc); # print random comibnations 
        @LoLCollocCartesianProduct = permute(@LoLColloc);
        recombineColloc4NLGcartesianproduct(@LoLCollocCartesianProduct); # print to file;
        
            
    }else{
        if ($is_cgi){ print "Random selection of collocates<br><br>\n\n"; };
        recombineColloc4NLG(@LoLColloc); # print random comibnations on screen
    }
    
    

    
} else { 
    $cqpprocesstime=0;
    if ($corpuslist eq 'RU') {
	$numoccur+=processcorpus('RNC2009-MOCKY',$searchstring);
	$numoccur+=processcorpus('INTERNET-RU',$searchstring);
	$numoccur+=processcorpus('NEWS-RU',$searchstring);
    } elsif ($corpuslist eq 'EN') {
	$numoccur+=processcorpus('BNC',$searchstring);
	$numoccur+=processcorpus('NEWS-GB', $searchstring);
	$numoccur+=processcorpus('INTERNET-EN', $searchstring);
    } elsif ($corpuslist eq 'DE-WAC') {
	foreach $part (1 .. 10) {
	    $corpus = sprintf "DEWAC%02d", $part;
	    $numoccur+=processcorpus($corpus, $searchstring);
	}
    } else {
	@corpuslist=split ',', $corpuslist;
	foreach $corpus (@corpuslist) {
	    $numoccur+=processcorpus($corpus, $searchstring);
	}
    };

    if ($errormessage) {
#the error message has been printed anyway
    } else {
	if ($collocationstat) {
	    print STDLOG "Colloc: left=$collocspanleft, right=$collocspanright, collocfilter=$collocfilter\n";
	    $numoccur=$totalpairs;
	    showcollocates();
	} elsif ($numoccur) {
	    showconcordance(\@storecontexts,0);
	}
	elsif ($learningrestrictlist) {  
	    printf $messages{'noknownwords'},$learningrestrictstr;
	} else {
	    printf $messages{'notfound'}, $searchstring, $corpuslist, $curlang;
	};
	print STDLOG " occurred $numoccur time(s). ";
	$processtime=time()-$starttime;
	print STDLOG "Total process time: $processtime sec; CQP process time: $cqpprocesstime sec.\n";
    }
};

if ($is_cgi){ print STDOUT "</html>\n";};
close(STDLOG);

sub utest {
$x=(utf8::is_utf8($_[0])) ? utf8 : noutf8;
print STDERR length($_[0]),": $x, $_[0]\n";
}
