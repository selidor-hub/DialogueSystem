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

#ifndef VADEVENTOBSERVERINTERFACE_H_
#define VADEVENTOBSERVERINTERFACE_H_

#include <memory>

namespace kaldi {

class VADEventObserverInterface {
public:
	virtual ~VADEventObserverInterface() = default;
	virtual void startSpeechEvent(unsigned int vadSessionId, const std::string& asrSessionId) = 0;
	virtual void endSpeechEvent(unsigned int vadSessionId, const std::string& asrSessionId) = 0;
};

using VADEventObserverInterfaceSharedPtr = std::shared_ptr<VADEventObserverInterface>;
using VADEventObserverInterfaceUniquePtr = std::unique_ptr<VADEventObserverInterface>;

} /* namespace kaldi */

#endif /* VADEVENTOBSERVERINTERFACE_H_ */
