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

#include "VADEventObserver.h"
#include <string>
#include <chrono>
#include <sstream>
#include "time_utils.h"

namespace kaldi {

VADEventObserver::VADEventObserver(std::shared_ptr<OutputLayerInterface> output) :
	outputLayer(output) {
}

VADEventObserver::~VADEventObserver() {
}

void VADEventObserver::startSpeechEvent(unsigned int vadSessionId, const std::string& asrSessionId) {
	outputLayer->send(OutputDataCreator()
			.setSadEvent(SadEvent::start)
			.setSadEventTime(time_utils::getTimeToEpoch_ms())
			.setSadSessionId(std::to_string(vadSessionId))
			.setSessionId(asrSessionId)
			.create());
}

void VADEventObserver::endSpeechEvent(unsigned int vadSessionId, const std::string& asrSessionId) {
	outputLayer->send(OutputDataCreator()
			.setSadEvent(SadEvent::end)
			.setSadEventTime(time_utils::getTimeToEpoch_ms())
			.setSadSessionId(std::to_string(vadSessionId))
			.setSessionId(asrSessionId)
			.create());
}

} /* namespace kaldi */
