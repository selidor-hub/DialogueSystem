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

#ifndef VADNNET_H_
#define VADNNET_H_

#include "VADInterface.h"
#include "feat/feature-mfcc.h"
#include "nnet3/nnet-am-decodable-simple.h"
#include "nnet3/nnet-utils.h"
#include <string>
#include <vector>
#include <algorithm>
#include "VADEventObserverInterface.h"
#include "base/kaldi-common.h"
namespace kaldi {

class VADDummy : public VADInterface {
public:
	virtual ~VADDummy() {}

	virtual bool isChunkSpeech(BaseFloat sampling_rate, const Vector<BaseFloat>& wave_part) override {return true;}
	virtual bool isVadDecisionChangedInLastCheck() override {return false;}
	virtual void registerEventObserver(
			VADEventObserverInterfaceSharedPtr observer) override {
	}
	virtual void setAsrSessionId(const std::string& asrSessionId) override {}
	virtual void clearVadSessionCounter( ){}
	virtual unsigned int vadSessionCounter() {return 0;}
};

class VADNnet : public VADInterface {
public:
	VADNnet(const std::string& VAD_options_file_path);
	virtual ~VADNnet();

	virtual bool isChunkSpeech(BaseFloat sampling_rate, const Vector<BaseFloat>& wave_part) override;
	virtual bool isVadDecisionChangedInLastCheck() override {
		return lastVadDecision != previousVadDecision;
	}
	virtual void registerEventObserver(VADEventObserverInterfaceSharedPtr observer) override {
		eventController->registerEventObserver(observer);
	}
	virtual void setAsrSessionId(const std::string& asrSessionId) override {
		this->asrSessionId = asrSessionId;
	}

	virtual unsigned int vadSessionCounter();
	virtual void clearVadSessionCounter();

private:
	class SilenceFilter {
	public:
		SilenceFilter(const uint32 silence_filter_factor) :
			silence_filter_factor(silence_filter_factor) {
		}

		void countSpeech() {
			silence_filter_counter = silence_filter_factor;
		}
		void countSilence() {
			if (silence_filter_counter > 0) --silence_filter_counter;
		}
		bool isSilence() {
			return silence_filter_counter == 0;
		}

	private:
		const uint32 silence_filter_factor;
		uint32 silence_filter_counter = 0;
	};

	class EventController {
	public:
		EventController(std::shared_ptr<SilenceFilter> silenceFilter) :
			silenceFilter(silenceFilter)
		{}

		void evaluateFilterAndSendEvents(unsigned int vadSessionCounter, const std::string& asrSessionId) {
			bool currentVadState = not silenceFilter->isSilence();
			bool wasChenged = previousVadState != currentVadState;
			if (wasChenged && currentVadState) {
				for (auto& o : observers)
					o->startSpeechEvent(vadSessionCounter, asrSessionId);
			}
			else if (wasChenged && not currentVadState) {
				for (auto& o : observers)
					o->endSpeechEvent(vadSessionCounter, asrSessionId);
			}
			previousVadState = currentVadState;
		}

		void registerEventObserver(std::shared_ptr<VADEventObserverInterface> observer) {
			observers.push_back(observer);
		}

	private:
		bool previousVadState = false;

		std::vector<VADEventObserverInterfaceSharedPtr> observers {};
		std::shared_ptr<SilenceFilter> silenceFilter;
	};

	MfccOptions mfcc_options;
	nnet3::NnetSimpleComputationOptions nnet_options;
	std::string vad_nnet_file {""};
	BaseFloat vtln_warp = 1.0;
	Vector<BaseFloat> priors;

	std::unique_ptr<Mfcc> mfcc = nullptr;
	std::unique_ptr<nnet3::Nnet> nnet = nullptr;
	std::unique_ptr<nnet3::CachingOptimizingCompiler> compiler = nullptr;
	std::shared_ptr<SilenceFilter> silenceFilter = nullptr;
	std::unique_ptr<EventController> eventController = nullptr;
	bool lastVadDecision = false;
	bool previousVadDecision = false;
	unsigned int vadSessionCount = 0;
	std::string asrSessionId;

	const uint32 silenceIndexInNnetOutput = 1;
	BaseFloat silence_cost_threshold = -2.0;
	uint32 silence_filter_factor = 2000;

	bool isSpeech(const Vector<BaseFloat>& vector) {
		if (vector(silenceIndexInNnetOutput) > silence_cost_threshold)
			return true;
		else
			return false;
	}
};

} /* namespace kaldi */

#endif /* VADNNET_H_ */
