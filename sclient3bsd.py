#!/usr/bin/env python3
# -*- coding: utf-8 -*-

SERVER = ""
PORT = 
USER = ""
PASSWORD = ""
INTERVAL = 1 # Update interval

import socket
import time
import os
import json
import collections
import psutil

def get_uptime():
    return int(time.time() - psutil.boot_time())

def get_memory():
    memory = psutil.virtual_memory()
    try:
        memory_used = memory.used - (memory.cached + memory.free)
    except AttributeError:
        memory_used = memory.total - memory.free
    return int( memory.total / 1024 ), int( memory.used / 1024 )

def get_swap():
    memory = psutil.swap_memory()
    return int( memory.total / 1024 ), int( memory.used / 1024 )

def get_hdd():
    partitions = psutil.disk_partitions()
    total_space = 0
    used_space = 0

    for partition in partitions:
        usage = psutil.disk_usage(partition.mountpoint)
        total_space += usage.total
        used_space += usage.used

    return int(total_space / 1024 / 1024), int(used_space / 1024 / 1024)

def get_load():
    try:
        return os.getloadavg()[0]
    except:
        return -1.0

def get_cpu():
    return psutil.cpu_percent(interval=INTERVAL)

class Traffic:
    def __init__(self):
        self.rx = collections.deque(maxlen=10)
        self.tx = collections.deque(maxlen=10)
    
    def get(self):
        avgrx = 0
        avgtx = 0
        for name, stats in psutil.net_io_counters(pernic=True).items():
            if name == "lo" or "tun" in name:
                continue
            avgrx += stats.bytes_recv
            avgtx += stats.bytes_sent

        self.rx.append(avgrx)
        self.tx.append(avgtx)
        avgrx = 0
        avgtx = 0

        l = len(self.rx)
        for x in range(l - 1):
            avgrx += self.rx[x+1] - self.rx[x]
            avgtx += self.tx[x+1] - self.tx[x]

        avgrx = int(avgrx / l / INTERVAL)
        avgtx = int(avgtx / l / INTERVAL)

        return avgrx, avgtx

def get_network(ip_version):
    if ip_version == 4:
        HOST = "ipv4.google.com"
    elif ip_version == 6:
        HOST = "ipv6.google.com"
    try:
        s = socket.create_connection((HOST, 80), timeout=2)
        return True
    except:
        return False

if __name__ == '__main__':
    socket.setdefaulttimeout(30)
    while True:
        try:
            print("Connecting...")
            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            s.connect((SERVER, PORT))
            data = s.recv(1024).decode('utf-8')
            if "Authentication required" in data:
                s.sendall((USER + ':' + PASSWORD + '\n').encode('utf-8'))
                data = s.recv(1024).decode('utf-8')
                if "Authentication successful" not in data:
                    print(data)
                    raise socket.error
            else:
                print(data)
                raise socket.error

            print(data)
            data = s.recv(1024).decode('utf-8')
            print(data)

            timer = 0
            check_ip = 0
            if "IPv4" in data:
                check_ip = 6
            elif "IPv6" in data:
                check_ip = 4
            else:
                print(data)
                raise socket.error

            traffic = Traffic()
            traffic.get()
            while True:
                CPU = get_cpu()
                NetRx, NetTx = traffic.get()
                Uptime = get_uptime()
                Load = get_load()
                MemoryTotal, MemoryUsed = get_memory()
                SwapTotal, SwapUsed = get_swap()
                HDDTotal, HDDUsed = get_hdd()

                array = {}
                if not timer:
                    array['online' + str(check_ip)] = get_network(check_ip)
                    timer = 10
                else:
                    timer -= 1 * INTERVAL

                array['uptime'] = Uptime
                array['load'] = Load
                array['memory_total'] = MemoryTotal
                array['memory_used'] = MemoryUsed
                array['swap_total'] = SwapTotal
                array['swap_used'] = SwapUsed
                array['hdd_total'] = HDDTotal
                array['hdd_used'] = HDDUsed
                array['cpu'] = CPU
                array['network_rx'] = NetRx
                array['network_tx'] = NetTx

                s.sendall(("update " + json.dumps(array) + "\n").encode('utf-8'))
        except KeyboardInterrupt:
            raise
        except socket.error:
            print("Disconnected...")
            # keep on trying after a disconnect
            s.close()
            time.sleep(3)
        except Exception as e:
            print("Caught Exception:", e)
            s.close()
            time.sleep(3)
