#!/bin/bash

# Copyright (c) 2008 Castfire, Inc
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

# -----------------------------------------------------------------------------
# castfire_upload_content.sh
# http://www.castfire.com/
# Version 1.0 2010-05-03
#
# To run this script the following commands need to be installed:
# 1. curl                 http://curl.haxx.se/
# 2. getopt (enhanced)    http://software.frodo.looijaard.name/getopt/
# 3. perl URI::Escape     perl -MCPAN -e 'install URI::Escape'
# 4. perl MIME::Base64    perl -MCPAN -e 'install MIME::Base64'
#
# This script adds or replaces content in an existing Castfire show by POSTing 
# the media file to the castfire API. The show's id or the show's foreign key 
# is required. The show's id is returned on success. The error message is 
# printed on failure. 

# -----------------------------------------------------------------------------
# CHANGE THESE
#
# These two API values are REQUIRED. Enter your values:
API_KEY=11111-22222-33333
API_SECRET=AbcdefgHijklmnoP

# These values are optional. If a value is assigned then it is used as the
# default and doesn't need to be passed on the command line.
# NOTE: a show_id OR a foreign_key is *required* by the api.
SHOW_ID=
FOREIGN_KEY=
POSITION=
REPLACE=

# These values probably don't need to be changed.
API_URL=http://api.castfire.com/upload/content/
FORMAT=xml

CURL=/usr/bin/curl
CURLOPTS="--silent"

# -----------------------------------------------------------------------------

# Start of the script
BASENAME=`basename $0`

BASEUSAGE="Usage: $BASENAME [options] filename"

USAGE="$BASEUSAGE\nTry '$BASENAME --help' for more information."

HELP="$BASEUSAGE\nPOST show content to the Castfire server using the api.\n
\nExample: $BASENAME --show_id=9999 --position=1 --replace part2.mov
\n\nOptions:
\n\t-h, --help \t\tDisplay this help and exit.
\n\t--show_id=NUMBER \tThe show id.
\n\t--foreign_key=STRING \tThe show foreign key.
\n\t--position=NUMBER \tThe position of the content in the show.
\n\t--replace \t\tReplace the current content at the position in the show.
\n"

# Parse the command line arguments using getopt. Add new args here.
GETOPTARGS=`getopt -o h --longoptions show_id:,foreign_key:,position:,replace,help -n "$BASENAME" -- "$@"`

if [ $? != 0 ] ; then exit 1 ; fi

# To use getopt quoting, re-eval command line args.
eval set -- "$GETOPTARGS"

while true ; do
	case "$1" in
		-h|--help) echo -e $HELP; exit 0 ;;
		--show_id) SHOW_ID=$2 ; shift 2 ;;
		--foreign_key) FOREIGN_KEY=$2 ; shift 2 ;;
		--status) STATUS=$2 ; shift 2 ;;
		
		--position) POSITION=$2 ; shift 2 ;;
		--replace) REPLACE=1 ; shift ;;
		
		--) shift ; break ;;
		*) echo "$BASENAME Internal error!" >& 2 ; exit 1 ;;
	esac
done

# Check number of passed files.
if [ $# -lt 1 -o $# -gt 1 ]; then echo -e $USAGE >& 2 ; exit 1 ; fi

# Create curl option list
if [ "$FORMAT" != "" ] ;  then OPTLIST="$OPTLIST -F \"format=$FORMAT\""; fi
if [ "$API_KEY" != "" ] ; then OPTLIST="$OPTLIST -F \"api_key=$API_KEY\""; fi
if [ "$SHOW_ID" != "" ] ;  then OPTLIST="$OPTLIST -F \"show_id=$SHOW_ID\""; fi
if [ "$FOREIGN_KEY" != "" ] ;   then OPTLIST="$OPTLIST -F \"foreign_key=$FOREIGN_KEY\""; fi
if [ "$POSITION" != "" ] ; then OPTLIST="$OPTLIST -F \"positions[0]=$POSITION\""; fi
if [ "$REPLACE"  != "" ] ; then OPTLIST="$OPTLIST -F \"replace=1\""; fi

# Create the policy from expiration and api_key and base64 encode. 
EXPIRATION=$(date -d "+1 hour" -R | perl -MURI::Escape -lne 'print uri_escape($_)')

POLICY=$(echo -n "expiration=$EXPIRATION&api_key=$API_KEY" | perl -MMIME::Base64 -lne 'print encode_base64($_)')

# Create api_sig from md5 of policy and secret
API_SIG=$(echo -n $API_SECRET$POLICY | md5sum | cut -c1-32)

OPTLIST="$OPTLIST -F \"policy=$POLICY\""
OPTLIST="$OPTLIST -F \"api_sig=$API_SIG\""

# Check file is readable.
if [ ! -f $1 ] ; then echo "$1: No such file" >& 2 ; exit 1 ; fi

# Add file to curl options
FILELIST="$FILELIST -F \"files[0]=@$1\""

# Call curl
RESPONSE=$(eval $CURL $CURLOPTS $OPTLIST $FILELIST $API_URL)

# echo show_id or error.
if [ $(echo -n $RESPONSE | grep -c 'status="ok"') -eq 1 ] ; then
	echo -n $RESPONSE | grep -o -P '<show><id>[0-9]+?</id>' | grep -o -P '[0-9]+'
	exit 0
else
	echo $(echo -n $RESPONSE | grep -o -P 'message=".+?"' | sed 's/message=//' | sed 's/"//g') >& 2
	exit 1
fi

