#!/usr/bin/env python2
#
# Copyright 2017-present Open Networking Foundation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# TODO: the whole file

import argparse
import json
import os
import sys
import time
import threading

sys.path.append("utils")
import bmv2
import helper
from convert import *

from p4.v1 import p4runtime_pb2

SUBMIT_ID = 4

def addNextToPrev(sw, helper, n, p, is_submit):
    table_entry = helper.buildTableEntry(
            table_name = "jondoIngress.nextToPrevPI",
            match_fields = { "hdr.jondo.path_id": n},
            action_name = "jondoIngress.setPathID",
            action_params = { "path_id": p,
                              "is_submit": is_submit } )
    sw.WriteTableEntry(table_entry);

def addPrevToNext(sw, helper, n, p, is_submit):
    table_entry = helper.buildTableEntry(
            table_name = "jondoIngress.prevToNextPI",
            match_fields = { "hdr.jondo.path_id": p},
            action_name = "jondoIngress.setPathID",
            action_params = { "path_id": n,
                              "is_submit": is_submit } )
    sw.WriteTableEntry(table_entry);

def addPathToJondo(sw, helper, p, j):
    table_entry = helper.buildTableEntry(
            table_name = "jondoIngress.pathIDToJondoID",
            match_fields = { "hdr.jondo.path_id": p},
            action_name = "jondoIngress.setPathID",
            action_params = { "next_id": j } )
    sw.WriteTableEntry(table_entry);

def InitializeJondoToRoute():
    #TODO maybe hardcode?
    return


def ProgramSwitch(sw, id, p4info_helper):
    
    InitializeJondoToRoute()

    digest_config = p4info_helper.buildDigestConfig("jondo_path_gen_t")

    while True:
        digest = sw.GetDigest(digest_config)
        hex_prev_path = digest.digest.data[0].struct.members[0].bitstring
        prev_path_id = decodeNum(hex_path)
        hex_path = digest.digest.data[0].struct.members[1].bitstring
        path_id = decodeNum(hex_path)
        hex_jondo = digest.digest.data[0].struct.members[2].bitstring
        jondo_id = decodeMac(hex_jondo)
        is_submit = 0
        if (path_id == SUBMIT_ID):
            is_submit = 1
        addNextToPrev(sw, p4info_helper, path_id, prev_path_id, is_submit)
        addPrevToNext(sw, p4info_helper, path_id, prev_path_id, is_submit)
        addPathToJondo(sw, p4info_helper, path_id, prev_path_id, is_submit)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='CIS553 P4Runtime Controller')

    parser.add_argument("-b", '--bmv2-json',
                        help="path to BMv2 switch description (json)",
                        type=str, action="store", default="build/jondo.json")
    parser.add_argument("-c", '--p4info-file',
                        help="path to P4Runtime protobuf description (text)",
                        type=str, action="store", default="build/jondo.p4info")

    args = parser.parse_args()

    if not os.path.exists(args.p4info_file):
        parser.error("File %s does not exist!" % args.p4info_file)
    if not os.path.exists(args.bmv2_json):
        parser.error("File %s does not exist!" % args.bmv2_json)
    p4info_helper = helper.P4InfoHelper(args.p4info_file)


    threads = []

    print "Connecting to P4Runtime server on s1..."
    sw1 = bmv2.Bmv2SwitchConnection('s1', "127.0.0.1:50051", 0)
    sw1.MasterArbitrationUpdate()
    sw1.SetForwardingPipelineConfig(p4info = p4info_helper.p4info,
                                    bmv2_json_file_path = args.bmv2_json)
    t = threading.Thread(target=ProgramSwitch, args=(sw1, 1, p4info_helper))
    t.start()
    threads.append(t)

    print "Connecting to P4Runtime server on s2..."
    sw2 = bmv2.Bmv2SwitchConnection('s2', "127.0.0.1:50052", 1)
    sw2.MasterArbitrationUpdate()
    sw2.SetForwardingPipelineConfig(p4info = p4info_helper.p4info,
                                    bmv2_json_file_path = args.bmv2_json)
    t = threading.Thread(target=ProgramSwitch, args=(sw2, 2, p4info_helper))
    t.start()
    threads.append(t)

    print "Connecting to P4Runtime server on s3..."
    sw3 = bmv2.Bmv2SwitchConnection('s3', "127.0.0.1:50053", 2)
    sw3.MasterArbitrationUpdate()
    sw3.SetForwardingPipelineConfig(p4info = p4info_helper.p4info,
                                    bmv2_json_file_path = args.bmv2_json)
    t = threading.Thread(target=ProgramSwitch, args=(sw3, 3, p4info_helper))
    t.start()
    threads.append(t)

    for t in threads:
        t.join()
