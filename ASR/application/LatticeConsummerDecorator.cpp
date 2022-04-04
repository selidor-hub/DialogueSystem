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

#include "LatticeConsummerDecorator.h"
#include <fstream>
namespace kaldi {

LatticeConsummerDecorator::LatticeConsummerDecorator(std::shared_ptr<LatticeConsummerInterface> latticeOut,
		std::shared_ptr<OutputLayerInterface> outputLayer,
		std::shared_ptr<AsrOutputDataCollectorInterface> dataCollector) :
			latticeOutput(latticeOut),
			clientInterface(outputLayer),
			fileDataCollector(dataCollector){

}

LatticeConsummerDecorator::~LatticeConsummerDecorator() {
}

void AsrOutputDataCollector::saveAndClearCache() {
	auto currentTimeAndIndex = getTimeStamp()+"_"+std::to_string(file_index++);

	auto filename = filesPrefix+currentTimeAndIndex+latticeExt;
	saveDataInFile(filename, latticeFst);

	filename = filesPrefix+currentTimeAndIndex+bestExt;
	saveDataInFile(filename, bestPath);

	//filename = filesPrefix+currentTimeAndIndex+respExt;
	//saveDataInFile(filename, response);

	cleanLastData();
}

void LatticeConsummerDecorator::updateDataCollector() {
	fileDataCollector->setLatticeFst(clientInterface->getSentData());
	fileDataCollector->setClientResponse(clientInterface->getResponse());
	fileDataCollector->saveAndClearCache();
}

void LatticeConsummerDecorator::send(const CompactLattice &lat) {
	latticeOutput->send(lat);
	updateDataCollector();
}

void LatticeConsummerDecorator::send(const CompactLattice &lat,
		float endingPitchProb) {
	latticeOutput->send(lat, endingPitchProb);
	updateDataCollector();

}

void LatticeConsummerDecorator::send(const CompactLattice &lat,
		float endingPitchProb, const std::string &text, const std::string& sessionId) {
	latticeOutput->send(lat, endingPitchProb, text, sessionId);
	updateDataCollector();
}

void LatticeConsummerDecorator::send(const CompactLattice& lat,
		float endingPitchProb, const std::string& text, const std::string& sessionId,
		const std::string& time_start, const std::string& time_end,
		const unsigned int vadSessionCounter, const unsigned int latticeCounter)  {
	latticeOutput->send(lat, endingPitchProb, text, sessionId, time_start, time_end, vadSessionCounter, latticeCounter);
	updateDataCollector();
}

std::string AsrOutputDataCollector::getTimeStamp() const {
	auto t = std::time(nullptr);
	auto tm = *std::localtime(&t);

	std::ostringstream oss;
	oss << std::put_time(&tm, "-%Y-%m-%d_%H-%M-%S");
	return oss.str();
}

void AsrOutputDataCollector::saveDataInFile(const std::string &fileName,
		const std::string &data) {
	std::ofstream ofs(fileName);
	if (ofs.is_open()) {
		ofs << data;
	}
}

}
