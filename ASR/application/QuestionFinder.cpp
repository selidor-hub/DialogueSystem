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

#include "QuestionFinder.h"
#include <algorithm>

namespace kaldi {

typedef int FremeIndex;

QuestionFinder::QuestionFinder(const kaldi::WordBoundaryInfo& info, const kaldi::TransitionModel &tmodel)  :
			info(info),
			tmodel(tmodel),
			realEndpointIterator(),
			lastAvgPith{0} {
	pitchBuffer.set_capacity(numberBufferedFrames);
}

float QuestionFinder::probabilityOfQuestion(const kaldi::CompactLattice &clat, int searchStartFrame) {
	float questionProb = 0.0;
	try {
		auto endFrameInBuffer = findEndpoint(clat, searchStartFrame);
		if (std::end(pitchBuffer) == endFrameInBuffer) {
			KALDI_WARN << "Not found frame in buffer";
		} else {
			questionProb = wasQuestion(endFrameInBuffer);
		}
		pitchBuffer.clear();
		questionProb /= questionThresholdForLastCalculation();
		KALDI_LOG << "Question pseudo prob: " << questionProb;
	} catch (const std::exception& e ) {
		KALDI_WARN << "QuestionFinder error:" << e.what();
	} catch (...) {
		KALDI_WARN << "QuestionFinder error";
	}
	return questionProb;
}

float QuestionFinder::questionThresholdForLastCalculation() {
	int threshold = lastAvgPith*thresholdStep() - lastAvgPith;
	KALDI_VLOG(1)  << "Question threshold [Hz]: " << threshold;
	return threshold;
}

void QuestionFinder::addFrame(const PitchChunk& pitchFrame) {
	pitchBuffer.push_back(pitchFrame);
	KALDI_VLOG(3) << " Added pitch frame with index " << pitchFrame.getFrameIndex();
}

size_t QuestionFinder::findFirstRealEndingWord(const std::vector<int32>& wordsIdVector) {
	auto offset = 0;
	auto endingWord = std::find_if(wordsIdVector.rbegin(), wordsIdVector.rend(), [&](int32 a){
		return nonWordIds.find(a) == nonWordIds.end();
	});
	offset = std::distance(wordsIdVector.rbegin(), endingWord) + 1;
	KALDI_VLOG(1)  << "Ending word offset in lat is " << offset;
	return offset;
}

boost::circular_buffer<PitchChunk>::iterator QuestionFinder::findEndpoint(const kaldi::CompactLattice &lattice, int searchStartFrame) {

	boost::circular_buffer<PitchChunk>::iterator endpoint(std::end(pitchBuffer));
	std::vector<int32> words, times_of_beginning_of_words, lengths_of_words;
	kaldi::CompactLattice best_path, best_path_align;

	bool result_ok = true;

	kaldi::CompactLatticeShortestPath(lattice, &best_path);
	result_ok &= kaldi::WordAlignLattice(best_path, tmodel, info, 0, &best_path_align);
	result_ok &= kaldi::CompactLatticeToWordAlignment(best_path_align, &words, &times_of_beginning_of_words, &lengths_of_words);

	if (result_ok && not times_of_beginning_of_words.empty() && not lengths_of_words.empty()) {
		size_t lastWordOffsetInVector = findFirstRealEndingWord(words);
		FremeIndex beginningOfLastWord = *(times_of_beginning_of_words.end()-lastWordOffsetInVector);
		FremeIndex lengthOfLastWord = *(lengths_of_words.end()-lastWordOffsetInVector);
		FremeIndex endFrameIndex = searchStartFrame + beginningOfLastWord + lengthOfLastWord;
		endFrameIndex *= acousticToPitchFramesScale;
		KALDI_VLOG(1)  << "End frame index is " << endFrameIndex;
		auto isFrameIndexEqual = [&](const PitchChunk& frame){ return endFrameIndex == frame.getFrameIndex();};
		endpoint = std::find_if(std::begin(pitchBuffer), std::end(pitchBuffer), isFrameIndexEqual);
	}
	else
	{
		KALDI_VLOG(1)  << "End frame not found";
	}
	return endpoint;
}

int QuestionFinder::averagePitch(boost::circular_buffer<PitchChunk>::iterator& endpointIterator) {

	boost::circular_buffer<PitchChunk>::iterator start_iterator(endpointIterator);
	int frameNumber = 0;
	int pichSum = 0;
	while (frameNumber < numberBufferedFramesToCalcAverage and start_iterator >= std::begin(pitchBuffer) ) {
		pichSum += start_iterator->getPitch();
		frameNumber++;
		start_iterator--;
	}

	return pichSum/frameNumber;
}

float QuestionFinder::wasQuestion(boost::circular_buffer<PitchChunk>::iterator& bufferIterator) {
	realEndpointIterator = bufferIterator;
	int pitchDeltasSum = 0;
	int lastPitch = bufferIterator->getPitch();
	int maxPitch = lastPitch;//TODO move finding max to another function

	for (auto analyzedFrame = 0; analyzedFrame < numberBufferedFramesToAnalyze and bufferIterator != std::begin(pitchBuffer); analyzedFrame++) {
		bufferIterator--;
		int pitchDelta = lastPitch - bufferIterator->getPitch();
		lastPitch = bufferIterator->getPitch();
		maxPitch = std::max(maxPitch, lastPitch);
		pitchDeltasSum += pitchDelta;

		if (isSilenceFrame(pitchDelta)) {
			analyzedFrame--; // skip silence frames
			KALDI_VLOG(2) << "Skipping frame no " << bufferIterator->getFrameIndex();
		}
		else {
			KALDI_VLOG(2) << "Processing frame " << bufferIterator->getFrameIndex() << " ,pitch " << bufferIterator->getPitch()
						<< " ,delta " << pitchDelta;
		}
		if (analyzedFrame == 0) realEndpointIterator = bufferIterator; // remember endpoint of speech
	}

	lastAvgPith = averagePitch(realEndpointIterator);
	KALDI_VLOG(1)  << "Max pitch: " << maxPitch << ", average pitch: " << lastAvgPith;

	float correctionFactor = std::pow(10.0, (maxPitch - lastAvgPith)/100.0);
	KALDI_VLOG(1)  << "Pitch delta sum: " << pitchDeltasSum << ",correction factor: " << correctionFactor;
	KALDI_VLOG(1)  << "QuestionValue: " << pitchDeltasSum * correctionFactor;

	pitchBuffer.clear();
	return pitchDeltasSum * correctionFactor;
}

} /* namespace kaldi */
