update-s3-metadata
==================

Wrapper script written in perl that uses s3cmd to update metadata for s3 objects.

I wrote this script for s3cmd v1.0.1 on CentOS 6.3

I modified s3cmd with the following in order to get headers to update when doing s3cmd cp and also to fix errors I was having when updating files that used japanese characters.


 vim /usr/bin/s3cmd
 line: 32
  reload(sys)
  sys.setdefaultencoding('utf-8')

 vim /usr/lib/python2.6/site-packages/S3/S3.py
 line: 301
                headers = SortedDict(ignore_case = True)
                content_type = None
                content_type = self.config.default_mime_type
                headers["content-type"] = content_type
 line: 303
                headers['x-amz-metadata-directive'] = "REPLACE" 
 line: 308-309
                if extra_headers:
                        headers.update(extra_headers)
