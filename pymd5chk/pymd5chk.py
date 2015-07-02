#!/usr/bin/env python

import time
import sys
import os
import hashlib
from functools import wraps

def timeit(func):
    @wraps(func)
    def wrapper(*args, **kwargs):
        st = time.time()
	rtn = func(*args, **kwargs)
	et = time.time()
	print 'cost :%s sec' %(et-st)
	return rtn
    return wrapper

def md5chksum(filename):
    md5_rtn = ''
    with open(filename) as f:
        data = f.read()
	md5_rtn = hashlib.md5(data).hexdigest()
    print '%s <-> %s' %(md5_rtn, os.path.abspath(filename))
    return md5_rtn

@timeit
def main(argv):
    for i in xrange(1, len(sys.argv)):
        if not os.path.isdir(sys.argv[i]):
	    md5chksum(sys.argv[i])

if __name__=='__main__':
    if len(sys.argv) >= 2:
	argv = sys.argv
	main(argv)
    else:
	print 'python %s file_1 file_2...file_n' %sys.argv[0]
