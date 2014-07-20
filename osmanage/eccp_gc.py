#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2013 Jing Shao <jingshao[at]cnic[dot]cn>

import os
import os.path
import argparse
import MySQLdb
import json
from functools import wraps
import time

def timeit(func):
    @wraps(func)
    def wrapper(*args, **kwargs):
        start = time.time()
        result = func(*args, **kwargs)
        end = time.time()
        print 'cost:%s sec' %(round(end-start, 4))
        return result
    return wrapper

class Util(object):
    @staticmethod
    def print_list(objList):
        jsonDumpsIndentStr = json.dumps(objList, indent=1)
        print jsonDumpsIndentStr
    
    @staticmethod
    def writelines(filename, lines):
        try:
            write_lines = []
            f = open(filename, 'w')
            if lines:
                write_lines = [line+'\n' for line in lines]
            else:
                write_lines.append('Empty Set\n')
            write_lines.append('\nTime,%s\n' %time.strftime('%Y-%m-%d %H:%M:%S',time.localtime(time.time())))
            write_lines.append('Count,%s\n' %(len(lines)-1))
            f.writelines(write_lines)
        except:
            print '[Error] Write file.'
        finally:
            f.close()
    
    @staticmethod
    def create_csv(filename, content):
        w_lines = []
        if filename:
            for line in content:
                w_lines.append(','.join(str(x) for x in line))
            Util.writelines(filename, w_lines)
            print 'Create report: %s' %filename
        else:
            print '[Error] No filename input.'
            return False

class Check(object):
    #Base check function
    @staticmethod
    def check(conn, key, sql):
        rtn = []
        cur = None
        cur = conn.cursor()
        cur.execute(sql)
        for row in cur.fetchall():
            if len(key) == len(row):
                tmp = dict(zip(key, row))
                rtn.append(tmp)
            else:
                print '[Error] Column number of key and result is not match.'
                cur.close()
                return None
        cur.close()
        return rtn
    
    # Check deleted instances
    @staticmethod
    def check_del(conn):
        sql = 'select id, uuid, deleted from nova.instances where deleted = 1'
        key = ['id', 'uuid', 'del']
        del_instances_info = Check.check(conn, key, sql)
        if del_instances_info:
            del_instances_id = []
            for item in del_instances_info:
                del_instances_id.append(item['uuid'])
            return del_instances_info, del_instances_id
        else:
            return None, None

    @staticmethod
    def fetch_instance(conn, uuid):
        sql = "select id, uuid, deleted, host from nova.instances where uuid='%s'" % uuid
        key = ['id', 'uuid', 'del', 'host']
        instance_info = Check.check(conn, key, sql)
        return instance_info
    
    # Check deleted instances without release fixed ip
    @staticmethod
    def check_fixed_ip(conn):
        sql = 'select instances.id as ins_id, instances.uuid as ins_uuid, instances.deleted, fixed_ips.id as fixed_ip_id, fixed_ips.address, fixed_ips.virtual_interface_id from nova.instances, nova.fixed_ips where instances.uuid = fixed_ips.instance_uuid and instances.deleted = 1'
        key = ['ins_id', 'ins_uuid', 'del', 'fixed_ip_id', 'address', 'v_ifce_id']
        fixed_ip_abnormal_info = Check.check(conn, key, sql)
    
        if fixed_ip_abnormal_info:
            fixed_ip_abnormal_id = []
            for item in fixed_ip_abnormal_info:
                fixed_ip_abnormal_id.append(item['ins_uuid'])
            return fixed_ip_abnormal_info, fixed_ip_abnormal_id
        else:
            return None, None
    
    # Check deleted instances without release floating ip
    @staticmethod
    def check_floating_ip(conn):
        sql = 'select instances.id, instances.uuid, instances.deleted, fixed_ips.id, fixed_ips.address, floating_ips.id, floating_ips.address, fixed_ips.virtual_interface_id from nova.instances, nova.fixed_ips, nova.floating_ips where instances.deleted = 1 and fixed_ips.instance_uuid = instances.uuid and fixed_ips.id = floating_ips.fixed_ip_id'
        key = ['ins_id', 'ins_uuid', 'del', 'fixed_ip_id', 'fixed_addr', 'floating_ip_id', 'floating_addr', 'v_iface_id']
        floating_ip_abnormal_info = Check.check(conn, key, sql)
    
        if floating_ip_abnormal_info:
            floating_ip_abnormal_id = []
            for item in floating_ip_abnormal_info:
                floating_ip_abnormal_id.append(item['ins_uuid'])
            return floating_ip_abnormal_info, floating_ip_abnormal_id
        else:
            return None, None
    
    # Check deleted instances without deleting image_files
    @staticmethod
    def check_image(ia):
        complete_ins = []
        complete_info = {}
        incomplete_ins = []
        
        root_path = ia.instances_dir
        for path in os.listdir(root_path):
            if path.startswith('instance-'):
                ab_path = os.path.join(root_path, path)
                try:
                    with open(os.path.join(ab_path, 'libvirt.xml')) as f:
                        for line in f:
                            if line.strip().startswith('<uuid>'):
                                complete_ins.append(line.strip().replace('<uuid>','').replace('</uuid>','').strip())
                                complete_info[line.strip().replace('<uuid>','').replace('</uuid>','').strip()] = path
                except:
                    incomplete_ins.append(path)
                    continue
    
        return complete_info, complete_ins, incomplete_ins
    
    @staticmethod
    def check_base(ia, conn):
        pass

class Process(object):
    def process_fixedip(self, ia, conn, time_str):
        info, ids = Check.check_fixed_ip(conn)
        content = []
        if info and len(info) > 1:
            content.append(info[0].keys())
            for row in info:
                content.append(row.values())
        Util.create_csv(os.path.join(ia.outdir, '%s_%s.csv'%('irfixedip',time_str)), content)

    def process_floatingip(self, ia, conn, time_str):
        info, ids = Check.check_floating_ip(conn)
        content = []
        if info and len(info) > 1:
            content.append(info[0].keys())
            for row in info:
                content.append(row.values())
        Util.create_csv(os.path.join(ia.outdir, '%s_%s.csv'%('irfloatingip',time_str)), content)

    def process_imagefile(self, ia, conn, time_str):
        # Get deleted instances
        d_info, d_ids = Check.check_del(conn)
        # Get completed image instances
        c_info, c_ids, ic_vids = Check.check_image(ia)
        # Intersection of completed image instances and deleted instances
        inter_c_d = list(set(d_ids).intersection(set(c_ids)))

        content = []
        for ins_id in inter_c_d:
            info = Check.fetch_instance(conn, ins_id)
            if len(info) == 1:
                info = info[0]
                info['path'] = os.path.join(ia.instances_dir, c_info[ins_id])
                if len(content) == 0:
                    content.append(info.keys())
                content.append(info.values())
        Util.create_csv(os.path.join(ia.outdir, '%s_%s.csv'%('irimagefiles',time_str)), content)

        content = [['incomplete_image_files'],]
        content.extend([[os.path.join(ia.instances_dir, path)] for path in ic_vids])
        Util.create_csv(os.path.join(ia.outdir, '%s_%s.csv'%('incompleteimagefiles',time_str)), content)

    def process_basefile(self, ia, conn, time_str):
        pass

    @timeit
    def process(self, ia, conn):
        time_str = time.strftime('%Y%m%d%H%M%S',time.localtime(time.time()))
        if ia.operation == 'fixedip':
            self.process_fixedip(ia, conn, time_str)
        elif ia.operation == 'floatingip':
            self.process_floatingip(ia, conn, time_str)
        elif ia.operation == 'imagefile':
            self.process_imagefile(ia, conn, time_str)
        elif ia.operation == 'basefile':
            pass
        elif ia.operation == 'all':
            self.process_fixedip(ia, conn, time_str)
            self.process_floatingip(ia, conn, time_str)
            self.process_imagefile(ia, conn, time_str)

if __name__=='__main__':
    parser = argparse.ArgumentParser(description='OpenStack GC by kevin.')
    subparsers = parser.add_subparsers(help='commands')

    parser.add_argument('-m', action='store', dest='mysql_host')
    parser.add_argument('-u', action='store', dest='user')
    parser.add_argument('-p', action='store', dest='passwd')
    parser.add_argument('-d', action='store', dest='instances_dir')
    parser.add_argument('-o', action='store', dest='outdir')

    fixed_ip_p = subparsers.add_parser('fixedip', help='Check irregular fixed_ip.')
    fixed_ip_p.set_defaults(operation='fixedip')
    floating_ip_p = subparsers.add_parser('floatingip', help='Check irregular floating_ip.')
    floating_ip_p.set_defaults(operation='floatingip')
    imagefile_p = subparsers.add_parser('imagefile', help='Check irregular image file.')
    imagefile_p.set_defaults(operation='imagefile')
    basefile_p = subparsers.add_parser('basefile', help='Check irregular base image file.')
    basefile_p.set_defaults(operation='basefile')
    all_p = subparsers.add_parser('all', help='Check all irregular.')
    all_p.set_defaults(operation='all')

    ia = parser.parse_args()
    conn = None
    try:
        conn = MySQLdb.connect(host=ia.mysql_host, user=ia.user, passwd=ia.passwd, port=3306)
        Process().process(ia, conn)
    except MySQLdb.Error, e:
        print "Mysql Error %d: %s" % (e.args[0], e.args[1])
    finally:
        conn.close()
