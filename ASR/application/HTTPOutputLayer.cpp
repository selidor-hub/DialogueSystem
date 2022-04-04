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

#include "HTTPOutputLayer.h"

HTTPOutputLayer::HTTPOutputLayer(const std::string& ip, unsigned short port) :
	ip(ip),
	port(port),
	ioc()
{
	thread = std::thread([&](){execute();});
	thread.detach();
}

HTTPOutputLayer::~HTTPOutputLayer() {
	continue_thread = false;
	lock_thread.notify_all();
}



void HTTPOutputLayer::send(const std::string &data) {
	last_data = data;
	std::make_shared<session>(ioc)->run(ip.c_str(), std::to_string(port).c_str(), "/czatbot/webhook_asr", data, 11/*or 10*/);
	lock_thread.notify_all();
}

const std::string& HTTPOutputLayer::getResponse() const {
	return last_response;
}

const std::string& HTTPOutputLayer::getSentData() const {
	return last_data;
}

void HTTPOutputLayer::execute() {
	while(continue_thread) {
		ioc.run();
		std::unique_lock<std::mutex> lck(mutex);
		lock_thread.wait(lck);
		ioc.restart();
	}
}
