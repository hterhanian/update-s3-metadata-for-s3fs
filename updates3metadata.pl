#!/usr/bin/perl
use warnings;
use strict;

##########################################################
#Global Vars
##########################################################
my $BUCKETREGEX = 'cld-dev-user-image';
my $MIMETYPEFILE = '/etc/mime.types';
my $DRYRUN ='FALSE';

my @BUCKETS;
my @FOLDERS;
my @OBJECTS;
my @FOLDEROBJECTS;

##########################################################
#Main
##########################################################

#Create list of buckets if regex matches $BUCKETREGEX
open(S3,'s3cmd ls |');
while(<S3>){
  chomp;

  if ( $_ =~ m/$BUCKETREGEX/ {
    if ( $_ =~ m/^.*s3:\/\/(.*)$/ ){
      push(@BUCKETS, $1);
    }
  }
}
close(S3);

#Iterate items in @BUCKETS and create object list for bucket recursively
foreach my $bucket (@BUCKETS){
  &checkdir($bucket)
}

#Fix Folders - This add's an empty file object to s3 for s3 folder. Used by S3FS.
foreach my $folder (@FOLDERS){
  my $path;
  my $name;

  if ( $folder =~ m/(.*)\/([^\/]+)$/gi ){
    $path = $1;
    $name = $2;
  }

  #Create folder object
  `touch '/tmp/$name'`;

  #Upload folder object
  if ( $DRYRUN eq 'FALSE' ){
    print "Updating folder object $folder\n";
    `s3cmd --acl-private --mime-type='application/x-directory' --add-header='x-amz-meta-mode:16893' --add-header='x-amz-meta-uid:2007' --add-header='x-amz-meta-gid:2007' put '/tmp/$name' 's3://$folder'`;
  }else{
    print "s3cmd --acl-private --mime-type='application/x-directory' --add-header='x-amz-meta-mode:16893' --add-header='x-amz-meta-uid:2007' --add-header='x-amz-meta-gid:2007' put '/tmp/$name' 's3://$folder'\n";
  }

  #Delete folder object
  `rm -f '/tmp/$name'`;
}

#Fix Objects - Updates object metadata, mode,uid,gid is used by S3FS
foreach my $object (@OBJECTS){
  my $mimetype;

  if ( $DRYRUN ne 'FALSE' ) { print "$object\n"; }

  if ( $object =~ m/\.(\w{3,4})$/ ){
    $mimetype = &mimetype($1);
    if ( $DRYRUN ne 'FALSE' ) {print "MIMETYPE: $mimetype\n";}
  }
  chomp($mimetype);
  if ( $DRYRUN eq 'FALSE' ){
    print "Updating object $object\n";
    `s3cmd --acl-private --mime-type=$mimetype --add-header=x-amz-meta-mode:33188 --add-header=x-amz-meta-uid:2007 --add-header=x-amz-meta-gid:2007 --add-header=x-amz-server-side-encryption:AES256 --add-header=x-amz-storage-class:STANDARD cp 's3://$object' 's3://$object'`;
  }else{
    print "s3cmd --acl-private --mime-type=$mimetype --add-header=x-amz-meta-mode:33188 --add-header=x-amz-meta-uid:2007 --add-header=x-amz-meta-gid:2007 --add-header=x-amz-server-side-encryption:AES256 --add-header=x-amz-storage-class:STANDARD cp 's3://$object' 's3://$object'\n";
  }
}

#Delete folder objects with no S3 folder
my @names;
foreach my $folderobject (@FOLDEROBJECTS){
  my $name;
  my $match=0;

  if ( $DRYRUN ne 'FALSE' ){ print "FOLDEROBJECT: $folderobject\n"; }

  if ( $folderobject =~ m/(.*)\/$/gi ){
    $name = $1;
  }else{
    $name = $folderobject;
  }

  if ( $DRYRUN ne 'FALSE' ){ print "FOLDEROBJECT REGEX: $name\n"; }


  foreach my $folder (@FOLDERS){
    my $folderfix;

    if ( $folder =~ m/(.*)\/?$/ ){
      $folderfix = $1;
    }

    if ( $name eq $folderfix ){
      $match += 1;
    }else{
      next;
    }
  }

  if ( $match == 0 ){
    push(@names, $name);
  }
}

foreach my $name (@names){
  if ( $DRYRUN eq 'FALSE' ){
    print "Deleting $name\n";
    `s3cmd del s3://$name`;
  }else{
    print "s3cmd del s3://$name\n";
  }
}

##########################################################
#Functions
##########################################################

#Search through bucket and generate folder/object list
sub checkdir {
  my $dir = $_[0];
  my @lines = `s3cmd ls 's3://$dir/'`;

  while (my $folder = shift @lines) {
    chomp($folder);
    if ( $folder =~ m/DIR\s+s3:\/\/($dir\/.*)\//gi ){
      if ( $DRYRUN ne 'FALSE' ) {print "FOLDER: $1\n";}
      push(@FOLDERS, $1);
      checkdir($1);
    }elsif ( $folder =~ m/s3:\/\/($dir\/.*\.\w{3,4}$)/gi ){
      push(@OBJECTS, $1);
      if ( $DRYRUN ne 'FALSE' ) {print "OBJECT: $1\n";}
    }elsif ( $folder =~ m/0\s+s3:\/\/($dir\/.*)/gi ){
      push(@FOLDEROBJECTS, $1);
      if ( $DRYRUN ne 'FALSE' ) {print "FOLDEROBJECT: $1\n";}
    }
  }
}

#Return mimetype based on file extension
sub mimetype {
  my $extension = lc($_[0]);

  if ( $DRYRUN ne 'FALSE' ) {print "EXTENSION=$extension\n";}

  if ( $extension eq 'jpg' or $extension eq 'jpeg' ){
    return 'image/jpeg';
  }
  if ( $extension eq 'mp4' ){
    return 'video/mp4';
  }
  if ( $extension eq 'm4a' or $extension eq 'mp4a' ){
    return 'audio/mp4';
  }
  if ( $extension eq 'mp3' ){
    return 'audio/mpeg';
  }
  if ( $extension eq 'wmv' ){
    return 'video/x-ms-wmv';
  }
  if ( $extension eq 'png' ){
    return 'image/png';
  }
  if ( $extension eq 'gif' ){
    return 'image/gif';
  }
  if ( $extension eq 'avi'){
    return 'video/x-msvideo';
  }
  if ( $extension eq 'flv' ){
    return 'video/x-flv';
  }
  if ( $extension eq 'mov' or $extension eq 'qt' ){
    return 'video/quicktime';
  }

  open(FH,$MIMETYPEFILE);
  while (<FH>){
    if ( $_ =~ m/^(.*)\t+$extension/gi ){
      return $1;
    }
  }

  if ( $DRYRUN ne 'FALSE' ) {print "No matches, using default mimetype\n";}
  return 'binary/octet-stream';
}
