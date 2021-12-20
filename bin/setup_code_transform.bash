#!/bin/bash

cb=$1
d=$2
json_dir=$3
id=$(basename -- $d)
scriptdir=$(dirname -- $(realpath -- "${BASH_SOURCE[0]}"))
rootdir=$(pwd)
trnsrc=$rootdir/trans.src-$id
if [[ ! -d $trnsrc ]]; then 
    mkdir -p $trnsrc ; 
    [[ -L $rootdir/trans.src ]] && rm $rootdir/trans.src;
    ln -sf $trnsrc $rootdir/trans.src; 
fi
if [[ -z $json_dir ]]; then json_dir=$rootdir/cb.json; mkdir -p $json_dir; fi
if [[ -z $d ]]; then d=cgc_cbs; fi
if [[ -z $PRD_BASE_DIR ]]; then 
	echo "ERROR: \$PRD_BASE_DIR is not set!"
	echo "Exiting..."
	exit -1
fi

if [[ -z $CGC_CB_DIR ]]; then 
	echo "ERROR: \$CGC_CB_DIR is not set!"
	echo "Exiting..."
	exit -1
fi

CGC_SRC=$CGC_CB_DIR/challenges/$cb

if [[ ! -d $CGC_SRC ]]; then 
    echo "ERROR: $CGC_SRC does not exist!"
    echo "Please check name and try again"
    exit -1
fi

echo "[$0] Processing $cb [$scriptdir]"

baseline=$d/build
depend=$(realpath -- $d)/deps

transdir_=$d/$cb.transform
destdir_=$d/$cb.base
#building baseline directory
destdir=${baseline}
srcdir=$cb
incdir=include
builddir=build
destsrcdir=$destdir/cgc_src
destbuilddir=$destdir/$cb/$builddir
mkdir -p $destsrcdir $destbuilddir $depend
fullpath=$PWD/$destsrcdir
[ ! -d $destsrcdir/$cb ] && cp -r $CGC_CB_DIR/challenges/$cb $destsrcdir/
[ ! -d $destsrcdir/include ] && cp -r $CGC_CB_DIR/include $destsrcdir/
[ ! -e $destsrcdir/CMakeLists.txt ] && cp -r $scriptdir/CMakeLists.txt $destsrcdir/
    pushd $destbuilddir
      cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
      -DCMAKE_VERBOSE_MAKEFILE=ON \
      -DBUILD_SHARED_LIBS=ON \
      -DBUILD_STATIC_LIBS=OFF \
      -DCMAKE_C_COMPILER=gcc-8 \
      -DCMAKE_ASM_COMPILER=gcc-8 \
      -DCMAKE_CXX_COMPILER=g++-8 \
      -DBINARY=$cb \
      -DCMAKE_C_FLAGS="-H" \
      -DCMAKE_CXX_FLAGS="-H" \
      -DPATCHED=OFF \
      ../../cgc_src &> cfg.log
      make &> /dev/null 
      if (( $? != 0 )); then 
         echo "FAILED TO MAKE" 
         echo "Exiting."
         exit -1
      fi
      echo "Building 'include's"
      if [[ ! -e "$depend/include.cgc" ]]; then 
      pushd include
        make cgc |& egrep -w '(^\.|\-H)' | perl -p -e'if(/.*\-c\s+(.*\.c)/){ s/.*\-c\s+(.*\.c).*/$1:/; } elsif(!/^\.+ /){ undef $_; }; '"s#$fullpath/##g;" > $depend/include.cgc
        make tiny-AES128-C |& egrep -w '(^\.|\-H)' | perl -p -e'if(/.*\-c\s+(.*\.c)/){ s/.*\-c\s+(.*\.c).*/$1:/; } elsif(!/^\.+ /){ undef $_; }; '"s#$fullpath/##g;" > $depend/include.aes
      popd
      fi
      echo "Building $cb"
      pushd $cb
        make clean &> /dev/null
        make $cb |& egrep -w '(^\.|\-H)' | perl -p -e'if(/.*\-c\s+(.*\.c)/){ s/.*\-c\s+(.*\.c).*/$1:/; } elsif(!/^\.+ /){ undef $_; }; '"s#$fullpath/##g;" > $depend/$cb
      popd
    popd

# variables needed for GA and Brute_Force subdirs
idir=preprocessed/src
srcdir=$cb/src
incdir=$srcdir/include
builddir=$cb/build

for ityp in ga brute_force; do
	transdir=${transdir_}.$ityp
	destdir=${destdir_}.$ityp
	destsrcdir=$destdir/$srcdir
	destbuilddir=$destdir/$builddir

	echo "Generating "$(basename -- $transdir)" contents"
	mkdir -p $destsrcdir $destbuilddir
	cp -r $CGC_CB_DIR/challenges/$cb $destsrcdir/
	cp -r $CGC_CB_DIR/include $destsrcdir/
	cp -r $scriptdir/CMakeLists.txt $destsrcdir/
	pushd $destbuilddir &> /dev/null
	  cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
	  -DCMAKE_VERBOSE_MAKEFILE=ON \
	  -DBUILD_SHARED_LIBS=ON \
	  -DBUILD_STATIC_LIBS=OFF \
	  -DCMAKE_C_COMPILER=gcc-8 \
	  -DCMAKE_ASM_COMPILER=gcc-8 \
	  -DCMAKE_CXX_COMPILER=g++-8 \
	  -DBINARY=$cb \
	  -DPATCHED=OFF \
	  ../src &> cfg.log
          echo "$cb | configure - completed"
	  make &> build.log
          echo "$cb | build - completed"
	popd &> /dev/null
	
	pushd $destdir
	c_src=$(find $srcdir/$cb/src -type f -name "*.c" | perl -p -e"s/^$cb\///;s/\.c.*$//")
	egrep -l PATCHED $srcdir/$cb/src/*.c | perl -p -e"s#^$srcdir/##"
	patch_c_src=$(egrep -l PATCHED $srcdir/$cb/src/*.c )
	echo "PATCH_C_SRC : $patch_c_src"
	find $srcdir/$cb/src -type f -name "*.c" | perl -p -e"s/^$cb\///"  > bugged-program.txt
	mkdir -p $idir/$cb/src
	for i in ${c_src[*]}; do
	   f=$(basename $i)
	   find $builddir/ -type f -name "$f.i" -exec cp {} $idir/$cb/src/$f.c \;
	done
	ln -sf $PRD_BASE_DIR/tools/cb-multios tools
	for i in $(ls $scriptdir/cgc_test/$cb/test*.sh); do
	ln -sf $i .
	done
	ln -sf $scriptdir/polls/$cb/poller poller
	ln -sf $scriptdir/compile.pl compile.pl
	ln -sf $builddir/$cb/pov*.pov .
	
	# converting genprog cfg file
	num_pos=$(cat $scriptdir/cgc_test/$cb/test.sh | perl -p -e'if(/^p(\d+)\)/){ print ("$1\n"); } undef $_;' | tail -n 1)
	num_neg=$(cat $scriptdir/cgc_test/$cb/test.sh | perl -p -e'if(/^n(\d+)\)/){ print ("$1\n"); } undef $_;' | tail -n 1)
	cat $scriptdir/cfg-gp | perl -p -e"s/__BINARY__/$cb/g;s/__POS__/$num_pos/g;s/__NEG__/$num_neg/g;" > cfg-gp
	x=0
	#echo -e "#!/bin/bash \nmkdir -p logs;\ntimeout -k 24h 24h /usr/bin/genprog cfg-gp --search brute --continue &> logs/gp.brute_force.all.log" > runme.bash
	echo -e "#!/bin/bash\n\nmkdir -p logs;\n" > runme.bash
	chmod +x runme.bash
	for i in $(ls ./test-*.sh); do
	   ((x+=1))
	   cat cfg-gp | perl -p -e's/neg-tests\s+\d+/neg-tests 1/' | perl -p -e"s/default\.cache/default\.$x\.cache/g" > cfg-gp-$x
	   echo -ne "--test-script $i" >> cfg-gp-$x
	   # generating genprog script
	   echo -e "#!/bin/bash \nmkdir -p logs;" > runme.$x.bash
	   if [ "$ityp" == "brute_force" ]; then 
	       echo -e "/usr/bin/genprog cfg-gp-$x --search brute --continue &> logs/gp.brute_force.$x.log" >> runme.$x.bash
   	   else 
	       echo -e "\ntimeout -k 8h 8h /usr/bin/genprog cfg-gp-$x &> logs/gp.ga.$x.0.log" >> runme.$x.bash
	       echo -e "\ntimeout -k 8h 8h /usr/bin/genprog cfg-gp-$x &> logs/gp.ga.$x.1.log" >> runme.$x.bash
	       echo -e "\ntimeout -k 8h 8h /usr/bin/genprog cfg-gp-$x &> logs/gp.ga.$x.2.log" >> runme.$x.bash
	       echo -e "\ntimeout -k 8h 8h /usr/bin/genprog cfg-gp-$x &> logs/gp.ga.$x.3.log" >> runme.$x.bash
	       echo -e "\ntimeout -k 8h 8h /usr/bin/genprog cfg-gp-$x &> logs/gp.ga.$x.4.log" >> runme.$x.bash
	       echo -e "\ntimeout -k 8h 8h /usr/bin/genprog cfg-gp-$x &> logs/gp.ga.$x.5.log" >> runme.$x.bash
	       echo -e "\ntimeout -k 8h 8h /usr/bin/genprog cfg-gp-$x &> logs/gp.ga.$x.6.log" >> runme.$x.bash
	   fi
	   chmod +x runme.$x.bash
	   echo -e "./runme.$x.bash" >> runme.bash
	done
	
	
        $rootdir/sanity.bash $cb/$cb &> sanity.log
        ret=$?
        if (( $ret != 0 )); then
        echo "$cb.base.$ityp | sanity.log returned $ret [Unexpected test results]"
        else
        echo "$cb.base.$ityp | sanity.log returned $ret [PASSED]"
        fi
        
	popd
	echo "done with $destdir"

	cp -r $destdir $transdir
	pushd $transdir
	echo "Generating "$(basename -- $transdir)" contents"
	rm -rf $builddir
	mkdir -p $builddir
	pushd $builddir > /dev/null
	cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
	-DCMAKE_VERBOSE_MAKEFILE=ON \
	-DBUILD_SHARED_LIBS=ON \
	-DBUILD_STATIC_LIBS=OFF \
	-DCMAKE_C_COMPILER=gcc-8 \
	-DCMAKE_ASM_COMPILER=gcc-8 \
	-DCMAKE_CXX_COMPILER=g++-8 \
	-DBINARY=$cb \
	-DPATCHED=OFF \
	../src &> cfg.log
        echo "$cb.transform.$ityp | configure - completed"
	make &> build.log
        echo "$cb.transform.$ityp | make - completed"
	popd > /dev/null
	
	for i in ${c_src[*]}; do
	   f=$(basename $i)
	   find $builddir/ -type f -name "$f.i" -exec cp {} $idir/$cb/src/$f.c \;
	done
	
	
        if [[ ! -e $json_dir/$cb.json ]]; then 
	    echo -e "{" > $cb.json
	    #echo -e "\"filenames\":[" >> $cb.json
	    x=0
	    #echo "find $incdir $srcdir/$cb/lib -type f -name \"*.c\" "
	    #for i in $(find $incdir $srcdir/$cb/lib -type f -name "*.c" ) ; do
	    #    if (( $(echo $i | egrep -c -w 'libpov')==0 )); then 
	    #	if (( $x > 0 )); then echo -e "," >> $cb.json; fi
	    #	echo -ne "   {\"name\":\"$i\"}" >> $cb.json
	    #	x=1
	    #    fi
	    #done
	    $scriptdir/depend.py --dependency-file $depend/$cb --src-dir $srcdir >> $cb.json
	    #echo -e "" >> $cb.json
	    #echo -e "]," >> $cb.json
	    echo -e "," >> $cb.json
	    echo -e "\"ignore\":[" >> $cb.json
	    i=0; 
	    for f in ${patch_c_src[*]}; do
	        if (( $i > 0 )); then echo -e "," >> $cb.json; fi
	        echo -ne "\"$f\"" >> $cb.json
	        (( i+=1 ))
	    done
	    echo -e "\n]," >> $cb.json
	    echo -e "\"macros\":[" >> $cb.json
	    echo -ne "   {\"name\": \"PATCHED\", \"value\": false }" >> $cb.json
	    if (( $(egrep -c "VULN_COUNT" $srcdir/$cb/CMakeLists.txt)>0 )); then 
	        vuln_count=$(egrep "VULN_COUNT" $srcdir/$cb/CMakeLists.txt | perl -p -e's/set\s*\(\s*VULN_COUNT\s*\"//;s/\"\s*\)//')
	    for i in $(seq 1 $vuln_count); do
	    	echo -e "," >> $cb.json
	    	echo -ne "   {\"name\": \"PATCHED_${i}\", \"value\": false }" >> $cb.json
	    done
	    fi
	    echo -e "" >> $cb.json
	    echo -e "]," >> $cb.json
	    x=0
	    echo -e "\"disable_eval\":[" >> $cb.json
	    for i in $(nm -C $cb/$cb | egrep -w '[tTwWuU]' | awk '{print $NF}'); do
	    	if (( $x == 0 )); then echo -ne "   " >> $cb.json; fi
	    	if (( $x > 0 )); then echo -ne "," >> $cb.json; fi
	    	echo -ne "\"$i\"" >> $cb.json
	    	x=1
	    done
	    
	    echo -e "" >> $cb.json
	    echo -e "]," >> $cb.json
	    # non-destructive function calls should be enabled
	    echo -e "\"enable_eval\":[" >> $cb.json
	    echo -e "   \"cgc_strlen\"\n]" >> $cb.json
	    echo -e "}" >> $cb.json
            cp $cb.json $json_dir/$cb.json
        else
            cp $json_dir/$cb.json $cb.json
        fi

	x=0
	for i in $(ls ./test-*.sh); do
	   ((x+=1))
	   # generating genprog script
       echo -ne "\n--allow-coverage-fail" >> cfg-gp-$x
	   if [ "$ityp" == "brute_force" ]; then 
	       echo -e "#!/bin/bash \nmkdir -p logs;" > runme.$x.bash
	       echo 'export ENABLE_FIXES=1' >> runme.$x.bash
	       echo -e "perl -pi -e'if(/blacklist-src-functions/){ undef \$_; }' cfg-gp-$x" >> runme.$x.bash
	       echo 'for i in $(cat fn_blacklist.*.txt); do echo -ne "\n--blacklist-src-functions "'"\$i; done  >> cfg-gp-$x" >> runme.$x.bash
	       echo 'perl -pi -e'"'"'if(/^\s*$/){ undef $_;};'"'"'  cfg-gp-'$x >> runme.$x.bash
	       echo -e "/usr/bin/genprog-bl cfg-gp-$x --search brute --continue &> logs/gp.brute_force.$x.log" >> runme.$x.bash
       fi
	done

	echo "EXPANSION: $scriptdir/code_expand_gp.bash $cb $trnsrc $cb.json"
	$scriptdir/code_expand_gp.bash $cb $trnsrc $cb.json
        ENABLE_FIXES=1 $rootdir/sanity.bash $cb/$cb &> sanity.log
        ret=$?
        if (( $ret != 0 )); then
        echo "$cb.transform.$ityp | sanity.log returned $ret [Unexpected test results]"
        else
        echo "$cb.transform.$ityp | sanity.log returned $ret [PASSED]"
        fi
	popd
	echo "done with $transdir"
done
