<?php
#
# A simple proxy script to avoid strange Permissions
#
Header("Content-type: text/plain");

/*
 * Send error messages
 */
function sendresp($code,$msg="") {
  header($_SERVER["SERVER_PROTOCOL"].' '.$code.' '.$msg);
  echo "\n";
  echo "ABORT with ERROR: $code\n\n\t$msg";
  exit();
}

if (!isset($_SERVER['PATH_INFO'])) sendresp(403,'Forbidden: missing path');

$path = '.'.$_SERVER['PATH_INFO'];

if (strpos($path,'/..')) sendresp(403,"Forbidden: $path");
if (!is_file($path)) sendresp(404,"Not found: $path");
if (is_link($path)) sendresp(403,"Invalid symlink: $path");
readfile($path);
?>
