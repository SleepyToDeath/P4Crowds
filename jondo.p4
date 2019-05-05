/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>


typedef bit<32> ip4Addr_t;
typedef bit<48> macAddr_t;
typedef bit<9>  portId_t;
typedef bit<16> pathId_t;
typedef bit<16> jondoId_t;

/*************************************************************************
*********************** H E A D E R S  ***********************************
*************************************************************************/

#define TYPE_TCP 6
#define TYPE_JONDO 233
#define RANDOM_PLACEHOLDER 233
#define SUBMIT_ID 233
#define NO_PATH

header jondo_t {
	bit<1> is_response;
	pathId_t path_id;
}

header ethernet_t {
    macAddr_t dstAddr;
    macAddr_t srcAddr;
    bit<16>   etherType;
}

header ipv4_t {
    bit<4>    version;
    bit<4>    ihl;
    bit<8>    diffserv;
    bit<16>   totalLen;
    bit<16>   identification;
    bit<3>    flags;
    bit<13>   fragOffset;
    bit<8>    ttl;
    bit<8>    protocol;
    bit<16>   hdrChecksum;
    ip4Addr_t srcAddr;
    ip4Addr_t dstAddr;
}

header tcp_t{
    bit<16> srcPort;
    bit<16> dstPort;
    bit<32> seqNo;
    bit<32> ackNo;
    bit<4>  dataOffset;
    bit<3>  res;
    bit<3>  ecn;
    bit<6>  ctrl;
    bit<16> window;
    bit<16> checksum;
    bit<16> urgentPtr;
}

struct jondo_metadata_t {
	bit<1> is_jondo;
	jondoId_t next_hop_id;
	bit<1> is_encrypt;
	bit<1> is_submit;
}

struct headers_t {
    ethernet_t  ethernet;
    ipv4_t      ipv4;
	tcp_t 		tcp;
	jondo_t 	jondo;
}

/*************************************************************************
***********************  P A R S E   P A C K E T *************************
*************************************************************************/

parser jondoParser(packet_in packet,
                    out headers_t parsed_header,
                    inout jondo_metadata_t metadata,
                    inout standard_metadata_t standard_metadata) {

    state start {
        transition parse_ethernet;
    }

    state parse_ethernet {
        packet.extract(parsed_header.ethernet);
        transition parse_ipv4;
    }

    state parse_ipv4 {
        packet.extract(parsed_header.ipv4);
		transition select(parsed_header.ipv4.protocal)
		{
			TYPE_TCP: parse_tcp;
			TYPE_JONDO: parse_jondo;
			default: accept;
		}
    }

	state parse_tcp {
		packet.extract(parsed_header.tcp);
		metadata.is_jondo = 0;
		transition accept;
	}

	state parse_jondo {
		packet.extract(parsed_header.jondo);
		metadata.is_jondo = 1;
		transition accept;
	}
}


/*************************************************************************
************   C H E C K S U M    V E R I F I C A T I O N   *************
*************************************************************************/

control jondoVerifyChecksum(inout headers_t hdr,
                             inout jondo_metadata_t meta) {
     apply { }
}


/*************************************************************************
***********************  I N G R E S S  **********************************
*************************************************************************/

control jondoIngress(inout headers_t hdr,
                      inout jondo_metadata_t metadata,
                      inout standard_metadata_t standard_metadata) {

	action nop() 
	{
		//do nothing
	}

	action encryptPayload()
	{
		// placeholder
	}

	action decryptPayload()
	{
		// placeholder
	}

	table toEncryptPayload {
		key = {
			metadata.is_encrypt : exact; // dummy, don't need key
		}

		actions = {
			encryptPayload;
		}
		default_action = encryptPayload;
	}

	table toDecryptPayload {

		key = {
			metadata.is_encrypt : exact; // dummy, don't need key
		}

		actions= {
			decryptPayload;
		}
		default_action = decryptPayload;
	}

	action setPathID(pathId_t path_id, bit<1> is_submit)
	{
		hdr.jondo.path_id = path_id;
		metadata.is_submit = is_submit;
	}

	table nextToPrevPI {
		key = {
			hdr.jondo.path_id : exact;
		}

		actions = {
			setPathID;
		}

		default_action = setPathID;
	}

	action buildPath()
	{
		hdr.jondo.path_id = RANDOM_PLACEHOLDER;
		jondoId_t jondo_id = RANDOM_PLACEHOLDER;
		/* TODO: inform control plane */
		/*	digest() */
		if (jondo_id == SUBMIT_ID)
			metadata.is_submit = 1;
	}

	table prevToNextPI {
		key = {
			hdr.jondo.path_id : exact;
		}

		actions = {
			setPathID;
		}

		default_action = buildPath;
	}

	action setJondoID(jondoId_t next_id ) {
		metadata.next_hop_id = next_id;
	}

	table pathIDToJondoID {
		key = {
			hdr.jondo.path_id : exact;
		}

		actions = {
			setJondoID;
		}
		default_action  = setJondoID;

	action convertToJondo()
	{
		hdr.jondo.is_response = 1;
		hdr.jondo.path_id = hdr.tcp.dstPort;
	}

	table toConvertToJondo {
		key = {
			metadata.is_encrypt; // dummy, don't need key
		}

		actions = {
			convertToJondo;
		}
		default_action = convertToJondo;
	}

	action setRoute(macAddr_t src_mac, macAddr_t dst_mac, ip4Addr_t src_ip, ip4Addr_t dst_ip)
	{
		hdr.ethernet.srcAddr = src_mac;
		hdr.ethernet.dstAddr = dst_mac;
		hdr.ipv4.srcAddr = src_ip;
		hdr.ipv4.dstAddr = dst_ip;
	}

	table jondoIDToRoute {
		key = {
			metadata.next_hop_id : exact;
		}

		actions = {
			setRoute;
		}
		default_action = setRoute;
	}

	action submit(macAddr_t src_mac, macAddr_t dst_mac, ip4Addr_t src_ip, ip4Addr_t dst_ip, bit<16> src_port, bit<16> dst_port)
	{
		hdr.ethernet.srcAddr = src_mac;
		hdr.ethernet.dstAddr = dst_mac;
		hdr.ipv4.srcAddr = src_ip;
		hdr.ipv4.dstAddr = dst_ip;
		hdr.tcp.srcPort = src_port; /* store path id in srcPort */
		hdr.tcp.dstPort = dst_port;
	}

	table toSubmit {
		key = {
			hdr.jondo.path_id : exact;
		}

		actions = {
			submit;
		}
		default_action = submit;
	}

    apply {
		toDecryptPayload.apply();
		if (metadata.is_jondo == 0)
		{
			toConvertToJondo.apply();
		}

		if (hdr.jondo.is_response == 0)
			prevToNextPI.apply();
		else
			nextToPrevPI.apply();

		if (metadata.is_submit == 0)
		{
			pathIDToJondoID.apply();
			jondoIDToRoute.apply();
			toEncryptPayload.apply();
		}
		else
		{
			toSubmit.apply();
		}
    }
}


/*************************************************************************
***********************  E G R E S S  ************************************
*************************************************************************/

control jondoEgress(inout headers_t hdr,
                     inout jondo_metadata_t metadata,
                     inout standard_metadata_t standard_metadata) {
    apply { }
}


/*************************************************************************
*************   C H E C K S U M    C O M P U T A T I O N   ***************
*************************************************************************/

control jondoComputeChecksum(inout headers_t hdr,
                              inout jondo_metadata_t meta) {
    // Note that the switch handles the Ethernet checksum.
    // We don't need to deal with that.
    // But we may need to deal with the IP checksum!
    apply {
        update_checksum(
            hdr.ipv4.isValid(),
            { hdr.ipv4.version,
              hdr.ipv4.ihl,
              hdr.ipv4.diffserv,
              hdr.ipv4.totalLen,
              hdr.ipv4.identification,
              hdr.ipv4.flags,
              hdr.ipv4.fragOffset,
              hdr.ipv4.ttl,
              hdr.ipv4.protocol,
              hdr.ipv4.srcAddr,
              hdr.ipv4.dstAddr },
            hdr.ipv4.hdrChecksum,
            HashAlgorithm.csum16);
    }
}

/*************************************************************************
****************  E G R E S S   P R O C E S S I N G   ********************
*************************************************************************/

control jondoDeparser(packet_out packet, in headers_t hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.ipv4);
		packet.emit(hdr.jondo);
		packet.emit(hdr.tcp);
    }
}

/*************************************************************************
***********************  S W I T C H  ************************************
*************************************************************************/

V1Switch(jondoParser(),
         jondoVerifyChecksum(),
         jondoIngress(),
         jondoEgress(),
         jondoComputeChecksum(),
         jondoDeparser()) main;
