'''
Created on 25 Feb 2019

@author: bogdan
'''


import os, sys, re
from collections import defaultdict


class clPrepTestKW(object):
    '''
    interprets files with keywords, prepares shell scripts for run testing.
    '''


    def __init__(self, IterStrings):
        '''
        Constructor
        '''
        
        self.LKeyWords = []
        self.DKeyWords = defaultdict(int)
        
        
        for SListKWs in IterStrings:
            SListKWs = SListKWs.rstrip()
    
            try:
                RMatch = re.search('"(.+)"', SListKWs)
            except:
                sys.stderr.write('re.search() ERROR: ' + SListKWs + '\n')
            
            try:
                StringKW = RMatch.group(1)
            except:
                sys.stderr.write('group(1) ERROR: ' + SListKWs + '\n')
                
            try:
                pass
                # sys.stderr.write(StringKW + '\n')
            except:
                sys.stderr.write('print() error for SgtringKW: ' + SListKWs + '\n')
            
            try:
                EListKW = eval(StringKW)
                # print(str(EListKW))
                
                for el in EListKW:
                    LWords = re.split(' ', el)
                    if len(LWords) == 1:
                        # self.LKeyWords.append(el)
                        self.DKeyWords[el] += 1                        
                
                
            except:
                sys.stderr.write('eval() ERROR: ' + SListKWs + '\n')
            
            
            
            
            
        
        return
        
        
    def printData(self):
        for key, val in sorted(self.DKeyWords.items()):
            self.LKeyWords.append(key)

        
        for el in self.LKeyWords:
            # print('perl cqp4nlg2cl.pl --keyword=\'%(el)s\'  > /data/html/corpuslabs/lab201810cnlg/cqp4nlg2cl_out4-%(el)s.txt' % locals())
            # print('perl /var/www/cgi-bin/cqp4nlg2cl.pl --keyword=\'%(el)s\'  > ./cqp4nlg2cl_out4-%(el)s.txt' % locals())
            print('perl /var/www/cgi-bin/cqp4nlg2cl.pl --keyword=\'%(el)s\'  > /data/html/corpuslabs/lab201810cnlg/testKWs/cqp4nlg2cl_out4-%(el)s.txt' % locals())
        
        return



if __name__ == '__main__':
    
    for SFInputFile in sys.argv[1:]:
        FInputFile = open(SFInputFile, 'rU')
        OPrepTestKW = clPrepTestKW(FInputFile)
        OPrepTestKW.printData()
        
            
    
    