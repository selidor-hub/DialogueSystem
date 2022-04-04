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

#ifndef QUESTIONFINDER_H_
#define QUESTIONFINDER_H_
#include "feat/online-feature.h"
#include "feat/pitch-functions.h"
#include <iostream>
#include <fstream>
#include <boost/circular_buffer.hpp>
#include <algorithm>
#include <chrono>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <numeric>
#include <cmath>
#include <iterator>
#include <set>
#include "lat/lattice-functions.h"
#include "online2/online-timing.h"
#include "online2/online-endpoint.h"
#include "lat/word-align-lattice.h"

namespace kaldi {

class PitchChunk {
public:
	PitchChunk(int sequenceFrameIndex, int pitchFrequency) :
		frameIndex(sequenceFrameIndex), pitch(pitchFrequency) {
	}
	int getFrameIndex() const {
		return frameIndex;
	}
	void setFrameIndex(int frameIndex) {
		this->frameIndex = frameIndex;
	}
	int getPitch() const {
		return pitch;
	}
	void setPitch(int pitch) {
		this->pitch = pitch;
	}

private:
	int frameIndex;
	int pitch;
};

class QuestionFinder {
public:
	QuestionFinder(const kaldi::WordBoundaryInfo& info, const kaldi::TransitionModel &tmodel);

	float probabilityOfQuestion(const kaldi::CompactLattice &clat, int searchStartFrame);
	void addFrame(const PitchChunk& pitchFrame);

private:
	constexpr static size_t numberBufferedFrames = 500;
	constexpr static size_t numberBufferedFramesToAnalyze = 30;// 300ms, Pitch frame 10ms
	constexpr static size_t numberBufferedFramesToCalcAverage = 100; //1000ms/10ms
	constexpr static int acousticToPitchFramesScale = 3;

	const std::set<int32> nonWordIds{0, 1, 2};
	constexpr static int numberOfHalfTonesInThreshold = 4;
	constexpr static float halfToneStep = 1.059463;
	constexpr static float thresholdStep() {
		return std::pow(halfToneStep, numberOfHalfTonesInThreshold);
	}

	const kaldi::WordBoundaryInfo& info;
	const kaldi::TransitionModel &tmodel;

	boost::circular_buffer<PitchChunk> pitchBuffer;
	boost::circular_buffer<PitchChunk>::iterator realEndpointIterator;
	int lastAvgPith;

	float questionThresholdForLastCalculation();
	size_t findFirstRealEndingWord(const std::vector<int32>& wordsIdVector);
	boost::circular_buffer<PitchChunk>::iterator findEndpoint(const kaldi::CompactLattice &lattice, int searchStartFrame);
	int averagePitch(boost::circular_buffer<PitchChunk>::iterator& endpointIterator);
	float wasQuestion(boost::circular_buffer<PitchChunk>::iterator& bufferIterator);
	bool isSilenceFrame(int pitchFramesDiff) {
		return pitchFramesDiff == 0;
	}


};


} /* namespace kaldi */

#endif /* QUESTIONFINDER_H_ */
