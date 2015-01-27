#!/usr/bin/env python
# -*- coding: utf-8 -*-
######################################################
## @Copyright Copyright(c) 2012-2014
## @Company Hangzhou Pantuo Sci&Tech Inc.
## @Author  Qiujie Yao <yaoqiujie@gmail.com>
## @Date  2013-02-18
##
## Listen to all the TDFis and handle the events 
## received from them
######################################################

import struct
import uuid
import gevent
from gevent import socket
from gevent.server import DatagramServer
from gevent import monkey
monkey.patch_all(thread=False)

def hex_str(s):
	return ":".join("{:02x}".format(ord(c)) for c in s)

def ip2int(addr):
	return struct.unpack("!I", socket.inet_aton(addr))[0]

def int2ip(addr):
	return socket.inet_ntoa(struct.pack("!I", addr))

def genChallenge():
	challenge = ''.join(str(uuid.uuid4()).split('-'))
	return challenge[:16]

class ACSimulator(DatagramServer):
	def handle(self, data, address):
		print "Received MSG[%s] from [%s]" %(hex_str(data), address[0])

		## Start to handle the requests from portal
		ver, req_type, chap, rsv, serial_no, req_id = struct.unpack("!BBBBHH", data[:8])
		user_ip, user_port, err_code, attr_num = struct.unpack("!IHBB", data[8:16])
		#print "%d, %d, %s, %d" %(ack_type, serial_no, int2ip(user_ip), attr_num)

		if req_type == 0x01: # REQ_CHALLENGE
			chall = genChallenge()
			req_id = 0x1234
			print "Received REQ_CHALLENGE request"
			print "REQ_ID:[%d], CHALLENGE:[%s]" %(req_id, chall)
			ack_chall = struct.pack("!BBBBHHIHBBBB16s", 0x01, 0x02, 0, 0, serial_no, req_id, user_ip, 0, 0, 1, 0x03, 0x12, chall)
			self.socket.sendto(ack_chall, address)
		elif req_type ==  0x03: # REQ_AUTH
			print "Received REQ_AUTH request"

			tlvs = data[16:]
			while tlvs:
				t, l = struct.unpack("!BB", tlvs[:2])
				v = struct.unpack("!%ds" %(l-2), tlvs[2:l])
				print "Type:[%d], Length:[%d], value:[%s]" %(t, l, v)
				tlvs = tlvs[l:]

			ack_auth = struct.pack("!BBBBHHIHBB", 0x01, 0x04, 0, 0, serial_no, req_id, user_ip, 0, 0, 0)
			self.socket.sendto(ack_auth, address)
		elif req_type == 0x07: # AFF_ACK_AUTH
			print "Received AFF_ACK_AUTH"
			
		
if __name__ == '__main__':
	address = ('', 2000)
	sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
	sock.settimeout(10)
	sock.bind(address)

	print "ACSimulator is going to be started!!"
	ACSimulator(sock).serve_forever()
