
proc xml2list xml {
    regsub -all {>\s*<} [string trim $xml " \n\t<>"] "\} \{" xml
    set xml [string map {> "\} \{#text \{" < "\}\} \{"}  $xml]

    set res ""   ;# string to collect the result
    set stack {} ;# track open tags
    set rest {}

    set xml [list {*}$xml]

}



set xml {<?xml version="1.0" encoding="utf-8"?>
<d:multistatus xmlns:d="DAV:" xmlns:s="http://sabredav.org/ns"><d:response><d:href>/dav/</d:href><d:propstat><d:prop><d:getlastmodified xmlns:b="urn:uuid:c2f41010-65b3-11d1-a29f-00aa00c14882/" b:dt="dateTime.rfc1123">Tue, 24 Jun 2014 15:55:32 GMT</d:getlastmodified><d:getcontentlength>24865142</d:getcontentlength><d:resourcetype><d:collection/></d:resourcetype><d:quota-used-bytes>24865142</d:quota-used-bytes><d:quota-available-bytes>53662226058</d:quota-available-bytes><d:creationdate xmlns:b="urn:uuid:c2f41010-65b3-11d1-a29f-00aa00c14882/" b:dt="dateTime.iso8601">2013-02-17T20:53:56Z</d:creationdate></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response><d:response><d:href>/dav/backups/</d:href><d:propstat><d:prop><d:getlastmodified xmlns:b="urn:uuid:c2f41010-65b3-11d1-a29f-00aa00c14882/" b:dt="dateTime.rfc1123">Tue, 05 Nov 2013 21:03:26 GMT</d:getlastmodified><d:getcontentlength>24864776</d:getcontentlength><d:resourcetype><d:collection/></d:resourcetype><d:quota-used-bytes>24865142</d:quota-used-bytes><d:quota-available-bytes>53662226058</d:quota-available-bytes><d:creationdate xmlns:b="urn:uuid:c2f41010-65b3-11d1-a29f-00aa00c14882/" b:dt="dateTime.iso8601">2013-05-19T22:28:31Z</d:creationdate></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response><d:response><d:href>/dav/Simple/</d:href><d:propstat><d:prop><d:getlastmodified xmlns:b="urn:uuid:c2f41010-65b3-11d1-a29f-00aa00c14882/" b:dt="dateTime.rfc1123">Fri, 29 Mar 2013 14:23:40 GMT</d:getlastmodified><d:getcontentlength>366</d:getcontentlength><d:resourcetype><d:collection/></d:resourcetype><d:quota-used-bytes>24865142</d:quota-used-bytes><d:quota-available-bytes>53662226058</d:quota-available-bytes><d:creationdate xmlns:b="urn:uuid:c2f41010-65b3-11d1-a29f-00aa00c14882/" b:dt="dateTime.iso8601">2013-03-29T14:21:59Z</d:creationdate></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response></d:multistatus>
}

puts [xml2list $xml]
