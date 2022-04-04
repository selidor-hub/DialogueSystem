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

#include "VADNnet.h"
#include "util/common-utils.h"
#include "base/kaldi-common.h"
#include <boost/algorithm/string/split.hpp>
#include <boost/algorithm/string/classification.hpp>

namespace kaldi {
using namespace nnet3;

VADNnet::VADNnet(const std::string& VAD_options_file_path)
{
	const char *usage = ".";
	ParseOptions po(usage);
	mfcc_options.Register(&po);
	nnet_options.Register(&po);
	po.Register("vad-nnet-file", &vad_nnet_file, "Path to nnet VAD file.");
	po.Register("vad-silence-filter-factor", &silence_filter_factor, "Time [ms] after which no-speech frames are considered speechless (default: 2000)");
	po.Register("vad-silence-cost-threshold", &silence_cost_threshold, "Threshold cost of nnet silence output after which audio frames are considered speech (average values: -6 .. -1, default: -2.0)");
	po.ReadConfigFile(VAD_options_file_path);
	mfcc.reset(new Mfcc(mfcc_options));

    nnet_options.acoustic_scale = 1.0; // by default do no scaling.
	nnet.reset(new Nnet());
	ReadKaldiObject(vad_nnet_file, nnet.get());
	SetBatchnormTestMode(true, nnet.get());
	SetDropoutTestMode(true, nnet.get());
	CollapseModel(CollapseModelConfig(), nnet.get());
	compiler.reset(new CachingOptimizingCompiler(*nnet, nnet_options.optimize_config));

	silence_filter_factor /= mfcc_options.frame_opts.frame_shift_ms; // convert time [ms] to frames number
	KALDI_VLOG(1) << "silence_filter_factor [frames]" << silence_filter_factor;
	silenceFilter.reset(new SilenceFilter(silence_filter_factor));
	eventController.reset(new EventController(silenceFilter));
}

VADNnet::~VADNnet() {
}

bool VADNnet::isChunkSpeech(BaseFloat sampling_rate,
		const Vector<BaseFloat> &wave_part) {

	previousVadDecision = lastVadDecision;

	Matrix<BaseFloat> features;
	try {
		mfcc->ComputeFeatures(wave_part, sampling_rate, vtln_warp, &features);
	} catch (...) {
		KALDI_WARN <<  "Failed to compute features for wave part";
		return true;
	}

	DecodableNnetSimple nnet_computer(
			nnet_options, *nnet, priors,
			features, compiler.get());
	Vector<BaseFloat> nnetOutputVector(nnet_computer.OutputDim());

	for (int32 i = 0; i < nnet_computer.NumFrames(); i++) {
		nnet_computer.GetOutputForFrame(i, &nnetOutputVector);

		if (isSpeech(nnetOutputVector)) {
			silenceFilter->countSpeech();
		} else {
			silenceFilter->countSilence();
		}
	}

	lastVadDecision = not silenceFilter->isSilence();
	KALDI_VLOG(2) << "VAD decision " <<  lastVadDecision;

	if (lastVadDecision && isVadDecisionChangedInLastCheck())
		vadSessionCount++;

	eventController->evaluateFilterAndSendEvents(vadSessionCount, asrSessionId);
	return lastVadDecision;
}

unsigned int VADNnet::vadSessionCounter() {
	return vadSessionCount;
}

void VADNnet::clearVadSessionCounter() {
	vadSessionCount = 0;
}

} /* namespace kaldi */
