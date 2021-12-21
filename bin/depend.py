#!/usr/bin/env python3
from os import path
import re

class dependencies:
    def __init__(self,in_file:str=None):
        self.order=list()
        self.hier=dict()
        if in_file and path.exists(in_file):
            self.parse(in_file)

    def add_file(self,fname,parent=None):
        x=self.hier.get(fname,None)
        if not x:
            elem={'file':fname, 'parent':list()}
            if parent:
                elem['parent'].append(parent);
            self.hier[fname]=elem
            #print(f"new : {fname} => {elem}")
        else:
            if parent and parent not in x['parent']:
                x['parent'].append(parent)
            #print(f"existing : {fname} => {x}")
        #print(f"[self.hier] : {self.hier}")

    def get_dependencies(self):
        return self.hier

    def parse(self,in_file:str):
        lines=None
        with open(in_file,'r') as f:
            lines=f.readlines()
            f.close();
        fstack=list()
        lcnt=0
        dep_type=None
        skip=False
        for i,l in enumerate(lines):
            if '<' in l:
                next
            if '.c:' in l:
                if '-o ' in l:
                    prev_l=l
                    l=re.sub(".*[\s'`]((([\w-]+|\.\.)/)*[\w-]+\.c:)","\g<1>",l)
                    #print(f"[info] cleaning up '{prev_l}' => '{l}'")
                f=re.sub(':','',l).strip()
                fstack=[f]
                lcnt=1
                dep_type=1
                if f not in self.order:
                    self.order.append(f)
                #print(f"[found it] {fstack}")
                if '<' in l:
                    skip=True
                pass
            elif '.o:' in l:
                dep_type=2
            else:
                if dep_type==2:
                    print("ERROR!!! Looks like this output is not supported.")
                    print("Expecting 'gcc -H' output, not 'gcc -M -MF -' output")
                    print("Exiting.")
                    import sys; sys.exit(-1)
                try:
                    info=l.split()
                    cnt=info[0].count('.')
                    f=info[1].strip()
                except Exception as e:
                    print(f"[line {i}] FAIL : {l}")
                    raise(e)
                #print(f"[adding it] fstack:{len(fstack)} vs cnt:{cnt}")
                while len(fstack) > cnt:
                    fstack.pop()
                    lcnt-=1
                if (lcnt != len(fstack)):
                    print("HOUSTON! We have a problem!")
                    print("lcnt and stack should be the same size")
                    print(f"lcnt = {lcnt}; len(fstack) = {len(fstack)}")
                    import sys; sys.exit(-1)
                if not skip:
                    if len(fstack)<1:
                        print(f"WARNING! empty fstack on line {i}:'{l}'")
                        continue
                    self.add_file(f,fstack[-1]) 
                    #print(f"[added] {f} {fstack[-1]}")
                    #print(f"[updated self.hier] {self.hier}")
                    if f not in self.order:
                        ind=self.order.index(fstack[-1])
                        self.order.insert(ind,f)
                    else:
                        ind1=self.order.index(f)
                        ind2=self.order.index(fstack[-1])
                        if ind1>ind2-1:
                            self.order.remove(f)
                            ind2=self.order.index(fstack[-1])
                            self.order.insert(ind2,f)
    
                        #self.order.append(f)
                fstack.append(f); lcnt+=1
        #print(f"[DONE parse self.hier] : {self.hier}")
                
    def print_for_json(self,srcdir):
        k=self.order
        kl=list(self.hier.keys())
        end=len(k)
        istr='"DEPEND_VERSION":"1.0.1",\n"filenames":['
        for i,ik in enumerate(k):
            #print(f"[DEBUG] {ik}")
            iik=f"{srcdir}/{ik}" if srcdir else ik
            if ik not in kl:
                istr+="{"+f'"name":"{iik}"'+"}"
                pass
            else:
                e=self.hier[ik]['file']
                iik=f"{srcdir}/{e}" if srcdir and not e.startswith('/') else e
                p=self.hier[ik]['parent']
                ip=[f"{srcdir}/{x}" if not x.startswith('/') else f"{x}" for x in p ] if srcdir else p
                istr+="{"+f'"name":"{iik}","included_by":{ip}'+"}"
            if i!=end-1:
                istr+=",\n"
        istr+='\n]'
        istr=re.sub("'","\"",istr)
        print(istr,end='')


        
if __name__ == "__main__":
    import argparse
    def get_args():
        parser=argparse.ArgumentParser(description=\
            "extract dependency info from gcc output")
        parser.add_argument('--src-dir',dest='src_dir',action='store',default=None,
            help='top-level directory of source code [CMake points to this dir]')
        parser.add_argument('--dependency-file',dest='dep',action='store',default=None,
            help='File that contains the dependency generated from compilation')
        # maybe in the future, we'll build and collect the dependencies, but not now
        args=parser.parse_args()
        return args
    args=get_args()
    d=dependencies(in_file=args.dep)
    #print(f"{d} (type={type(d)}")
    #print(f"{d.get_dependencies()}")
    d.print_for_json(args.src_dir)



        
