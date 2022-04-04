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

#ifndef OUTPUTLAYERINTERFACE_H_
#define OUTPUTLAYERINTERFACE_H_

#include <string>

class OutputLayerInterface {
public:
	virtual ~OutputLayerInterface() = default;
	virtual void send(const std::string& data) = 0;
	virtual const std::string& getResponse() const = 0;
	virtual const std::string& getSentData() const = 0;
};

#endif /* OUTPUTLAYERINTERFACE_H_ */
