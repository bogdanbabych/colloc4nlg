'''
Created on 19 Nov 2018

@author: bogdan
'''

import os, sys, re, getopt
# from astropy.io.fits.convenience import append


class clPatterns(object):
    '''
    working with pattern extraction from annotated format
    '''
    

    def __init__(self, argv):
        '''
        Constructor
        '''
        # default value
        # self.FInput = open(sys.argv[2], 'rU')
        self.FInput = None
        
        try:
            opts, args = getopt.getopt(argv, "i:x:", ["inputfile=", "exec="])
            sys.stderr.write(f"{opts}\n")
        except getopt.GetoptError:
            sys.stderr.write('options error\n')
            sys.exit(2)
            
        for opt, arg in opts:
            if opt == '-i':
                # sys.stderr.write(f"{opt} -> {arg}\n")
                self.openFileR(arg)
            
            if opt == '-x':
                if re.match('putTagS', arg):
                    self.putTagS(arg)
                elif re.match('vrt_', arg):
                    DPatterns = self.selectVRTCol(arg)
                    self.printDict(DPatterns)
                    
    
    def openFileR(self, SFInput = sys.argv[1]):
        self.FInput = open(SFInput, 'rU')
        return
                
        
        
    def putTagS(self, arg):
        # inserting tags at the end of each line in the text file (for PoS tagger)
        # task 1:
        LArgs = re.split('_', arg)
        BToLower = False
        if 'lc' in LArgs: BToLower = True
        
        for SLine in self.FInput:
            SLine = SLine.rstrip()
            if BToLower: SLine = SLine.lower()
            SLine = '<s> ' + SLine + ' </s>'
            print(SLine)
        return

    def selectVRTCol(self, arg):
        # selecting column from a VRT file
        # task 2:
        DPatterns = {}
        
        LInColNum2 = []
        LInColNumIndex = []
        LInColNumb = re.split('_', arg)
        for el in LInColNumb[1:]:
            # sys.stderr.write(f'Field:{el}\n')
            
            RMatch = re.match('([0-9]+)i$', el)
            if RMatch:
                SElIndex = RMatch.group(1)
                IElIndex = int(SElIndex)
                LInColNumIndex.append(IElIndex)
                continue
            IEl = int(el)
            LInColNum2.append(IEl)
        
        # ICol = int(col)
        LInput = self.splitTagS()
        for el in LInput:
            SCol, LChunks = self.processVRT(el, LInColNum2)
            # sys.stderr.write(SCol)
            # sys.stderr.write('... column\n')
            for el in LChunks:
                el = el.lstrip()
                el = el.rstrip()
                try:
                    DPatterns[el] += 1
                except:
                    DPatterns[el] = 1
            '''
            try:
                DPatterns[SCol] += 1
            except:
                DPatterns[SCol] = 1
            '''
        # sys.stderr.write(f'{ar} + {col}\n')
        return DPatterns




    # supporting functions
    def splitTagS(self):
        # splitting on <s> tags
        sys.stderr.write("splitting tags...\n")
        SInput = self.FInput.read()
        LInput = re.findall(r'<s>.+?</s>', SInput, re.IGNORECASE|re.DOTALL|re.MULTILINE)
        # tag = re.compile('<s>.+</s>')
        # LInput = re.split(tag, SInput)
        sys.stderr.write(str(len(LInput)) + "\n")
        return LInput
    
    
    def processVRT(self, SSegment, LICol):
        # preparing one pattern identified as a segment by <s>split
        LSegment = re.split('\n', SSegment)
        LCol = []
        SCol = '' # Column(s) selected = returned value
        for SLine in LSegment:
            SLine.rstrip()
            if re.match('^<.+?>$', SLine):
                continue
            try:
                LLine = re.split('\t', SLine)
                LSSelectedFields = [] # one or more fields selected
                for IEl in LICol:
                    SColumn = LLine[IEl]
                    # sys.stderr.write('SColumn: ...' + SColumn + '\n')
                    LSSelectedFields.append(SColumn)
                SSelectedFields = '/'.join(LSSelectedFields)
                LCol.append(SSelectedFields)
            except:
                continue
        SCol = ' '.join(LCol)
        SCol = re.sub('(NP ?)+', '[ProperName] ', SCol)
        LChunks = re.split('[,\.\:\(\)\;]', SCol)
        # print(SCol)
        # print('\n')
        return SCol, LChunks
    
    def printDict(self, DFrq):
        LTlistOfTuples = sorted(DFrq.items(), key=lambda x: (x[1], x[0]), reverse=True)
        for TEl in LTlistOfTuples:
            print(TEl[0], '\t', TEl[1])
    

        
        
if __name__ == '__main__':
    OPatterns = clPatterns(sys.argv[1:])
    # OPatterns.putTagS()
    