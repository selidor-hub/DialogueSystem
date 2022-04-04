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

#ifndef LATTICECONSUMMERDECORATOR_H_
#define LATTICECONSUMMERDECORATOR_H_
#include "OutputLayerInterface.h"
#include <memory>
#include <string>
#include "LatticeConsummerInterface.h"
#include <iostream>
#include <iomanip>
#include <ctime>
#include <sstream>

namespace kaldi {

class AsrOutputDataCollectorInterface {
public:
	virtual void saveAndClearCache() = 0;
	virtual void setBestPath(const std::string& bestPath) = 0;
	virtual void setLatticeFst(const std::string& latticeFst) = 0;
	virtual void setClientResponse(const std::string& response) = 0;
};

class LatticeConsummerDecorator : public LatticeConsummerInterface {
public:
	LatticeConsummerDecorator(std::shared_ptr<LatticeConsummerInterface> latticeOut,
			std::shared_ptr<OutputLayerInterface> output,
			std::shared_ptr<AsrOutputDataCollectorInterface> dataCollector);
	virtual ~LatticeConsummerDecorator();

	virtual void send(const CompactLattice& lat) override;
	virtual void send(const CompactLattice& lat, float endingPitchProb) override;
	virtual void send(const CompactLattice& lat, float endingPitchProb, const std::string& text, const std::string& sessionId) override;
	virtual void send(const CompactLattice& lat, float endingPitchProb, const std::string& text, const std::string& sessionId,
			const std::string& time_start, const std::string& time_stop,
			const unsigned int vadSessionCounter, const unsigned int latticeCounter)  override;

private:
	void updateDataCollector();

	std::shared_ptr<LatticeConsummerInterface> latticeOutput;
	std::shared_ptr<OutputLayerInterface> clientInterface;
	std::shared_ptr<AsrOutputDataCollectorInterface> fileDataCollector;
};

class AsrOutputDataCollector : public AsrOutputDataCollectorInterface {
public:
	AsrOutputDataCollector(const std::string& files_prefix) :
		filesPrefix(files_prefix) {}

	virtual void saveAndClearCache() override;

	virtual void setBestPath(const std::string& bestPath) override {
		this->bestPath = bestPath;
	}

	virtual void setLatticeFst(const std::string& latticeFst) override {
		this->latticeFst = latticeFst;
	}

	virtual void setClientResponse(const std::string& response) override {
		this->response = response;
	}

private:
	void cleanLastData() {
		bestPath.clear();
		latticeFst.clear();
		response.clear();
	}
	std::string getTimeStamp() const;
	void saveDataInFile(const std::string& fileName, const std::string& data);

	unsigned int file_index = 0;
	std::string bestPath;
	std::string latticeFst;
	std::string response;
	const std::string filesPrefix;

	const std::string latticeExt = ".lat.fst.txt";
	const std::string bestExt = ".best.txt";
	const std::string respExt = ".json";
};

class AsrOutputDataCollectorDummy : public AsrOutputDataCollectorInterface {
public:
	virtual ~AsrOutputDataCollectorDummy() {};
	virtual void saveAndClearCache() override {};
	virtual void setBestPath(const std::string& bestPath) override {}
	virtual void setLatticeFst(const std::string& latticeFst) override {}
	virtual void setClientResponse(const std::string& response) override {}
};
}
#endif /* LATTICECONSUMMERDECORATOR_H_ */
