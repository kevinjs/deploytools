#!/usr/bin/env python
#coding=utf-8
#Author: calvinshao
import sys
import os
import re
import string
import getopt
import time
import subprocess
import threading
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

def filter_output(output, keywords):
    def _inner_filter(str_t):
        t = [kw for kw in keywords if kw in str_t]
        if t:
            return True
        else:
            return False
    return filter(_inner_filter, map(lambda out_str:string.strip(out_str), string.split(output, '\n')))

def get_script_path(src, dst):
    script_path = ''
    if '/' in src:
        script_path = src[src.rindex('/')+1:]
    else:
        script_path = src

    if dst[-1] == '/':
        script_path = '%s%s' %(dst, script_path)
    else:
        script_path = '%s/%s' %(dst, script_path)
    return script_path

def run_by_expect(host, src, dst, kwds):
    script_path = get_script_path(src, dst)
    shell_input = './run_command.exp %s %s %s %s %s' %(host['ip'], host['port'], script_path, host['acc'], host['pwd'])
    p = subprocess.Popen(shell_input, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    stdout, stderr = p.communicate()
    return filter_output(stdout, kwds)

def send_by_expect(host, src, dst):
    shell_input = './send_file.exp %s %s %s %s %s %s' %(src, host['ip'], host['port'], host['acc'], host['pwd'], dst)
    p = subprocess.Popen(shell_input, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    try:
        stdout, stderr = p.communicate(timeout=8)
    except subprocess.TimeoutExpired:
        return False
    if '100%' in stdout:
        return True
    else:
        return False

def send_and_run_by_expect(host, queue, src, dst='/tmp', kwds=[]):
    if send_by_expect(host, src, dst):
        output = run_by_expect(host, src, dst, kwds)
        queue.put([host['ip'], output])
    else:
        queue.put([host['ip'], []])

def run_by_sshpass():
    pass

def send_by_sshpass(host, src, dst):
    output = ''
    shell_input = 'sshpass -p %s scp -P %s -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -r %s %s@%s:%s' %(host['pwd'], host['port'], src, host['acc'], host['ip'], dst)
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
def run_batch_async(mode, remote_hosts_file, script_file):
    hosts = read_hosts(remote_hosts_file)
    queue = Queue.Queue()
    threads = []
    cnt = 0
    cnt_done = 0

    if mode == 'sshpass':
        pass
    elif mode == 'expect':
        for host in hosts:
            t = threading.Thread(target=send_and_run_by_expect, args=(host, queue, script_file, '/tmp', ['PUBLIC_IP_LIST']))
            threads.append(t)
            t.start()
            cnt += 1
        #for t in threads:
        #    t.join()
        for i in xrange(cnt):
            ret = queue.get()
            cnt_done += 1
            print ret

#@timeit
#def run_batch_sync(mode, remote_hosts_file, script_file):
#    queue =Queue.Queue()
#    hosts = read_hosts(remote_hosts_file)
#    cnt = 0
#    cnt_done = 0
#    for host in hosts:
#        print 'Start run on %s' %host['ip']
#        send_and_run_by_expect(host, queue, script_file, '/tmp', ['PUBLIC_IP_LIST'])
#        cnt += 1
#    for i in xrange(cnt):
#        ret = queue.get()
#        cnt_done += 1
#        print ret
    
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
        run_batch_async(mode, remote_hosts_file, script_file)
    else:
        print 'USAGE: python %s -m mode -r remote_host_file -s script_file' %sys.argv[0]
        sys.exit(-1)

