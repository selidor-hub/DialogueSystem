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

#ifndef BUILD_LATTICEOUTPUTINTERFACE_H_
#define BUILD_LATTICEOUTPUTINTERFACE_H_
#include "lat/lattice-functions.h"
#include <string>

namespace kaldi {

class LatticeConsummerInterface {
public:
	virtual ~LatticeConsummerInterface() = default;
	virtual void send(const CompactLattice& lat) = 0;
	virtual void send(const CompactLattice& lat, float endingPitchProb) = 0;
	virtual void send(const CompactLattice& lat, float endingPitchProb, const std::string& text, const std::string& sessionId) = 0;
	virtual void send(const CompactLattice& lat, float endingPitchProb, const std::string& text, const std::string& sessionId,
			const std::string& time_start, const std::string& time_end,
			const unsigned int vadSessionCounter, const unsigned int latticeCounter) = 0;
};

}
#endif /* BUILD_LATTICEOUTPUTINTERFACE_H_ */
