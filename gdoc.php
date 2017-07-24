#!/usr/bin/env php
<?php
/** Path to proxy script */
define('CMD',array_shift($argv));
/** Basic command name */
define('CMDNAME',basename(CMD,'.php'));
error_reporting(E_ALL);

$entries = [];

function process_file($f) {
  $php = file_get_contents($f);
  if ($php === FALSE) die($f.': Not found'.PHP_EOL);
  $off = 0;
  while (preg_match('/\/\*\*\s*/',$php,$mv,PREG_OFFSET_CAPTURE,$off)) {
    $start = $off = $mv[0][1]+strlen($mv[0][0]);
    if (!preg_match('/\*\//',$php,$mv,PREG_OFFSET_CAPTURE,$off)) break;
    $off = $mv[0][1]+strlen($mv[0][0]);
    
    $entry = '';
    foreach (explode("\n",substr($php,$start,$mv[0][1] - $start)) as $ln) {
      $ln = preg_replace('/^\s*\* *(\s?)/','$1',rtrim($ln));
      $entry .= $ln .PHP_EOL;
    }
    if (preg_match('/\/\*\*\s*/',$php,$mv,PREG_OFFSET_CAPTURE,$off)) {
      $tail = substr($php,$off,$mv[0][1]-$off);
      $off = $mv[0][1];
    } else {
      $tail = substr($php,$off);
    }
    $tail = explode("\n",trim($tail));
    $tail = trim($tail[0]);
    if ($tail{strlen($tail)-1} == '{') $tail = trim(substr($tail,0,strlen($tail)-1));
    
    $entries[$tail] = $entry;
  }

  print_r($entries);
}


foreach ($argv as $f) {
  process_file($f);
}

