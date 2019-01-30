'''
Created on 14 Jan 2019

@author: bogdan
'''


import sys, os, re


class clCorpusDBprep(object):
    '''
    prepare a corpus DB for word forms from a vertical document format (vrt)
    '''


    def __init__(self, SFInput):
        '''
        Constructor
        '''
        # print('This is clCorpusDBprep')
        FInput = open(SFInput, 'rU')
        i = 0
        DDWForms = {}
        DPoSConf = {} # dictionary PoS configurations
        
        LConf = [] # current configuration -- as a list : when configuration breaks then index all lexical items
        
        
        
        for SLine in FInput:
            i+=1
            SLine = SLine.rstrip()
            if i%1000000 == 0: sys.stderr.write(SLine + '\n')
            if re.match('^(.+)\t(.+)\t(.+)$', SLine):
                RFields = re.match('^(.+)\t(.+)\t(.+)$', SLine)
                TMatches = RFields.groups()
                (SWord, SPoS, SLemma) = TMatches
                try:
                    DTLemPos = DDWForms[SWord] # frequency dictionary of lemmatization options
                except:
                    DTLemPos = {}
                
                if (SLemma, SPoS) in DTLemPos.keys(): # if such combination of PoS code and Lemma already exists:
                    # update frequency
                    IFrqLemPos = DTLemPos[(SLemma, SPoS)]
                    IFrqLemPosNew = IFrqLemPos + 1
                    DTLemPos[(SLemma, SPoS)] = IFrqLemPosNew
                else: # if there has not been such combination of PoS and Lemma
                    DTLemPos[(SLemma, SPoS)] = 1
                    
                DDWForms[SWord] = DTLemPos
                # print(TMatches)
                
                # processing configurations
                LConf.append((SLemma, SPoS))
            
                
        i=0
        for SKey, DTVals in sorted(DDWForms.items()):
            i+=1; 
            if i%10000 == 0: sys.stderr.write(SLine + '\n')
            # print(SKey, DTVals)
            sys.stdout.write(SKey + '\t')
            for TKey, IFrqVal in sorted(DTVals.items(), key=lambda k: k[1], reverse=True):
                # sorted by inverse frequencies
                # IFrqVal = DTVals[TKey]
                (SLemma, SPoS) = TKey
                sys.stdout.write(SLemma + '/' + SPoS + ':' + str(IFrqVal) + ';')
            sys.stdout.write('\n')
            
    
    


    def procConfiguration(self, LTConf):
        """
        function: list of lexicalised lemma+pos sequences; out: a dictionary: for each lemma+pos --> a dictionary with the value of this configuration list, with the lexicalised item in that lemma -
        --> then can be converted to strings...
        """
        DWords2Conf = {}
        
        for (SLemma, SPoS) in LTConf:
            pass
        
        return DWords2Conf

if __name__ == '__main__':
    OCorpusDBprep = clCorpusDBprep(sys.argv[1])
    