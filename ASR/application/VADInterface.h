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

#ifndef VADINTERFACE_H_
#define VADINTERFACE_H_

#include "base/kaldi-types.h"
#include "matrix/kaldi-vector.h"
#include "VADEventObserverInterface.h"

namespace kaldi {
class VADInterface {
public:
	virtual ~VADInterface() = default;
	virtual bool isChunkSpeech(BaseFloat sampling_rate, const Vector<BaseFloat>& wave_part) = 0;
	virtual bool isVadDecisionChangedInLastCheck() = 0;
	virtual unsigned int vadSessionCounter() = 0;
	virtual void clearVadSessionCounter() = 0;
	virtual void setAsrSessionId(const std::string& asrSessionId) = 0;
	virtual void registerEventObserver(VADEventObserverInterfaceSharedPtr observer) = 0;
};

}

#endif /* VADINTERFACE_H_ */
