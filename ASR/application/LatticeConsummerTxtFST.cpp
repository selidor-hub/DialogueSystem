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

#include "LatticeConsummerTxtFST.h"

#include <sstream>
#include <vector>
#include <assert.h>
#include "OutputDataCreator.h"

namespace kaldi {

LatticeConsummerTxtFST::LatticeConsummerTxtFST(std::shared_ptr<OutputLayerInterface> output,
		std::unique_ptr<LatticeConverterInterface> converter):
			outputLayer(output),
			converter(std::move(converter)){

}

LatticeConsummerTxtFST::~LatticeConsummerTxtFST() {
}

void LatticeConsummerTxtFST::send(const CompactLattice &lat) {

	outputLayer->send(OutputDataCreator()
			.setLattice(converter->convert(lat))
			.create());
}

void LatticeConsummerTxtFST::send(const CompactLattice &lat,
		float endingPitchProb) {

	outputLayer->send(OutputDataCreator()
			.setLattice(converter->convert(lat))
			.setQuestionPower(std::to_string(endingPitchProb))
			.create());
}


void LatticeConsummerTxtFST::send(const CompactLattice& lat, float endingPitchProb, const std::string& text, const std::string& sessionId) {

	outputLayer->send(OutputDataCreator()
			.setLattice(converter->convert(lat))
			.setQuestionPower(std::to_string(endingPitchProb))
			.setText(text)
			.setSessionId(sessionId)
			.create());
}

void LatticeConsummerTxtFST::send(const CompactLattice& lat,
		float endingPitchProb, const std::string& text, const std::string& sessionId,
		const std::string& time_start, const std::string& time_end,
		const unsigned int vadSessionCounter, const unsigned int latticeCounter)  {

	outputLayer->send(OutputDataCreator()
			.setLattice(converter->convert(lat))
			.setQuestionPower(std::to_string(endingPitchProb))
			.setText(text)
			.setSessionId(sessionId)
			.setLatticeTimeSpan(time_start, time_end)
			.setSadSessionId(std::to_string(vadSessionCounter))
			.setLatticeCounter(std::to_string(latticeCounter))
			.create());
}

}
