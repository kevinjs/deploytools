#!/usr/bin/env python
#coding=utf-8
#Author: calvinshao
import sys
import os
import re
import getopt
import time
import subprocess
import Queue
import csv
from functools import wraps

def timeit(func):
    @wraps(func)
    def wrapper(*args, **kwargs):
        st = time.time()
        ret = func(*args, **kwargs)
        et = time.time()
        print 'cost: %s sec' %(et-st)
        return ret
    return wrapper

def run_by_expect():
    pass

def send_by_expect():
    pass

def run_by_sshpass():
    pass

def send_by_sshpass(addr, port, src, dst, acc, pwd):
    output = ''
    shell_input = 'sshpass -p %s scp -P %s -o LogLevel=error -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -r %s %s@%s:%s' %(pwd, port, src, acc, addr, dst)
    try:
        output = subprocess.check_output(shell_input, shell=True)
    except subprocess.CalledProcessError, err:
        print out_put
        print err.output
    


def read_hosts(hosts_file):
    hosts = []
    rex_ip_p = re.compile(r'((([1-9]?|1\d)\d|2([0-4]\d|5[0-5]))\.){3}(([1-9]?|1\d)\d|2([0-4]\d|5[0-5]))(:[0-9]+)?')
    if hosts_file and os.path.isfile(hosts_file):
        with open(hosts_file, 'r') as f:
            try:
                for ip_port, acc, pwd in csv.reader(f):
                    tmp_svr_info = {}
                    if re.search(rex_ip_p, ip_port):
                        if ':' in ip_port:
                            tmp_svr_info['ip'] = ip_port.split(':')[0]
                            tmp_svr_info['port'] = int(ip_port.split(':')[1])
                        else:
                            tmp_svr_info['ip'] = ip_port.split(':')[0]
                            tmp_svr_info['port'] = 22
                        tmp_svr_info['acc'] = acc
                        tmp_svr_info['pwd'] = pwd
                        hosts.append(tmp_svr_info)
            except ValueError:
                print 'ERROR:hosts file format'
    return hosts

@timeit
def run_batch(mode, remote_hosts_file, script_file):
    hosts = read_hosts(remote_hosts_file)


if __name__=='__main__':
    remote_hosts_file = ''
    mode = 'expect'
    script_file = ''

    opts, args = getopt.getopt(sys.argv[1:], "m:r:s:h")
    for op, value in opts:
        if op == "-m":
            mode = value
        elif op == "-r":
            remote_hosts_file = value
        elif op == "-s":
            script_file = value
        elif op == "-h":
            print 'USAGE: python %s -m mode -r remote_host_file -s script_file' %sys.argv[0]

    if mode in ['expect', 'sshpass'] \
       and remote_hosts_file \
       and script_file:
        run_batch(mode, remote_hosts_file, script_file)
    else:
        print 'USAGE: python %s -m mode -r remote_host_file -s script_file' %sys.argv[0]
        sys.exit(-1)
