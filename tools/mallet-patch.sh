#!/usr/bin/env bash

# check command line parameter: exit if zero, or not a directory
# I hate bash scripting.

if [ -z $1 ]; then

    echo "Usage: mallet-patch.sh <mallet base dir>.";
    echo "Need existing directory as mallet base dir argument.";
    exit;
fi

if [ ! -d $1 ]; then

    echo "Usage: mallet-patch.sh <mallet base dir>.";
    echo "Need existing directory as mallet base dir argument.";
    exit;
fi


    export malletdir=$1

# strip trailing slash in malletdir

    malletdir=${malletdir%/}

# cat patch to tempfile

    export fn=`mktemp -t malletpatch`

    cat << EOT > $fn
120c120,125
< 	return entries.get(index);
---
> 	// pado@coli.uni-saarland.de 18.05.2006
> 	// Workaround for unseen class labels in test data
> 	if (index > entries.size()-1)
> 	    return entries.get(0);
> 	else
> 	    return entries.get(index);

EOT
    
# apply patch
    
    patch -N $malletdir/src/edu/umass/cs/mallet/base/types/Alphabet.java $fn

    rm -f $malletdir/src/edu/umass/cs/mallet/base/types/Alphabet.java.rej

# if patch has been applied already, delete the file we 
    
    
# re-make mallet (base and jar should suffice)
    
    cd $malletdir
    make mallet-base jar
    cd -
    
