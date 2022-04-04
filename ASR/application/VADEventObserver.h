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

#ifndef VADEVENTOBSERVER_H_
#define VADEVENTOBSERVER_H_

#include "VADEventObserverInterface.h"
#include "OutputLayerInterface.h"
#include "OutputDataCreator.h"

namespace kaldi {

class VADEventObserver: public VADEventObserverInterface {
public:
	VADEventObserver(std::shared_ptr<OutputLayerInterface> output);
	virtual ~VADEventObserver();
	virtual void startSpeechEvent(unsigned int vadSessionId, const std::string& asrSessionId) override;
	virtual void endSpeechEvent(unsigned int vadSessionId, const std::string& asrSessionId) override;

private:
	std::shared_ptr<OutputLayerInterface> outputLayer;

	std::string getTimeToEpoch();
};

} /* namespace kaldi */

#endif /* VADEVENTOBSERVER_H_ */
