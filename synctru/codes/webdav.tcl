#!/usr/bin/tclsh

package require http
package require tls
package require base64

http::register https 443 [list ::tls::socket \
			      -cadir /usr/share/ca-certificates/mozilla ]

set user "alejandro_liu@yahoo.com"
set passwd "E4n8CtcZ3OJX"

set dirurl "https://dav.box.com/dav/"
set exHdrLst [list Authorization \
		  [list Basic [base64::encode ${user}:${passwd}]]]

#set tok [::http::geturl $dirurl -headers $exHdrLst -validate 1]
#parray $tok
#http::cleanup $tok

set tok [::http::geturl ${dirurl} \
	     -method PROPFIND \
	     -headers [concat $exHdrLst [list Depth 1]]]
parray $tok
http::cleanup $tok
