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

#ifndef TCPOUTPUTLAYER_H_
#define TCPOUTPUTLAYER_H_
#include <stdio.h>
#include <string.h>
#include <iostream>
#include <boost/array.hpp>
#include <boost/asio.hpp>

#include "OutputLayerInterface.h"

using boost::asio::ip::tcp;

class TcpOutputLayer: public OutputLayerInterface {
public:
	TcpOutputLayer(const std::string& ip, unsigned short port);
	virtual ~TcpOutputLayer();

	virtual void send(const std::string& data) override;
	virtual const std::string& getResponse() const override;
	virtual const std::string& getSentData() const override;

private:
	void tryConnect(tcp::socket& socket);
	const std::string& receiveAll(tcp::socket& socket);

	boost::asio::io_service io_service;
	tcp::socket socket;
	tcp::resolver::iterator endpoint_it;
	std::string last_response;
	std::string last_data;
};

#endif /* TCPOUTPUTLAYER_H_ */
