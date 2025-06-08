#!/bin/sh
# $Id$
# $Log$

TMP=/tmp/debug-cgi.$$

echo Content-type: text/plain
echo

echo set env PATH_INFO "$PATH_INFO"
echo set env PATH_TRANSLATED "$PATH_TRANSLATED"
echo set env QUERY_STRING ="$QUERY_STRING"
if [ "$CONTENT_LENGTH" != "" ] ; then echo set env CONTENT_LENGTH "$CONTENT_LENGTH" ; fi
if [ "$CONTENT_TYPE" != "" ] ; then echo set env CONTENT_TYPE "$CONTENT_TYPE" ; fi
if [ "$DOCUMENT_ROOT" != "" ] ; then echo set env DOCUMENT_ROOT "$DOCUMENT_ROOT" ; fi
if [ "$SERVER_NAME" != "" ] ; then echo set env SERVER_NAME "$SERVER_NAME" ; fi
if [ "$SERVER_URL" != "" ] ; then echo set env SERVER_URL "$SERVER_URL" ; fi
if [ "$SERVER_PORT" != "" ] ; then echo set env SERVER_PORT "$SERVER_PORT" ; fi
if [ "$HTTP_COOKIE" != "" ] ; then echo set env HTTP_COOKIE "$HTTP_COOKIE" ; fi
if [ "$HTTPS" != "" ] ; then echo set env HTTPS "$HTTPS" ; fi
if [ "$HTTP_HOST" != "" ] ; then echo set env HTTP_HOST "$HTTP_HOST" ; fi
if [ "$REMOTE_ADDR" != "" ] ; then echo set env REMOTE_ADDR "$REMOTE_ADDR" ; fi
if [ "$HTTP_USER_AGENT" != "" ] ; then echo set env HTTP_USER_AGENT "$HTTP_USER_AGENT" ; fi
#if [ "$HTTP_ACCEPT_ENCODING" != "" ] ; then echo set env HTTP_ACCEPT_ENCODING "$HTTP_ACCEPT_ENCODING" ; fi
if [ "$REQUEST_METHOD" != "" ] ; then echo set env REQUEST_METHOD "$REQUEST_METHOD" ; fi
if [ "$SCRIPT_FILENAME" != "" ] ; then echo set env SCRIPT_FILENAME "$SCRIPT_FILENAME" ; fi
if [ "$REDIRECT_SCRIPT_URL" != "" ] ; then echo set env REDIRECT_SCRIPT_URL "$REDIRECT_SCRIPT_URL" ; fi
if [ "$REDIRECT_STATUS" != "" ] ; then echo set env REDIRECT_STATUS "$REDIRECT_STATUS" ; fi
echo set env SCRIPT_NAME "$SCRIPT_NAME"

if [ "$CONTENT_LENGTH" != "" ] ; then
    touch $TMP 2>&1
    dd ibs=1 count=$CONTENT_LENGTH of=$TMP 2>/dev/null
    echo set args '<' $TMP
fi

echo ''
