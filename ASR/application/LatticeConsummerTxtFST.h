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

#ifndef LATTICECONSUMMERTXTFST_H_
#define LATTICECONSUMMERTXTFST_H_

#include "OutputLayerInterface.h"
#include <memory>
#include "base/kaldi-common.h"
#include "util/common-utils.h"
#include "fstext/fstext-lib.h"
#include "lat/kaldi-lattice.h"
#include "LatticeConsummerInterface.h"
#include "LatticeConverterInterface.h"


namespace kaldi {

class LatticeConsummerTxtFST: public LatticeConsummerInterface {
public:
	LatticeConsummerTxtFST(std::shared_ptr<OutputLayerInterface> output,
			std::unique_ptr<LatticeConverterInterface> converter);
	virtual ~LatticeConsummerTxtFST();

	virtual void send(const CompactLattice& lat) override;
	virtual void send(const CompactLattice& lat, float endingPitchProb) override;
	virtual void send(const CompactLattice& lat, float endingPitchProb, const std::string& text, const std::string& sessionId) override;
	virtual void send(const CompactLattice& lat, float endingPitchProb, const std::string& text, const std::string& sessionId,
			const std::string& time_start, const std::string& time_end,
			const unsigned int vadSessionCounter, const unsigned int latticeCounter)  override;

private:

	std::shared_ptr<OutputLayerInterface> outputLayer;
	std::unique_ptr<LatticeConverterInterface> converter;
};

}
#endif /* LATTICECONSUMMERTXTFST_H_ */
