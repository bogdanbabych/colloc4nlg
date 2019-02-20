# for documentation, type:
# perldoc cqpquery.pm
# Serge Sharoff, with some advice from Marco Baroni and Stefan Evert

use Carp;
use CWB::CQP;
use CWB::CL;

use smallutils;

@ISA=qw(Exporter);

@EXPORT = qw/&cqperror &computecollocates &getattrpos &getlearningrestrictlist &getlemma  &getlemmas  &getword  &getwords  &loglike &makecqpquery &printdebug  &processcorpus  &readconffile  &readmessagefile  &showcollocates  &showconcordance %messages @storecontexts/;

sub sortlines { #we're sorting frequencies in ascending order 
   return(($sort1option eq "fq") ? $sortlines{$_[1]} cmp $sortlines{$_[0]} : $sortlines{$_[0]} cmp $sortlines{$_[1]})
}

sub learningrestrictlist { #function for rejecting lines containing few known words
    my $curpos=shift;
    undef my %querylemmas;
    foreach $i ($curpos-$contextsizewords..$curpos+$contextsizewords) {
	$querylemmas{getlemma($i)}=1 ;
    };
    my $intersect=0;
    if ($learninggeneraliselist) {
	my $alllemmas=join ' ',sort keys %querylemmas;
	return 1 unless $alllemmas=~/ (?:$learninggeneraliselist) /;
    };
    foreach (keys %querylemmas) {
	if ((exists $restrictwords{$_}) or (/[.,:;()\d]+/)) {
	    $intersect++;
	}
    };
    return ($intersect<$learningrestrictlist) ?
	1 : 0

}

sub prefixline {
    my ($cpos,$titleid)=@_;
    unless (($titleid) and (length($titleid)<5)) {
	$titleid='&gt;&gt;';
    };
    return qq{<td><input type="checkbox" name="cpos" value="$cpos"></td><td><a href="$cgipath/showcontext-cqp.pl?cpos=$cpos" target="_blank">$titleid</td>}
}

sub printtransscores {
    my $scoreref=shift;
    my $i=0;
    my %shown;
    foreach (sort { ${$scoreref}{$b} <=> ${$scoreref}{$a} } keys %{$scoreref}) {
	my ($m,$trans)=split /\t/,$_;
	unless (exists $shown{$trans}) { #this cares for the same translation of different word forms
	    my $score=${$scoreref}{$_};
	    printf STDOUT qq{<a href="$cqpsearchprefix$trans\&c=$parallel">%s (%3.2f)</a>, }, $trans, $score;
	    $shown{$trans}=$score;
	};
	last if $i++>10;
    };
    return \%shown;
}

#two modes for displaying coprus content: a table with concordance lines or broader longer wrapped context 
#lines can be also filtered out using a custom function, an OO interface with overloading might be a better solution
sub showconcordance {
    my ($cposref,$broadview,$restictfn)=@_;
    my @cpos=@{$cposref};
# first, collect information for sorting lines
    foreach (@{$cposref}) {
	if (($corpusname,$cpos,$matchend)=/^(.+)\.(\d+)\.(\d+)$/) {
	    $querylength=$matchend-$cpos+1;
	    if ($corpusname ne $oldcorpusname) {
		$clcorpus = makecorpusattrs($corpusname);
		$oldcorpusname=$corpusname;
	    };
	    if ((ref $restictfn) and &{$restictfn}($_)) {
		next;
	    };
	    my $prim='';
	    if ($sort1option eq "fq") {
		$prim=sprintf "%04d", (($sort2option eq "left") ? $neighbourfq{getword($cpos-1)} : 
		    $neighbourfq{getword($matchend+1)});
	    } else {
		$prim=($sort1option eq "word") ? getword($cpos) :
		    ($sort1option eq "lemma") ? getlemma($cpos) :
		    ($sort1option eq "pos") ? getpos($cpos)  :
		    ($sort1option eq "document") ? $_ : '';
	    };
	    # my $second=($sort2option eq "left") ? getword($cpos,-1) : ## next line modified from this line by Bogdan Babych,24/05/2007 
	    my $second=($sort2option eq "left") ? getword($cpos-1) :
		($sort2option eq "right") ? getwords($cpos,$querylength,$querylength+5) :
		# ($sort2option eq "leftlemma") ? getlemma($cpos,-1) : ## next line modified from this line by Bogdan Babych,24/05/2007
		($sort2option eq "leftlemma") ? getlemma($cpos-1) :
		($sort2option eq "rightlemma") ? getlemmas($cpos,$querylength,$querylength+5) : '';
	    $sortlines{$_}="$prim$second";
	};
    };

    undef my %alignedcorpuswordattr;
    undef my %alignedcorpuslemmaattr;
    undef my %pairs;
    if ($parallel) { #this is the case when an OO interface should be useful for storing attributes of parallel corpora
	foreach $alignedcorpus (split ',', $parallel) {
	    if ($clparacorpus = new CWB::CL::Corpus $alignedcorpus) {
		$alignedcorpuswordattr{$alignedcorpus}=$clparacorpus->attribute('word', 'p');
		$alignedcorpuslemmaattr{$alignedcorpus}=$clparacorpus->attribute('lemma', 'p') || $alignedcorpuswordattr{$alignedcorpus};
	    };
	};
    };

  #output starts, needs formatting!!!! EMILIANO
    print STDOUT qq{$searchstring<br/>} if length($searchstring)>100; # doesn't fit in the title
    print $messages{'back'};

    print STDOUT qq{<form name="showcontext" action="$cgipath/showcontext-cqp.pl" method="post">\n};
    print STDOUT qq{<table>\n};
    print STDOUT qq{<tbody>\n};
    $outcount=0;
    if (($parallel) and (!$showhorizontal)) {
	my $width=int(90/((scalar keys %alignedcorpuswordattr)+1));
	print "<th></th><th>id</th><th width=$width\%>Source</th>\n";
	foreach $alignedcorpus (sort keys %alignedcorpuswordattr) {
	    print "<th></th><th>id</th><th width=$width\%>$alignedcorpus</th>";
	}
    };


    foreach (sort {sortlines($a,$b)} keys %sortlines) {

	if (($corpusname,$cpos,$matchend)=/^(.+)\.(\d+)\.(\d+)$/) {
	    if ($corpusname ne $oldcorpusname) {
		$clcorpus = makecorpusattrs($corpusname);
		$oldcorpusname=$corpusname;
	    };
	    $match=getannotatedwords($cpos,0,$matchend-$cpos);

	    $left=getannotatedwords($cpos,-1,-$contextsizewords,$charsize);
	    $right=getannotatedwords($matchend,1,$contextsizewords,$charsize);
	    if ($curlang eq 'ar') {
		($left,$right)=($right,$left);
	    };
	    if ($broadview) {
		$titleid=gettitle($titleattr,$titleidattr,$cpos); 
		print STDOUT qq{<p class="contextpar"> <strong>$titleid</strong><br>$left $match $right</p>\n};
	    } else {
		$concline=qq{<td align="right" nowrap>$left</td>
    <td align="center" nowrap><strong>$match</strong></td>
    <td align="left" nowrap>$right</td>};
		next if $concline eq $prevconcline;
		$prevconcline = $concline;
		$outcount++;
		$titleid=gettitle($titleattr,$titleidattr,$cpos,1); #id only

		if ($parallel) {
		    $fulltransline='';
		    foreach $alignedcorpus (sort keys %alignedcorpuswordattr) {
			$transstring='';
			my $alignattr = $clcorpus->attribute(lc($alignedcorpus), 'a');	
			if (($alignattr) and ($alg = $alignattr->cpos2alg($cpos))) {
			    ($src_start, $src_end, $target_start, $target_end) 
				= $alignattr->alg2cpos($alg) ;

			    foreach $parapos ($target_start..$target_end) { # collect lemmas in translation
				my $paraword=cleantags(getattrpos($parapos,$alignedcorpuswordattr{$alignedcorpus}));
				$transstring.=" " unless $paraword=~/^$punctuationmarks$/;
				$transstring.=$paraword;
				my $paralemma=$alignedcorpuslemmaattr{$alignedcorpus}->cpos2str($parapos);
				utf8::decode($paralemma);
				++$pairs{"$match\t$paralemma"} unless ($paralemma=~/^$punctuationmarks$/) or 
								    ($paralemma eq 'the');
				unless ($freq{$paralemma}) {
				    if (my $id=$alignedcorpuslemmaattr{$alignedcorpus}->str2id($paralemma)) {
					$freq{$paralemma}=$alignedcorpuslemmaattr{$alignedcorpus}->id2freq($id);
				    }
				};
			    }
			};

#			$transsize+=$target_end-$target_start;
#			utf8::decode($transstring);

			if ($corpuslang{$alignedcorpus} eq 'ru') {
			    if ($transliterateout) {
				$transstring=cyr2lat($transstring);
			    }
			};
			$newtransline= prefixline("$alignedcorpus.$target_start.$target_start",$alignedcorpus)."<td>$transstring</td>";
			if ($showhorizontal) { #it will be a separate row
			    $newtransline="<tr>$newtransline</tr>"
			};
			$fulltransline.=$newtransline;
		    }
		    if ($showhorizontal) {
			print STDOUT "<tr>",prefixline($_,$titleid),$concline,"</tr>\n",$fulltransline;
		    } else { #several translations in one row
			print STDOUT "<tr>",prefixline($_,$titleid),"<td>$left <strong>$match</strong> $right</td>", $fulltransline,"</tr>\n";
		    };
		} else { #each concordance line is separate
		    $outputline=prefixline($_,$titleid).$concline;
		    print STDOUT "<tr>$outputline</tr>\n";
		}
	    };
	};
    };
    unless ($broadview) {
	if ($latin1query) {
	    $searchstring=Encode::decode('utf8',$searchstring);
	};
	if (($corpussize) and ($numoccur < $terminate)) {
	    printf STDOUT $messages{'exactfq'}, $outcount, $numoccur*1000000/$corpussize, $searchstring, $corpuslist;
	} else {
	    printf STDOUT $messages{'someexamples'}, $outcount, $searchstring, $corpuslist;
	    
	};

	if ($learninggeneraliselist) {
	    print STDOUT "The list of known words also used: <strong>($learninggeneraliselist)</strong><br>\n";
	};
    };

    print STDOUT qq{</tbody></table>\n};

    unless ($broadview) {
	print STDOUT qq{<INPUT type="hidden" name="querytitle" value="$searchstring">\n};
	print STDOUT qq{<INPUT type="hidden" name="debuglevel" value="$debuglevel">\n} if $debuglevel;
	print STDOUT qq{<div class="submitbox">\n<h3><input type="radio" name="selectall" onclick="selectAll(this.form,0);">};
	print STDOUT $messages{'selectall'};
	print STDOUT qq{&nbsp;&nbsp;&nbsp;\n<input type="radio" name="selectall" onclick="selectAll(this.form,1);">};
	print STDOUT $messages{'invertall'},"</h3>\n";
	print STDOUT qq{<h3>$messages{'showlines'} &nbsp;&nbsp;<input type="text" name="contextsize" value="$contextsize" size="2"> $messages{'words'}</h3>\n};
	print STDOUT qq{<p><input type="submit">&nbsp;&nbsp;<input type="reset"></p>\n};
    }

    print STDOUT qq{</div>\n};
    print STDOUT qq{</form>\n};

    if ($parallel) {
	$mistat=1;$llstat=1;    
	$totalpairs=scalar(keys %pairs);
	computecollocates($outcount,$corpussize,\%freq,\%pairs);
	print STDOUT "\n<p>$messages{'computedtranslations'} (MI-score): ";
	my $miscorer=printtransscores(\%miscore);
	print STDOUT "</p>\n<p>$messages{'computedtranslations'} (Loglike): ";
	my $llscorer=printtransscores(\%loglikescore);
	print STDOUT "</p>\n<p>$messages{'computedtranslations'}: <strong>", join(', ',sort keys %{&intersect($llscorer,$miscorer)}), "</strong>\n</p>";
	    
    };

    print $messages{'back'};

    print STDOUT q{</body><script>/* Copied from Vincent Puglia, GrassBlade Software */ 
      function selectAll(formObj, isInverse) {
        for (var i=0;i < formObj.length;i++)  {
          fldObj = formObj.elements[i];
          if (fldObj.type == 'checkbox') {
            if (isInverse)
            fldObj.checked = (fldObj.checked) ? false : true;
            else fldObj.checked = true; 
          }
        }
      }
    </script>};
}


sub gettitle {
    my ($titleattr,$titleidattr,$cpos,$idonly)=@_;
    if ($titleidattr) {
	$titleid=$titleidattr->struc2str($titlestruc) if $titlestruc=$titleidattr->cpos2struc($cpos);
	$titlestr=$titleid; # we can't return more 
    } elsif ($titleattr) {
#	$titlestr=$titleattr->struc2str($titlestruc) if $titlestruc=$titleattr->cpos2struc($cpos);
      $titlestruc=$titleattr->cpos2struc($cpos);
      $titlestr=$titleattr->struc2str($titlestruc) if ($titlestruc >= 0) ;

	if (($idonly) and (($titleid)=$titlestr=~/id="(.+?)"/)) { #no need to return more
	    $titlestr=$titleid;
	}
    } else {
	return '';
    };

    $flag = utf8::decode($titlestr);

    if ($titlestr=~m%\"http://%) {
	$titlestr=~s%"(http://.+?)"%<a href="$1">$1</a>%;
    };
    return $titlestr;
};

sub cqperror {
    my $outstring=join "<br>", @_;
    if ($outstring=~/query lock violation attempted/) {
	print $messages{'openingbracket'};
    } else {
	    print "<h3>$outstring</h3>";
	};
    print "<strong>searchstring: </strong> $searchstring<p>";
    print STDLOG "Error in the searchstring: '$searchstring'"; 
    $errormessage=1; ## to stop displaying results
    return 0;
}

sub makecorpusattrs {
    my $sourcecorpus=shift;
    my $clcorpus;
    if ($clcorpus = new CWB::CL::Corpus $sourcecorpus) { # open the CL interface
	$wordattr = $clcorpus->attribute("word", 'p');
	print STDLOG "No attribute 'word' in $sourcecorpus\n" unless $wordattr;
	$corpussize=$wordattr->max_cpos;
	unless ($lemmaattr = $clcorpus->attribute("lemma", 'p')) {
	    $lemmaattr = $wordattr;
	};
	$posattr = $clcorpus->attribute("pos", 'p') || $wordattr; 
	$titleattr = $clcorpus->attribute("text",'s');
	$titleidattr = $clcorpus->attribute("text_id",'s');
    } else {
	cqperror("Can't access corpus $corpusname") unless (defined $clcorpus);
    }
    return $clcorpus;
};



sub processcorpus {
    my ($sourcecorpus,$searchstring)=@_;
    $cqpstart=time();
    my $clcorpus=makecorpusattrs($sourcecorpus);
    if ($wordattr == $lemmaattr) {
	$searchstring=~s/\[lemma=/\[word=/g; #we couldn't do this during query generation, as some corpora in the query list might have a lemma, while others not.
    };
    $cqpquery = new CWB::CQP;
    $cqpquery->set_error_handler(\&cqperror);
    $cqpquery->exec($sourcecorpus);
#    utf8::encode($searchstring) unless ($curlang eq 'ru'); # it's strange that this works (and doesn't work otherwise)
#    $cqpquery->exec("set autoshow on");
    $cqpquery->exec("set context 0 word");
    undef $parallel if $collocationstat;
    $queryid="$cachedir/$sourcecorpus:".&queryhash("$searchstring");
    if (($cachedir) and open(MATCHES,$queryid)) {
#information about a cached query is kept in the following file:
	@matches=<MATCHES>;
	close(MATCHES);
	foreach (@matches) {
	    @ref=split /\t/,$_;
	    $_ = [@ref];
	};
	system 'touch', $queryid;
    } else {

	$cqpquery->exec_query($searchstring);
	if ($cqpquery->ok) {
	    @matches = $cqpquery->dump("Last");
	    if ((time()-$cqpstart > 1) and ($cachedir)) {
		#if query processing takes sufficiently long and we have somewhere to write 
		$cqpquery->exec(qq{dump Last >"$queryid"});
		($dirsize)=split(' ',`du -k $cachedir/`);   # following Stefan's procedure
		if (($dirsize) and ($dirsize>$maxcachedirsize)) {
		    @cachelist=<$cachedir/*>;
		    @cachelist = sort { -M $a <=> -M $b } <$cachedir/*>;
		    my $cumdelete_size = 0;
		    while (@cachelist and $cumdelete_size < $dirsize-$okcachedirsize) {
			my $fname = pop @cachelist;
			$cumdelete_size += (-s $fname) / 1024;
			unlink($fname);
		    }
		}
	    }
	};
    };
    $cqpprocesstime+=time()-$cqpstart;
    if (substr($searchstring,0,2) eq 'MU') {
	$querylength=scalar(split(' \[',$searchstring))-1;
    };
    if ($collocationstat || $collocation4nlg) {
	$onefrqc += scalar(@matches);
	if($printproofcolloc4nlg0){ print "onefrqc = $onefrqc<br>\n"; };
	
	undef %nlemmas;
    };
    if ($cqpquery->ok) {
    foreach $m (@matches) {
	($curpos, $matchend, $target, $keyword) = @{$m};
	if ($querylength) { # cqp doesn't return correct lenght for MU queries
	    $matchend+=$querylength-1;
	}
	$cl=$matchend-$curpos+1;
	if ($collocationstat || $collocation4nlg) {
	    $matchlemma=getlemmas($curpos,0,$cl-1);
	    undef @nlemma;
	    if ($collocspanleft) {
		for $i (-$collocspanleft..-1) {
		    push @nlemma, getlemma($curpos+$i) if (!$collocfilter) or (poscheck($collocfilter,$curpos+$i));
		}
	    };
	    if ($collocspanright) {
		for $i ($cl..$cl+$collocspanright-1) {       # starting after the end of the search condition
		    push @nlemma, getlemma($curpos+$i) if (!$collocfilter) or (poscheck($collocfilter,$curpos+$i));
		}
	    };
	    foreach $nlemma (@nlemma) {
		++$pairs{"$matchlemma\t$nlemma"};
		++$totalpairs;
	    }
	    @nlemmas{@nlemma}=();
	} else {
	    #for this sorting we have to precollect co-occurrence frequency data
	    if ($sort1option eq "fq") {
		my $neighbour=($sort2option eq "left") ? getword($curpos-1) : getword($matchend+1);
		$neighbourfq{$neighbour}++;
	    };
	    push @storecontexts, "$sourcecorpus.$curpos.$matchend";
	}
    };
    } else {
	cqperror("Error in processing your query $searchstring in $sourcecorpus")
    };

    undef $cqpquery; # close the CQP interface

    $cqpcollocprocesstime=time();
    if ($corpussize) {
	$numwords +=$corpussize;
    };
    foreach $nlemma (keys %nlemmas) { #to collect freq statistics from several corpora
	if ($id  = $lemmaattr->str2id($nlemma)) {
	    $freq{$nlemma}+= $lemmaattr->id2freq($id);
	};
    };
    undef $clcorpus;
    return (scalar(@matches));
}

sub getattrpos {
    my ($cpos,$attr) = @_;
    my $m = $attr->cpos2str($cpos);
    $flag = utf8::decode($m);
#    $m=~s/\&(?:quot|bquo|equo);/\"/g;
    return($m);
}

sub getlemma {
    my $m=getattrpos($_[0],$lemmaattr);
    if ($m eq '__UNDEF__') {
	$m=getattrpos($_[0],$wordattr);
    }
    return($m);
}
sub getword {
    my $res=getattrpos($_[0],$wordattr);
    return($res);
}

sub getlemmas {
    my ($cpos,$start,$end)=@_;
    $out='';
    for $i ($cpos+$start..$cpos+$end) {
	my $m=getattrpos($i,$lemmaattr);
	$out.="$m " unless  $m=~/<\/?(\w+)>/; # we don't process HTML tags
    }
    return substr($out,0,length($out)-1);  # minus the added space
}

sub cleantags {
    my $m=shift;
    $m=~s/<\/?(\w+)>/&lt;$1&gt;/g; # HTML tags in the corpus are converted
    $m=~s/ &lt;g\/&gt; //g; #if we have <g/> tags (glue, as used by Adam)
    $m=~s/\&amp;/\&/g;
    $m=~s/\&(?:quot|bquo|equo);/\"/g;
    return $m;
}

#words to output with attributes, but we limit the output by line length in characters
sub getannotatedwords {
    my ($cpos,$start,$end,$charsize)=@_;
    my $out='';
    my $outlength=0;
    my $wordsize=abs($end-$start);
    for my $offset (0..$wordsize) { #the problem here is the need to grow left contexts from the right
	my $i=$cpos+signint($end)*$offset+$start;
	my $m.=cleantags(getattrpos($i,$wordattr));
	$m=' '.$m unless $m=~/^$punctuationmarks$/;
	$outlength+=length($m);
	last if ($charsize) and ($outlength>$charsize);
	my $lemma=getattrpos($i,$lemmaattr);
	my $pos=getattrpos($i,$posattr);
	$m=qq{<span title="$lemma/$pos">$m</span>};
	if ($end<0) {
	    $out=$m.$out;
	} else {
	    $out.=$m;
	}
# 	if ($similaritysearch) {
# 	    my $lemmastr=getattrpos($i,$lemmaattr);
# 	    my ($pre,$post)=('','');
# 	    if ($SEMCLASS{$lemmastr}) {
# 		$pre= "<span title='$SEMCLASS{$lemmastr}'>";
# 		$post="</span>";
# 	    };
# 	    print "$pre$wordstr$post";
# 	    $m="<INPUT type=checkbox name=cpos value=$sourcecorpus.$i>$pre$m$post";
# 	}
    };
    return $out;
}

sub getwords {
    my ($cpos,$start,$end)=@_;
    my $out='';
    for $i ($cpos+$start..$cpos+$end) {
	$out.= cleantags(getattrpos($i,$wordattr))." ";
    }
    return substr($out,0,length($out)-1);  # minus the added space
}

sub poscheck {
    my ($collocfilter,$cpos)=@_;
    my $posval=$posattr->cpos2str($cpos);
    return(($posval=~/^$collocfilter$/) ? 1 : 0);
}

#for creating a proper cqp query for each input token
sub processword {
    my ($word)=@_;

    return $word if $word=~/[=\[\]]/; # for very clever guys
    my $attrname=$defaultattrname;
    undef my $pos,$out;
    if ($word eq '.') { # exactly one word in between; 
	return q{[]};
    } elsif ($word eq '?') { # an optional word in between
	return q{[]?};
    } elsif (($distfrom,$distto)=$word=~/^\.\.(\d*)-?(\d*)$/) { # a range of optional words in between: ..3 shortcut to {0,3}
	$distfrom=0 unless $distfrom;
	$distto=2 unless $distto;
	return "[]{$distfrom,$distto}";
    } elsif (($newword,$pos)=$word=~/(.*?)\/(\S+)$/) { # this is the /N shortcut to &pos=N
	$word=$newword;
	$pos=~s/,/\|/g;
    };
    my $wl=length($word);
    if (($wl>1) and (substr($word,$wl-1,1) eq '%')) {  #queries ending with %
	$attrname='lemma';
	$word=substr($word,0,$wl-1);
#	$word=lc($word) unless $curlang eq 'de'; # lemmas are all in the lower case, except for German
    };
    $out=qq{$attrname="$word"};
    if ($pos) {
	if ($wl) {  # full expression with &
	    $out.='&'.qq{$posattrname="$pos"}
	} else { # only POS mentioned
	    $out=qq{$posattrname="$pos"};
	}
    }
    return "[$out]";
}

sub processmuqueryword{
    if ($_[0]=~/^\+(\d+|s)(\S+)/) { #either +\d or +s
	return ($1,processword($2));
    } else {
	return ($_[1],processword($_[0]));
    }
}

sub loglike {
 my ($k,$n,$x)=@_;
 my $res=1000;
 if (($x>0) and ((1-$x)>0)) {
     $res = $k*log($x) + ($n-$k)*log(1-$x);
 } else { $res=0;
# the case of complete dependence: one does not occur without the other, but log(0)
 }
 return($res);
}
sub printdebug {
    if ($debuglevel) {
	print DEBUGLOG "@_\n";
    }
}

sub queryhash { #the simplest thing is to replace all unsafe chars and have a readable query name
    $_[0]=~s/([|*?&"'])/sprintf("%%%02X", ord($1))/eg;
    return $_[0];
}

sub computecollocates {
    my ($onefrqc,$numwords,$freqref,$pairsref)=@_;
    my %pairs=%{$pairsref};
    my %freq=%{$freqref};
    foreach $key (keys %pairs) {
	next if ($pairs{$key}<$idiosyncthreshold) and ($totalpairs>200);  #reject idiosyncratic word combinations, if we have enough pairs
	unless (($matchlemma,$nlemma)=$key=~/^(.+)\t(.+)$/) {
#	    utf8::decode($key);
	    cqperror("Internal error in splitting the collocation pair $key");
	    next;
	};
	$onetwofrqc=$pairs{$key};
	$freq{$matchlemma}=$onefrqc unless exists $freq{$matchlemma};
	$twofrqc=$freq{$nlemma};
print STDERR "$key, $onefrqc $twofrqc\n" unless $onefrqc and $twofrqc;
	$oedifference=$onetwofrqc  - ($onefrqc * $twofrqc/$numwords);
	if ($onefrqc and $twofrqc and ($oedifference>0)) { #otherwise there's no need to bother with calculations
	    $miscore{$key} = log ($numwords * $onetwofrqc  / 
				  ($onefrqc * $twofrqc))/log(2) if $mistat; 
	    $tscore{$key} = ($oedifference) / sqrt ($onetwofrqc) 
		if $tstat; 
	    
	    $dicescore{$key} = (100 * 2 * $onetwofrqc) / ($onefrqc +$twofrqc) 
		if $dstat; 
	    
	    if ($llstat) {#the log like score according to Manning and Schuetze
		$p=$twofrqc/$numwords;
		$p1=$onetwofrqc /$onefrqc;
		$p2=($twofrqc-$onetwofrqc)/($numwords-$onefrqc);
		$loglikescore{$key}=-0.5*(&loglike($onetwofrqc, $onefrqc, $p) + 
			&loglike($twofrqc-$onetwofrqc, $numwords-$onefrqc, $p) -
			&loglike($onetwofrqc, $onefrqc, $p1) - 
			&loglike($twofrqc-$onetwofrqc, $numwords-$onefrqc, $p2));
	    };
	}
    };
}



# preparing focus - using collocation statistics, to be extended -- > e.g., using intersection of lists, or ranking list by numbers of occurrences in collocation tables
sub prepareFocus4NLG(@LFocusNew0){
    my @LFocusNew = ();
    foreach $el (@LFocusNew0){
        if ($el =~ /^(.+)~(.+)$/){
            $collWord4nlg = $1;
            $collWordScore = $2;
        }else{
            $collWord4nlg = $el;
        }
        push @LFocusNew, $collWord4nlg;
    }
    

    return @LFocusNew

}

# cleanup of collocation lists, e.g., number strings are adjectives -- remove; proper names --> issue
sub cleanupCollList4NLG{
    my @LCollocsClean = ();
    my @LCollocs = @_;
    for $el (@LCollocs){
        
        if ($el =~ /~/){
            ($word, $score) = split(/~/, $el);
            if ($word =~ /[0-9]/){
                next;
            }else{
                push @LCollocsClean, $el;
            }
            
        }else{

            if ($el =~ /[0-9]/){
                next;
            }else{
                push @LCollocsClean, $el;
            }

            
        }
    }

    return @LCollocsClean;

}


sub prepareCollocList4NLG{
    my @collocationstr4nlg = @_;
    # my @collKWordMatchList = ();
    my %collKWordMatch;
    my %coll4KWordSc; # $collKWordSc{$coll} = $sc collocation scores for each matched keyword: the main data structure to update and be used for ranking...
    my @coll4nlgList = ();
    # my @coll4nlgList = @collocationstr4nlg;
    
    foreach $collocpairscore (@collocationstr4nlg){
        if ($collocpairscore =~ /^(.+)\t(.+)~(.*)$/){
            my $kw = $1; # print "kw = $kw ; ";
            my $coll = $2; # print "coll = $coll ; ";
            my $sc = $3 + 0; # print "sc = $sc ; ";
            my $collscore;
            # if ($printproofcolloc4nlg0){
            if ($printproofscores4nlg0){
                $collscore = "$coll~$sc"; # print "collscore = $collscore ; <br>\n";
            
            }else{
                $collscore = "$coll"; # print "collscore = $collscore ; <br>\n";
                
            }
            $coll4KWordSc{$coll} = $sc;
            # print "coll = $coll; sc = $sc;; ";
            $collKWordMatch{$kw}++ ;
            push @coll4nlgList, $collscore;
        }
    }
    # my @collKWordMatchList = keys %collKWordMatch;
    ## print "<br>\n---prepareCollocList4NLG---list:<br>\n";
    ## print @collKWordMatchList, " len: " , scalar(@collKWordMatchList) ; # %collKWordMatch;
    ## print "<br>\n----<br>\n";
    
    
    

    # return (\@collKWordMatchList, \@coll4nlgList);
    return (\%collKWordMatch, \@coll4nlgList, \%coll4KWordSc); # last = hash for each collocation having the score...


}

# sentence-level function


sub prepareNlgFilterTemplateX4NLG{
    my @nlgFilterTemplateX = @_;
    # returned lists
    my @nlgFilterTemplateXPos = ();
    my @nlgFilterTemplateXLofLStop = ();
    my @nlgFilterTemplateXLofLGo = (); 
    my @rejectTemp = ();
    
    foreach my $el ( @nlgFilterTemplateX ){
        my @nlgFilterTemplateXLStop = (); # list of strings
        my @nlgFilterTemplateXLGo = (); # list of strings
        
        if ($el =~ /=/){
            @LElWords = split /=/, $el;
            # $strDebugX = $strDebugX .  "    LElWords = @LElWords<br>\n";
            push @nlgFilterTemplateXPos, $LElWords[0];
            $SWordsRejectInject = $LElWords[1]; 
            # $strDebugX = $strDebugX . "    SWordsRejectInject = $SWordsRejectInject<br>\n";
            @LWordsRejectInject = split(/\,/, $SWordsRejectInject); $ILen = scalar(@LWordsRejectInject); 
            # $strDebugX = $strDebugX . "    LWordsRejectInject = @LWordsRejectInject; $ILen <br>\n";
             
            my $ICountElWords = 0;
            foreach my $SWord (@LWordsRejectInject){
                $ICountElWords++;
                # $strDebugX = $strDebugX . " SWord=$SWord ";
                ##### delete next string #### 
                # if($ICountElWords <= 1){ $strDebugX = $strDebugX . " ICountElWords = $ICountElWords "; next; }; # first el of the array is PoS, skip
                
                # remove leading identifiers: stop / go list
                if($SWord =~ /^;(.+)/){ # reject word
                    # $strDebugX = $strDebugX . " xSWordX = $1 ";
                    push @nlgFilterTemplateXLStop, $1;
                    push @rejectTemp, $1;
                }elsif($SWord =~ /^:(.+)/){ # inject word
                    # $strDebugX = $strDebugX . " +SWord+ = $1 ";
                    push @nlgFilterTemplateXLGo, $1;
                    
                }else{ # undefined so far, possibly for future functionality; ignore
                
                };
                
                
            }

            
        }else{
            push @nlgFilterTemplateXPos, $el;
            push @nlgFilterTemplateXLStop, "[NONE]";
            push @nlgFilterTemplateXLGo, "[NONE]";
    
        };
        push @nlgFilterTemplateXLofLStop, \@nlgFilterTemplateXLStop ;
        push @nlgFilterTemplateXLofLGo, \@nlgFilterTemplateXLGo; 
    
    }
    
    return (\@nlgFilterTemplateXPos, \@nlgFilterTemplateXLofLStop, \@nlgFilterTemplateXLofLGo, \@rejectTemp);
    # 
    
}


sub recombineCollocHash4NLG2Hashes{
    my ($ref_hBeamComb , $ref_hBeamCombLine) = @_ ;
    my %hBeamComb = %{$ref_hBeamComb} ;
    my %hBeamCombLine = %{$ref_hBeamCombLine} ;
    my %hBeamComb0 ;
    
    if (scalar(keys %hBeamComb) == 0 and scalar(keys %hBeamCombLine) == 0 ){
        %hBeamComb0 = {};
    }elsif( scalar(keys %hBeamComb) == 0  ){
        %hBeamComb0 = %hBeamCombLine;
    }elsif( scalar(keys %hBeamCombLine) == 0  ){
        %hBeamComb0 = %hBeamComb;
    }else{
        foreach my $collstr (sort {$hBeamComb{$b} <=> $hBeamComb{$a}} keys %hBeamComb){
            foreach my $collstrLine (sort {$hBeamCombLine{$b} <=> $hBeamCombLine{$a}} keys %hBeamCombLine){
                $collstr0 = "$collstr $collstrLine ";
                $sc0 = $hBeamComb{$collstr} + $hBeamCombLine{$collstrLine};
                $hBeamComb0{$collstr0} = $sc0;

    
            }
            
        }
    }
    
    
    
    return \%hBeamComb0;
    
}

sub recombineCollocHash4NLG{
    my $maxComb = 15; # to implement this as an optional feature --> if needed we restrict the search space
    my $curComb = 0;
    my @LoHCollocSc = @_;
    my %hBeamComb = {};
    # my %hBeamComb;
    
    print "LoHCollocSc = @LoHCollocSc <br>\n";
    foreach my $ref_CollScHash (@LoHCollocSc) { 
        %CollScHash = %{$ref_CollScHash};
        my %hBeamCombLine;
        foreach my $collocation (sort {$CollScHash{$b} <=> $CollScHash{$a}} keys %CollScHash){
            if ($collocation =~ /[0-9]/){
                next;                
            };
            if ( grep( /^$collocation$/, @rejectTemp ) ) { # reject collocations in stoplist
                next;
            };
            # if (){};
            
            $currComb++;
            if($currComb > $maxComb){ 
                print " :: currComb = $currComb [break] :: "; 
                last;
            };
            
            $score = $CollScHash{$collocation};
            my $sc = $score + 1;
            my $logsc = log($sc);
            
            $hBeamCombLine{$collocation} = $logsc;

            
            print "$collocation : $score ;;   ";
        }
    
        $ref_hBeamComb0 = recombineCollocHash4NLG2Hashes(\%hBeamComb , \%hBeamCombLine);
        %hBeamComb0 = %{$ref_hBeamComb0};
        %hBeamComb = %hBeamComb0;
        
        
        $currComb = 0;
        print " -- line<br><br>\n\n";
        
    }
    foreach my $collstring (sort {$hBeamComb{$b} <=> $hBeamComb{$a}} keys %hBeamComb){
        $sccombined = $hBeamComb{$collstring};
        print "$collstring = $sccombined <br>\n";    
    }
    print "list end <br>\n";


}


sub recombineColloc4NLG2File{
    # my $refNoOfSent, $refLoLColloc = @_;
    # my $nOfSent = ${$refNoOfSent};
    # my @LoLColloc = @{$refLoLColloc};
    my @LoLColloc = @_;
    $nOfSent5 = $noofsentences4nlg50;
    
    print "<br><br>\n\n Recombining collocations. This may take some time. Results will be printed on <a href='http://corpus.leeds.ac.uk/corpuslabs/lab201810cnlg/labspace/'>http://corpus.leeds.ac.uk/corpuslabs/lab201810cnlg/labspace/</a><br>\n";
    open(my $fh, '>', "/data/html/corpuslabs/lab201810cnlg/labspace/$nlgOutputSentenceFile0") or die "Could not open file '$nlgOutputSentenceFile0' $!";

    for (my $i = 1; $i <= $nOfSent5; $i++){
        # print $fh "\n";
        # if ($printproofcolloc4nlg0){ print "<br>\n<br>\n";};
        foreach $refLColloc (@LoLColloc){
            my @LColloc = @{$refLColloc};
            my $randomColloc = $LColloc[rand @LColloc];
            print $fh "$randomColloc ";
            
        }
        print $fh "\n";

    }

    close $fh;
    print "done<br>\n";
    
        
}


sub recombineColloc4NLG{
    # my $refNoOfSent, $refLoLColloc = @_;
    # my $nOfSent = ${$refNoOfSent};
    # my @LoLColloc = @{$refLoLColloc};
    my @LoLColloc = @_;
    $nOfSent = $noofsentences4nlg0;
    for (my $i = 1; $i <= $nOfSent; $i++){
        print "<br>\n$i. ";
        # if ($printproofcolloc4nlg0){ print "<br>\n<br>\n";};
        foreach $refLColloc (@LoLColloc){
            my @LColloc = @{$refLColloc};
            my $randomColloc = $LColloc[rand @LColloc];
            print "$randomColloc ";
            
        }

    }
        
}


sub recombineColloc4NLGcartesianproduct{
    my @LoLColloc = @_;
    print "<br><br>\n\n Recombining collocations. This may take some time. Results will be printed on <a href='http://corpus.leeds.ac.uk/corpuslabs/lab201810cnlg/labspace/'>http://corpus.leeds.ac.uk/corpuslabs/lab201810cnlg/labspace/</a><br>\n";
    open(my $fh, '>', "/data/html/corpuslabs/lab201810cnlg/labspace/$printcartesianpr4nlg0") or die "Could not open file '$printcartesianpr4nlg0' $!";

    for $el (@LoLColloc){
        print $fh join(" ", @$el), "\n";
    }
    close $fh;
    print "done<br>\n";
        
}



sub recombineColloc4NLGcartesianproductHashScores{
    my @LoLColloc = @_;
    my %hCollocScores = (); # output
    my @lCollocScores = (); # returned sorted list?
    
    for $el (@LoLColloc){
        # print $fh join(" ", @$el), "\n";
        my $lineCollocStr = join(" ", @$el);
        my @lineColloc = @$el;
        my $lineCollocStrNoScores = "";
        my @lineCollocNoScores = (); # for collecting clean words, without scores if that is required for output
        my $scCombined = 0;
        
        for $word (@lineColloc){
            my $wd = ""; 
            my $sc = 1; 
            my $logsc = 0;
            if($word =~ /^(.+)~(.+)$/){
                $wd = $1;
                $sc = $2 + 1;
                $logsc = log($sc);
            }elsif($word =~ /^(.+)$/){
                $wd = $1;
                $sc = 1;
                $logsc = 0;
            }else{
                next;    
            };
            push(@lineCollocNoScores, $wd); 
            $scCombined += $logsc;
        };
        
        $lineCollocStrNoScores = join(" ", @lineCollocNoScores);
        if($onlycombinedcores4nlg0){
            $hCollocScores{$lineCollocStrNoScores} = $scCombined;
        }else{
            $hCollocScores{$lineCollocStr} = $scCombined;
        }
        
        
    };
    
    # $onlycombinedcores4nlg0
    
    my @lCollocScoresSorted = sort {$hCollocScores{$b} <=> $hCollocScores{$a}} keys %hCollocScores;
    for $line (@lCollocScoresSorted){
        my $sc = $hCollocScores{$line};
        my $line_sc = "$line\t$sc";
        push(@lCollocScores, $line_sc);
        # 
    
    };
    
    return @lCollocScores;

    
}

sub recombineColloc4NLGcartesianproductPrintList{
    my @LtoPrint = @_;
    print "<br><br>\n\n Recombining collocations. This may take some time. Results will be printed on <a href='http://corpus.leeds.ac.uk/corpuslabs/lab201810cnlg/labspace/'>http://corpus.leeds.ac.uk/corpuslabs/lab201810cnlg/labspace/</a><br>\n";
    open(my $fh, '>', "/data/html/corpuslabs/lab201810cnlg/labspace/$printcartesianpr4nlg0") or die "Could not open file '$printcartesianpr4nlg0' $!";
    for $line_sc (@LtoPrint){
        print $fh $line_sc, "\n";
    }
   
    close $fh;
    print "done<br>\n";

}



sub permute {
    my $last = pop @_;
    unless(@_) {
           return map([$_], @$last);
    }

    return map { 
                 my $left = $_; 
                 map([@$left, $_], @$last)
               } 
               permute(@_);
}



sub recombinePairs{
    my @AofPairs = @_;
    $nOfSent = 10;
    for (my $i = 1; $i <= $nOfSent; $i++){
        print "List: $i <br>\n";
            foreach $refPairs (@AofPairs){
            my %aPairs = %{$refPairs};
            my @aPairs_keys = keys %aPairs;
            my $random_key = $aPairs_keys[rand @aPairs_keys];
            print "$random_key <br> \n";
        }
    
    }    
    
}


sub showcollocates {
    computecollocates($onefrqc,$numwords,\%freq,\%pairs);
  # beginning of collocate page, titles an intro blurb
    if ($printproofcolloc4nlg0){
        printf STDOUT $messages{'colloc-header'}, $corpuslist, $numwords, $searchstring, $collocspanleft, $collocspanright, $collocfilter;
        
    }

  # print short html anchor for each association measure requested
  if ($llstat && $printproofcolloc4nlg0) { print STDOUT qq{<p><a href="#LL score">LL score</a></p>\n};}
  if ($mistat && $printproofcolloc4nlg0) { print STDOUT qq{<p><a href="#MI score">MI score</a></p>\n};}
  if ($dstat && $printproofcolloc4nlg0)  { print STDOUT qq{<p><a href="#Dice score">Dice score</a></p>\n\n};};
  if ($tstat && $printproofcolloc4nlg0)  { print STDOUT qq{<p><a href="#T score">T score</a></p>\n\n};};
  my $i=0;
  # call nex sub for each ass-measure, building the collocate tables' headings
  if ($llstat) {
      @collocationstr4nlg = printscoretable('LL score',\%loglikescore,$cutoff);
  }
  if ($mistat) {
      @collocationstr4nlg = printscoretable('MI score',\%miscore,$cutoff);
  }
  if ($dstat) {
      @collocationstr4nlg = printscoretable('Dice score',\%dicescore,$cutoff);
  }
  if ($tstat) {
      @collocationstr4nlg = printscoretable('T score',\%tscore,$cutoff);
  }
  print STDOUT $pagefooter; 
  return @collocationstr4nlg;
}

sub printscoretable {
    my ($name,$scoreref,$cutoff)=@_;
    my $i=0;
    my @collocationstr4nlg = ();
    if ($printproofcolloc4nlg0){
        collocateheader($name);
    }
    
    foreach my $key (sort { ${$scoreref}{$b} <=> ${$scoreref}{$a} } keys %{$scoreref}) {
      printcollocstring($key,${$scoreref}{$key});
      $i++;
      $score4nlg = ${$scoreref}{$key};
      push @collocationstr4nlg, "$key~$score4nlg";
      last if $i>$cutoff;
    };
    if ($printproofcolloc4nlg0){
        print STDOUT $collocatefooter; # finish the table
    }
    
    
    # print "<br> collocationstr4nlg : <br> \n";
    # print @collocationstr4nlg ;
    # print "<br>\n";
    return @collocationstr4nlg;
}

sub collocateheader {
  print STDOUT qq{<h2><a name="$_[0]"/>$_[0]</h2>\n};
  # start printing table and table header
  print STDOUT qq{<table>\n};
  print STDOUT qq{<thead>\n};
  printf STDOUT qq{  <tr>
    <td> %s </td>
    <td> %s </td>
    <td> %s </td>
    <td> %s </td>
    <td> %s </td>
    <td> %s </td>
  </tr>}, $messages{'collocation'}, $messages{'joint-frq'}, $messages{'frq1'}, $messages{'frq2'}, $_[0], $messages{'concordance'};
  # close table header an start printing table body
  print STDOUT qq{\n</thead>\n};
  print STDOUT qq{<tbody>\n};
}

# PRINT the matched collocation strings as HTML, called by sub printscoretable
sub printcollocstring {
    my ($key,$score)=@_;
    my $pair=''; #this is what we print
    my $defaultattrname='lemma'; #collocates are displayed by lemma
    if (($w1,$w2)=$key=~/^(.+)\t(.+)$/) {
	$frqc1=$freq{$w1};
	$frqc2=$freq{$w2};
	if (($collocspanleft == 1) and (!$collocspanright)) {
	    #we're searching for immediate left collocates, but the collocate is after the key, so let's reverse
	    $pair="$w2 $w1"; 
	    ($frqc1,$frqc2)=($frqc2,$frqc1) 
	} elsif (($collocspanright == 1) and (!$collocspanleft)) {
	    $pair="$w1 $w2"; 
	} else {
	    $pair="$w1 ~~ $w2";
	};
	if (($curlang eq 'ru') and ($transliterateout)) {
	    $pair=cyr2lat($pair);
	};
	$searchstring4print="MU(meet [$defaultattrname='$w1'] [$defaultattrname='$w2'] -$collocspanleft $collocspanright)\&cqpsyntaxonly=1";
    # removing for clarity -- to be restored:
    if($printproofcolloc4nlg0){
        printf STDOUT qq{  <tr>
        <td>%s</td>
        <td align="right">%s</td>
        <td align="right">%s</td>
        <td align="right">%s</td>
        <td align="right">%3.2f</td>
        <td align="center"><a target="_blank" href="$cqpsearchprefix$searchstring4print\&amp;corpuslist=$corpuslist">%s</a></td>
      </tr>\n}, $pair, $pairs{$key}, $frqc1, $frqc2, $score,$messages{'examples'};
        
    }

    };
}

sub getlearningrestrictlist {
    my $cgiquery=shift;
    my $learningrestrictstr='';
    my $frequencyband=$cgiquery->param("frequencyband");
    $learninggeneraliselist=$cgiquery->param("learninggeneraliselist");
    if ($cgiquery->param("knownwordsfile")) { 
	my $upload_filehandle = $cgiquery->upload("knownwordsfile"); 
	print STDERR "$! for ",$cgiquery->param("knownwordsfile"); 
	binmode( $upload_filehandle, ":utf8" );
	while ( <$upload_filehandle> ) {
	    s/\#.+//;
	    $learningrestrictstr.="$_ ";
	}
	@restrictwords{split /\s+/,$learningrestrictstr}=();
    } elsif ($frequencyband) {
	tie(%RESTRICTWORDS, 'GDBM_File', "$lexicondb/$frequencyband-$curlang", O_RDONLY, 0444) or cqperror("Cannot open dictionary $lexicondb/$frequencyband-$curlang\n");
	while (($key,$val) = each %RESTRICTWORDS) {
	    $flag = utf8::decode($key);
	    $restrictwords{$key}=$val;
	}
	untie(%RESTRICTWORDS);
	printdebug("total restrict words ", scalar(keys(%restrictwords)), "\n");
    };
    if ($learninggeneraliselist) {
	@learninggeneraliselist=split(/\s+/,$learninggeneraliselist);
	if (($cgiquery->param("similaritylist")) and (tie(%LEXICALCLASS,'GDBM_File', "$lexicondb/$cname.simlist", O_RDONLY, 0444))) {# or cqperror("Cannot the similarity database $lexicondb/$cname.simlist\n");
	    $maxsim=10;
	    push @learninggeneraliselist, generatesimilaritylist(@learninggeneraliselist);
	    untie(%LEXICALCLASS);
	};
	@restrictwords{@learninggeneraliselist}=();
	$learninggeneraliselist=join('|',sort @learninggeneraliselist);
    }
    return $learningrestrictstr;
}

#the procedure takes a CSAR query and outputs a valid CQP query
sub makecqpquery {
local $_=shift;
#my $cqpsyntaxonly;
s/^\s+//;
s/\s+$//;
s/\s+/ /g;

unless (($cqpsyntaxonly) or (substr($_,0,3) eq 'MU(')) {
    #preprocess the query
    if (($curlang eq 'ru') and ($transliteratein)){
	$_=&lat2cyr($_);
    };
#     if (($curlang eq 'ru') and (dbmopen(%RUSLEMMALIST,"$lexicondb/$cname.lemmas",0444)) 
# 	and ($ruscorpus = new CWB::CL::Corpus $cname)) {
# 	$ruslemmaattr = $ruscorpus->attribute("lemma", 'p');
#     };
    @wordlist=split /\s+/, $_;
    if (scalar(@wordlist) == 1) { # the simplest case
	$_= processword($wordlist[0]);
    } elsif ((substr($_,0,1) eq '"') and (substr($_,-1,1) eq '"')) { # a strict sequence
	@wordlist=split /\s+/, substr($_,1,length($_)-2);
	foreach $word (@wordlist) {
	    $word= processword($word);
	};
	$_=join(' ',@wordlist);
    } elsif (scalar(@wordlist)>1) {  #a mu query; the output should be like MU(meet (meet 'x' 'y' s) -3 5)
	$lengthincrement=0;
	($prevdist,$newquery)=processmuqueryword(shift @wordlist,$lengthincrement++);
	foreach $word (@wordlist) {
	    if (substr($word,0,1) eq '.') {
		if ($word eq '.') { # exactly one word in between; 
		    $distfrom=1;
		    $distto=1;
		} elsif ($word eq '.?') { # an optional word in between
		    $distfrom=0;
		    $distto=1;
		} elsif (($distfrom,$distto)=$word=~/^\.\.(\d*)-?(\d*)$/) { # a range of optional words in between: ..3 shortcut to {0,3}
		    $distfrom=0 unless $distfrom;
		    $distto=2 unless $distto;
		};
		$lengthincrement+=$distto;
		next; # we do not output anything in this case
	    };
	    ($newdist,$word)=processmuqueryword($word,$lengthincrement++);
	    $dist='s';
	    unless (($newdist) eq 's') {
		$dist="-$prevdist $newdist";
		$prevdist=$newdist;
	    };
	    $newquery=" (meet $newquery $word $dist)";
	    
	}
	$_='MU'.$newquery;
    };

};

return $_;
}

sub readconffile {
    my $conffile=shift || '/corpora/tools/cqp.conf';
    if (-f $conffile) {
	{eval 
	     require $conffile;
	};
    }
}

sub readmessagefile {
    my $conffile=shift || '/corpora/tools/messages.conf';
    if (my $fh=openfile($conffile)) {
	while (<$fh>) {
	    chomp;
	    if (my ($key,$value)=/(\S+?)\s+(.+)/) {
		$messages{$key}=$value;
	    }
	}
    }
}

1;

=head1 NAME

I<cqpquery.pm>: module to perform basic operations with querying corpora encoded in CWB.
Primarily, this concerns presenting concordance lines and collocation lists.

=head1 SYNOPSIS

$searchstring=makecqpquery($originalquery);

$numoccur=processcorpus($corpus, $searchstring);

showconcordance(\@storecontexts,0); # for displaying concordances

OR

showcollocates(); #for printing collocate lists


=head1 DESCRIPTION

This module exports the following functions:

=head2 cqperror

takes a string and outputs it as an error

=head2 computecollocates

Computes collocates

Input:

=item * the number of occurrences of a search term, 

=item * the cumulative corpus size (possibly from several real corpora)

=item * a reference to a hash with frequencies of tokens

=item * a reference to a hash with frequencies of pairs of tokens

Tokens must be split with the tab.

Depending on the values of global variables llstat, mistat, dstat and tstat
the procedure populates global hash variables %loglikescore, %miscore, %dicescore  and %tscore 

=head2 getattrpos

returns the string value for a cpos and attribute, converts to UTF8, corrects quotes.

Input:

=item * corpus position

=item * attribute object

Output: string

=head2 getlearningrestrictlist 

gathers additional information for the language learning interface (it
restricts concordance line according to the set of words known by the
learner).

Input:

=item * CGI query object

=head2 getlemma 

returns the string value for a cpos of the lemma attribute via getattrpos.

Input:

=item * corpus position

Output: string

=head2 getlemmas 

returns the string value for a cpos range of the lemma attribute via getattrpos.

Input:

=item * starting corpus position

=item * beginning of the offset

=item * end of the offset

Output: string

=head2 getword 

returns the string value for a cpos of the word attribute via getattrpos.

Input:

=item * corpus position

Output: string

=head2 getwords 

returns the string value for a cpos range of the word attribute via getattrpos.

Input:

=item * starting corpus position

=item * beginning of the offset

=item * end of the offset

Output: string

=head2 loglike

computes the loglikelihood value according to Manning&Schutze

Input:

=item * k, n, x (see M&S)

Output:

=item * float

=head2 makecqpquery 

converts a CSAR query to a proper CQP query unless $cqpsyntaxonly is
set.  Plain words are converted according to the value of
$defaultattrname.  If more than one tokens are in the query, they are
joined using the MU syntax (to save processing time), unless they are
in quotes.  In this case the standard CQP syntax is used (this
emulates the behaviour of search engines).

Input:

=item * CSAR query

Output:

=item * CQP query

=head2 printdebug 

prints debugging information into DEBUGLOG if $debug is set

Input:

=item * string to print

=head2 processcorpus 

processes one CWB corpus at a time. Populates %freq and %pairs if
$collocstat is set (for unigram and bigram frequencies), populates
@storedcontexts otherwise (if we are after concordance lines)

Input:


=item * corpus name

=item * CQP query

Output:

=item * the number of lines returned

=head2 readconffile 

reads a configuration file.

=head2 readmessagefile 

Reads the file with messages.  With the exception of messages output
by CQP, the output can be localised.

=head2 showcollocates  


=head2 showconcordance 

Prints a set of concordance lines to STDOUT.  

Input:

=item * a reference to a list of corpus positions (the format: corpus.begin.end)

=item * flag for a wider selection (otherwise it displays normal
one-line concordances), adds text level annotation

Bells and whistles:

=item 1. skipping repeated lines

=item 2. displaying lemmas and pos tags (using <span>)

=item 3. displaying parallel translations (corpus names stored in $parallel)

Sorting by:

=item 1. document

=item 2. left/right

=item 3. word/lemma

=item 4. frequency on the left/right (akin to building a concordance,
but already with examples; the function has been suggested by Jeremy Munday)

=head1 DEPENDENCIES

L<CL> Perl interface, CWB

=head1 AUTHOR

Serge Sharoff, University of Leeds

=head1 ACKNOWLEDGMENTS

Thanks to Marco Baroni and Stefan Evert for help, advice and testing.

=head1 BUGS

Probably many: if you find one, please let me know


=head1 COPYRIGHT

Copyright 2007, Serge Sharoff

This module is free software. You may copy or redistribute it under
the same terms as Perl itself.

=head1 SEE ALSO

http://cwb.sourceforge.net

=cut