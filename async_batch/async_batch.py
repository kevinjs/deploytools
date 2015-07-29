#!/usr/bin/env python
#coding=utf-8
#Author: kevinjs
#Email: dysj4099@gmail.com

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
from multiprocessing.dummy import Pool as ThreadPool
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
    '''Filter output lines by match keywords.'''
    def _inner_filter(str_t):
        t = [kw for kw in keywords if kw in str_t]
        if t:
            return True
        else:
            return False
    if keywords:
        return filter(_inner_filter, map(lambda out_str:string.strip(out_str), string.split(output, '\n')))
    else:
        return map(lambda out_str:string.strip(out_str), string.split(output, '\n'))

def get_script_path(src, dst):
    '''Combine script path.'''
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

def read_hosts(hosts_file):
    '''Read CSV file.'''
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

def run_by_sshpass(host, src, dst, kwds):
    script_path = get_script_path(src, dst)
    shell_input = "sshpass -p %s ssh -P %s -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=3 %s@%s '%s' 2>&1" %(host['pwd'], host['port'], host['acc'], host['ip'], script_path)
    p = subprocess.Popen(shell_input, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    stdout, stderr = p.communicate()
    return filter_output(stdout, kwds)

def send_by_sshpass(host, src, dst):
    shell_input = 'sshpass -p %s scp -P %s -o LogLevel=error -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -r %s %s@%s:%s' %(host['pwd'], host['port'], src, host['acc'], host['ip'], dst)
    p = subprocess.Popen(shell_input, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    try:
        stdout, stderr = p.communicate(timeout=10)
    except subprocess.TimeoutExpired:
        return False

    if 'lost connection' in stdout or 'Permission denied' in stdout:
        return False
    else:
        return True

ctrl_mode = {'send_by_expect':send_by_expect,
             'send_by_sshpass':send_by_sshpass,
             'run_by_expect':run_by_expect,
             'run_by_sshpass':run_by_sshpass}

def send_and_run(param_unit):
    if param_unit:
        host = param_unit['host']
        queue = param_unit['queue']
        src = param_unit['src']
        dst = param_unit['dst']
        kwds = param_unit['kwds']
        mode = param_unit['mode']

        if ctrl_mode.get('send_by_%s' %mode)(host, src, dst):
            output = ctrl_mode.get('run_by_%s' %mode)(host, src, dst, kwds)
            queue.put([host['ip'], output])
        else:
            queue.put([host['ip'], ['empty_line']])

@timeit
def run_batch_async(mode, remote_hosts_file, script_file):
    hosts = read_hosts(remote_hosts_file)
    queue = Queue.Queue()
    pool = ThreadPool()
    param_units = []

    for host in hosts:
        tmp = {}
        tmp['host'] = host
        tmp['queue'] = queue
        tmp['src'] = script_file
        tmp['mode'] = mode
        tmp['dst'] = '/tmp'
        # put filter keywords of output here
        tmp['kwds'] = []
        param_units.append(tmp)

    # Implement switch case by hash (dict)
    pool.map(send_and_run, param_units)
    pool.close()
    pool.join()

    for i in xrange(len(hosts)):
        ret = queue.get()
        print 'Run on %s' %ret[0]
        print 'Last output %s' %ret[1][-1]

@timeit
def run_batch_sync(mode, remote_hosts_file, script_file):
    queue =Queue.Queue()
    hosts = read_hosts(remote_hosts_file)
    cnt = 0

    for host in hosts:
        param_unit = {}
        param_unit['host'] = host
        param_unit['queue'] = queue
        param_unit['src'] = script_file
        param_unit['mode'] = mode
        param_unit['dst'] = '/tmp'
        # put filter keywords of output here
        param_unit['kwds'] = []

        send_and_run(param_unit)
        cnt += 1
    for i in xrange(cnt):
        ret = queue.get()
        print 'Run on %s' %ret[0]
        print 'Last output %s' %ret[1][-1]

async_mode = {'run_batch_async':run_batch_async,
              'run_batch_sync':run_batch_sync}

if __name__=='__main__':
    remote_hosts_file = ''
    mode = 'expect'
    a_mode = 'async'
    script_file = ''

    opts, args = getopt.getopt(sys.argv[1:], "m:r:s:a:h")
    for op, value in opts:
        if op == "-m":
            mode = value
        elif op == "-r":
            remote_hosts_file = value
        elif op == "-s":
            script_file = value
        elif op == "-a":
            a_mode = value
        elif op == "-h":
            print 'USAGE: python %s -m mode -r remote_host_file -s script_file -a async_mode' %sys.argv[0]

    if mode in ['expect', 'sshpass'] \
            and remote_hosts_file \
            and script_file:
        #run_batch_async(mode, remote_hosts_file, script_file)
        async_mode.get('run_batch_%s' %a_mode)(mode, remote_hosts_file, script_file)
    else:
        print 'USAGE: python %s -m mode -r remote_host_file -s script_file -a async_mode' %sys.argv[0]
        sys.exit(-1)
