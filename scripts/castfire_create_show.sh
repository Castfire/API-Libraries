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
# castfire_create_show.sh
# http://www.castfire.com/
# Version 1.2 2008-03-21
#
# To run this script the following commands need to be installed:
# 1. curl                 http://curl.haxx.se/
# 2. getopt (enhanced)    http://software.frodo.looijaard.name/getopt/
# 3. perl URI::Escape     perl -MCPAN -e 'install URI::Escape'
# 4. perl MIME::Base64    perl -MCPAN -e 'install MIME::Base64'
#
# This script creates a new Castfire show by POSTing the media files to the
# castfire API. The show's id is returned on success. The error message printed
# on failure. 
# NOTE: A maximum of 9 media files can make up a show.

# -----------------------------------------------------------------------------
# CHANGE THESE
#
# These two API values are REQUIRED. Enter your values:
API_KEY=11111-22222-33333
API_SECRET=AbcdefgHijklmnoP

# These values are optional. If a value is assigned then it is used as the
# default and doesn't need to be passed on the command line.
# NOTE: channel_id, name, status are all *required* by the api.
CHANNEL_ID=
NAME=
STATUS=
FILENAME=
DATETIME_PUBLISHED=
TAGS=
PERMALINK=

# These values probably don't need to be changed.
API_URL=http://api.castfire.com/upload/show/
FORMAT=xml

CURL=/usr/bin/curl
CURLOPTS="--silent"

# -----------------------------------------------------------------------------

# Start of the script
BASENAME=`basename $0`

BASEUSAGE="Usage: $BASENAME [options] filename [filename2 ... filename9]"

USAGE="$BASEUSAGE\nTry '$BASENAME --help' for more information."

HELP="$BASEUSAGE\nPOST a show to the Castfire server using the api.\n
\nExample: $BASENAME --channel_id=9999 --name=\"Test Show\" --status=draft part1.mov part2.mov part3.mov
\n\nOptions:
\n\t-h, --help \t\tDisplay this help and exit.
\n\t--channel_id=NUMBER \tThe channel id.
\n\t--name=NAME \t\tThe name of the show.
\n\t--status=STATUS \tThe status of the show. [published|draft|auto-publish|expired]
\n\t--filename=NAME \tThe filename of the show. A timestamp will be appended.
\n\t--tags=URL \t\tA comma delimited list of tags [tag1,tag2,tag3,...].
\n\t--permalink=URL \tThe URL of the original page containing the show.
\n\t--datetime_published=DATETIME \tThe published date and time of a show in any valid format.
\n"

# Parse the command line arguments using getopt. Add new args here.
GETOPTARGS=`getopt -o h --longoptions channel_id:,name:,status:,filename:,datetime_published:,tags:,permalink:,help -n "$BASENAME" -- "$@"`

if [ $? != 0 ] ; then exit 1 ; fi

# To use getopt quoting, re-eval command line args.
eval set -- "$GETOPTARGS"

while true ; do
	case "$1" in
		-h|--help) echo -e $HELP; exit 0 ;;
		--channel_id) CHANNEL_ID=$2 ; shift 2 ;;
		--name) NAME=$2 ; shift 2 ;;
		--status) STATUS=$2 ; shift 2 ;;
		
		--filename) FILENAME=$2 ; shift 2 ;;
		--datetime_published) DATETIME_PUBLISHED=$2 ; shift 2 ;;
		--permalink) PERMALINK=$2 ; shift 2 ;;
		--tags) TAGS=$2 ; shift 2 ;;
		
		--) shift ; break ;;
		*) echo "$BASENAME Internal error!" >& 2 ; exit 1 ;;
	esac
done

# Check number of passed files.
if [ $# -lt 1 -o $# -gt 9 ]; then echo -e $USAGE >& 2 ; exit 1 ; fi

# Create curl option list
if [ "$FORMAT" != "" ] ;  then OPTLIST="$OPTLIST -F \"format=$FORMAT\""; fi
if [ "$API_KEY" != "" ] ; then OPTLIST="$OPTLIST -F \"api_key=$API_KEY\""; fi
if [ "$CHANNEL_ID" != "" ] ;  then OPTLIST="$OPTLIST -F \"channel_id=$CHANNEL_ID\""; fi
if [ "$NAME" != "" ] ;   then OPTLIST="$OPTLIST -F \"name=$NAME\""; fi
if [ "$STATUS" != "" ] ; then OPTLIST="$OPTLIST -F \"status=$STATUS\""; fi
if [ "$FILENAME"  != "" ] ; then OPTLIST="$OPTLIST -F \"filename=$FILENAME\""; fi
if [ "$DATETIME_PUBLISHED" != "" ] ; then OPTLIST="$OPTLIST -F \"datetime_published=$DATETIME_PUBLISHED\""; fi
if [ "$TAGS" != "" ] ; then OPTLIST="$OPTLIST -F \"tags=$TAGS\""; fi
if [ "$PERMALINK" != "" ] ; then OPTLIST="$OPTLIST -F \"permalink=$PERMALINK\""; fi

# Create the policy from expiration and api_key and base64 encode. 
EXPIRATION=$(date -d "+1 hour" -R | perl -MURI::Escape -lne 'print uri_escape($_)')

POLICY=$(echo -n "expiration=$EXPIRATION&api_key=$API_KEY" | perl -MMIME::Base64 -lne 'print encode_base64($_)')

# Create api_sig from md5 of policy and secret
API_SIG=$(echo -n $API_SECRET$POLICY | md5sum | cut -c1-32)

OPTLIST="$OPTLIST -F \"policy=$POLICY\""
OPTLIST="$OPTLIST -F \"api_sig=$API_SIG\""

# Create curl filelist
K=1
while [ "$#" -gt 0 ] ; do

	# Check file is readable.
	if [ ! -f $1 ] ; then echo "$1: No such file" >& 2 ; exit 1 ; fi
	
	# Add to curl options
	FILELIST="$FILELIST -F \"files[$K]=@$1\""
	K=$(($K + 1))
	shift
done

# Call curl
RESPONSE=$(eval $CURL $CURLOPTS $OPTLIST $FILELIST $API_URL)

# echo show_id or error.
if [ $(echo -n $RESPONSE | grep -c 'status="ok"') -eq 1 ] ; then
	echo -n $RESPONSE | grep -o -P '[0-9]+'
	exit 0
else
	echo $(echo -n $RESPONSE | grep -o -P 'message=".+?"' | sed 's/message=//' | sed 's/"//g') >& 2
	exit 1
fi

