// Automated Speech Recognition Module
// Copyright (C) 2022 SELIDOR - T. Puza, Ł. Wasilewski Sp.J.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
// THIS CODE IS PROVIDED *AS IS* BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, EITHER EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION ANY IMPLIED
// WARRANTIES OR CONDITIONS OF TITLE, FITNESS FOR A PARTICULAR PURPOSE,
// MERCHANTABLITY OR NON-INFRINGEMENT.
// See the Apache 2 License for the specific language governing permissions and
// limitations under the License.

#include "TcpOutputLayer.h"
#include "base/kaldi-error.h"
#include <boost/exception/diagnostic_information.hpp>

TcpOutputLayer::TcpOutputLayer(const std::string& ip, unsigned short port) :
io_service(),
socket(io_service),
last_response(""),
last_data("") {

	tcp::resolver::query query(ip, std::to_string(port));
	tcp::resolver resolver(io_service);

	try {
		endpoint_it = resolver.resolve(query);
	}
	catch (boost::system::system_error& e) {
		throw std::runtime_error(e.what());
	}
}

TcpOutputLayer::~TcpOutputLayer() {
}

void TcpOutputLayer::send(const std::string &data) {

	//TODO implement synchronized queue and thread
	last_data = data;
	try {
		tryConnect(socket);
		boost::asio::write(socket, boost::asio::buffer(data.c_str(), data.length()));
		KALDI_LOG << "Sent " << data.length() << " bytes";
		last_response = receiveAll(socket);
	}
	catch(...) {
		KALDI_WARN << "TCP socket writing error, more info in VLOG(1)";
		KALDI_VLOG(1) << "TCP socket error, diagnostic information follows:\n" <<
				boost::current_exception_diagnostic_information();
	}
}

const std::string& TcpOutputLayer::getResponse() const {
	return last_response;
}

const std::string& TcpOutputLayer::getSentData() const {
	return last_data;
}

void TcpOutputLayer::tryConnect(tcp::socket &socket) {
	if (not socket.is_open()) {
		boost::asio::connect(socket, endpoint_it);
		boost::asio::socket_base::keep_alive keepAlive(true);
		socket.set_option(keepAlive);
	}
}

const std::string& TcpOutputLayer::receiveAll(tcp::socket &socket) {
	boost::asio::streambuf buf;
	std::size_t n = boost::asio::read_until(
			socket, buf, "\n\n");

	auto bufs = buf.data();
	last_response = std::string(boost::asio::buffers_begin(bufs),
	                boost::asio::buffers_begin(bufs) + buf.size());
	KALDI_LOG << "Received " << n << " bytes";
	return last_response;
}
