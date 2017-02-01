#!/usr/bin/php
<?php
//
// Generate File distribution index
//
define('INDEX_FILE','.fdist.idx');

if (!isset($argv[1])) die("No directory specified\n");
$repodir= $argv[1];
if (!is_dir($repodir)) die("$repodir: not found\n");

$perms = array();
$dirs = array('');
$start = microtime(true);

while (count($dirs)) {
  $d = array_shift($dirs);
  set_time_limit(30);	// Reset execution timer
  echo "# $d\n";

  if ($d == '') {
    $d_path = $repodir;
  } else {
    $d_path = $repodir . '/' . $d;
  }

  $dh = @opendir($d_path) or die("could not open directory: $d");
  while (false !== ($f = readdir($dh))) {
    if ($f == "." || $f == ".." || $f == INDEX_FILE) continue;
    if ($f == "perms.txt") {
      if ($pf = @fopen($d_path.'/perms.txt','r')) {
	while (($buf = fgets($pf)) !== false) {
	  $buf = preg_split('/\s+/',trim($buf));
	  $fn = array_shift($buf);
	  if ($d != '') {
	    $fn = $d .'/'.$fn;
	  }
	  $perms[$fn] = array();
	  foreach ($buf as $atpair) {
	    list($k,$v) = explode('=',$atpair,2);
	    $perms[$fn][$k] = $v;
	  }
	}
	fclose($pf);
      }
      continue;
    }

    //
    // Pattern filters...
    //
    if (preg_match('/~$/',$f)) continue;
    if (preg_match('/\s/',$f)) continue;
    if (preg_match('/#/',$f)) continue;
    if ($d == '' && $f == 'pkgs') continue; // This shouldn't be there!

    if ($d == '') {
      $fn = $f;
    } else {
      $fn = $d.'/'.$f;
    }
    $fpath = $d_path.'/'.$f;
	
    // Ignore any special files
    $type = filetype($fpath);
    if ($type != 'link' && $type != 'dir' && $type != 'file') continue;
	  
    $stat = lstat($fpath) or fatal_err("Unable to stat: $fpath");
    $meta = array(
		  'type' => substr($type,0,1),
		  'mtime' => $stat['mtime'],
		  'uid' => 0, // $stat['uid'],
		  'gid' => 0, // $stat['gid'],
		  'mode' => sprintf("%03o",$stat['mode'] & 07777),
		  'md5' => '-',
		  'size' => 0

		  );
    if ($type == 'link') {
      $meta['md5'] = readlink($fpath);
    } elseif ($type == 'dir') {
      array_push($dirs,$fn);
    } else { // $type == 'file'
      $meta['size'] = $stat['size'];
      if (isset($dat[$fn])) {
	if ($dat[$fn]['type'] == $meta['type'] 
	    && $dat[$fn]['size'] == $meta['size']
	    && $dat[$fn]['mtime'] == $meta['mtime']) {
	  $meta['md5'] = $dat[$fn]['md5'];
	}
      }
      if ($meta['md5'] == '-') {
	set_time_limit(30);	// Reset execution timer
	echo "# CKSUM' $fpath - ";
	$begin = microtime(true);
	$meta['md5'] = md5_file($fpath);
	echo $meta['md5'].' '.(microtime(true)-$begin)." secs\n";
      }
    }
    $dat[$fn] = $meta;
  }
}

// Apply overrides...
foreach ($perms as $fn => &$meta) {
  if (!isset($dat[$fn])) continue;
  foreach ($meta as $k => $v) {
    $dat[$fn][$k] = $v;
  }
}


//
// Dump the manifest
//
$fp = fopen($repodir.'/'.INDEX_FILE,'w');
if (!$fp) die("Unable to open INDEX_FILE\n");

foreach ($dat as $fn => &$meta) {
  $ln = array($meta['type'],$fn);
  foreach (array('md5','mode','uid','gid','size','mtime') as $at) {
    array_push($ln,$meta[$at]);
  }
  fwrite($fp,implode(' ',$ln)."\n");
}
fclose($fp);

echo "# RUNTIME: ".(microtime(true)-$start)." secs\n";
?>
