// online2bin/online2-tcp-nnet3-decode-faster.cc

// Copyright 2014  Johns Hopkins University (author: Daniel Povey)
//           2016  Api.ai (Author: Ilya Platonov)
//           2018  Polish-Japanese Academy of Information Technology (Author: Danijel Korzinek)
//           2022  SELIDOR - T. Puza, Ł. Wasilewski Sp.J.

// See ../../COPYING for clarification regarding multiple authors
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

#include "feat/wave-reader.h"
#include "online2/online-nnet3-decoding.h"
#include "online2/online-nnet2-feature-pipeline.h"
#include "online2/onlinebin-util.h"
#include "online2/online-timing.h"
#include "online2/online-endpoint.h"
#include "fstext/fstext-lib.h"
#include "lat/lattice-functions.h"
#include "util/kaldi-thread.h"
#include "nnet3/nnet-utils.h"
#include "lat/word-align-lattice.h"

#include <netinet/in.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <poll.h>
#include <signal.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <string>

#include "LatticeConsummerDecorator.h"
#include "LatticeConsummerTxtFST.h"
#include "TcpServer.h"
#include "QuestionFinder.h"
#include "HTTPSOutputLayer.h"
#include "HTTPOutputLayer.h"

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
#include <stdlib.h>
#include "VADNnet.h"
#include "VADEventObserver.h"
#include "time_utils.h"
#include "LatticeConverter.h"

std::string randomString(int len)
{
   std::string str = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
   std::string newstr;
   int pos;
   while(newstr.size() != len) {
    pos = ((rand() % (str.size() - 1)));
    newstr += str.substr(pos,1);
   }
   return newstr;
}

namespace kaldi {

std::string LatticeToString(const Lattice &lat, const fst::SymbolTable &word_syms) {
	LatticeWeight weight;
	std::vector<int32> alignment;
	std::vector<int32> words;
	GetLinearSymbolSequence(lat, &alignment, &words, &weight);

	std::ostringstream msg;
	for (size_t i = 0; i < words.size(); i++) {
		std::string s = word_syms.Find(words[i]);
		if (s.empty()) {
			KALDI_WARN << "Word-id " << words[i] << " not in symbol table.";
			msg << "<#" << std::to_string(i) << "> ";
		} else
			msg << s << " ";
	}
	return msg.str();
}

std::string GetTimeMsToEpochString(int32 time, float time_unit) {
	std::stringstream ss;
	auto now = std::chrono::system_clock::now().time_since_epoch();
	int time_ms = time * time_unit * 1000;
	ss << (std::chrono::duration_cast<std::chrono::milliseconds>(now).count() - time_ms);
	return ss.str();
}

std::string GetTimeString(int32 t_beg, int32 t_end, BaseFloat time_unit) {
	char buffer[100];
	double t_beg2 = t_beg * time_unit;
	double t_end2 = t_end * time_unit;
	snprintf(buffer, 100, "%.2f %.2f", t_beg2, t_end2);
	return std::string(buffer);
}

int32 GetLatticeTimeSpan(const Lattice& lat) {
	std::vector<int32> times;
	LatticeStateTimes(lat, &times);
	return times.back();
}

std::string LatticeToString(const CompactLattice &clat, const fst::SymbolTable &word_syms) {
	if (clat.NumStates() == 0) {
		KALDI_WARN << "Empty lattice.";
		return "";
	}
	CompactLattice best_path_clat;
	CompactLatticeShortestPath(clat, &best_path_clat);

	Lattice best_path_lat;
	ConvertLattice(best_path_clat, &best_path_lat);
	return LatticeToString(best_path_lat, word_syms);
}
}


int main(int argc, char *argv[]) {
	try {
		using namespace kaldi;
		using namespace fst;

		srand((unsigned)time(0));

		const char *usage =
				"Reads in audio from a network socket and performs online\n"
				"decoding with neural nets (nnet3 setup), with iVector-based\n"
				"speaker adaptation and endpointing.\n"
				"Note: some configuration values and inputs are set via config\n"
				"files whose filenames are passed as options\n"
				"\n"
				"Usage: online2-tcp-nnet3-decode-faster-lat [options] <nnet3-in> "
				"<fst-in> <word-symbol-table>\n";

		ParseOptions po(usage);


		// feature_opts includes configuration for the iVector adaptation,
		// as well as the basic features.
		OnlineNnet2FeaturePipelineConfig feature_opts;
		nnet3::NnetSimpleLoopedComputationOptions decodable_opts;
		LatticeFasterDecoderConfig decoder_opts;
		OnlineEndpointConfig endpoint_opts;
		PitchExtractionOptions pitch_opts;  // Options for pitch extraction
		WordBoundaryInfoNewOpts word_opts;

		pitch_opts.frame_shift_ms = 30/3;
		pitch_opts.frame_length_ms = 90/3;

		BaseFloat chunk_length_secs = 0.20;
		BaseFloat output_period = 1;
		BaseFloat samp_freq = 16000.0;
		int port_num = 5050;
		int read_timeout = 3;
		bool produce_time = false;
		bool produce_lattices = false;
		std::string output_files_prefix {""};
		std::string remote_server {"chatbot.reservis.xyz"};
		std::string remote_server_protocol {"https"};
		std::string remote_server_port {"443"};
		std::string remote_server_path {"/czatbot/webhook_asr"};
		std::string vad_config_file {""};

		po.Register("remote-server-address", &remote_server,
				"Address of remote HTTPS server for sending produced lattices (default: "+remote_server+")");
		po.Register("remote-server-port", &remote_server_port,
				"Port on remote server for sending produced lattices (default: "+remote_server_port+")");
		po.Register("remote-server-protocol", &remote_server_protocol,
				"Protocol on remote server for sending produced lattices [http|https] (default: "+remote_server_protocol+")");
		po.Register("remote-server-path", &remote_server_path,
				"Path on remote server for sending produced lattices (default: "+remote_server_path+")");
		po.Register("output-files-prefix", &output_files_prefix,
				"Prefix of optional output files (best path, lattice, response from client). Define to get files.");
		po.Register("produce-lattices", &produce_lattices,
						"Specifies whether the grid should be present in the output data. (default: false)");
		po.Register("samp-freq", &samp_freq,
				"Sampling frequency of the input signal (coded as 16-bit slinear).");
		po.Register("chunk-length", &chunk_length_secs,
				"Length of chunk size in seconds, that we process.");
		po.Register("output-period", &output_period,
				"How often in seconds, do we check for changes in output.");
		po.Register("num-threads-startup", &g_num_threads,
				"Number of threads used when initializing iVector extractor.");
		po.Register("read-timeout", &read_timeout,
				"Number of seconds of timout for TCP audio data to appear on the stream. Use -1 for blocking.");
		po.Register("port-num", &port_num,
				"Port number the server will listen on.");
		po.Register("produce-time", &produce_time,
				"Prepend begin/end times between endpoints (e.g. '5.46 6.81 <text_output>', in seconds)");
		po.Register("vad-config-file", &vad_config_file, "Path to nnet VAD module configuration file. If not defined, the VAD will not be used.");

		feature_opts.Register(&po);
		decodable_opts.Register(&po);
		decoder_opts.Register(&po);
		endpoint_opts.Register(&po);
		pitch_opts.Register(&po);
		word_opts.Register(&po);

		po.Read(argc, argv);

		if (po.NumArgs() != 4) {
			po.PrintUsage();
			return 1;
		}

		SetProgramName("KALDI");

		std::unique_ptr<VADInterface> VAD = nullptr;
		if (vad_config_file.empty()) {
			VAD.reset(new VADDummy());
			KALDI_LOG << "VAD not configured";
		} else {
			KALDI_LOG << "Creating VAD instance";
			VAD.reset(new VADNnet(vad_config_file));
		}



		std::string nnet3_rxfilename = po.GetArg(1),
				fst_rxfilename = po.GetArg(2),
				word_syms_filename = po.GetArg(3),
				word_boundary_rxfilename = po.GetArg(4);

		OnlineNnet2FeaturePipelineInfo feature_info(feature_opts);

		BaseFloat frame_shift = feature_info.FrameShiftInSeconds();
		int32 frame_subsampling = decodable_opts.frame_subsampling_factor;


		KALDI_VLOG(1) << "Loading AM...";

		TransitionModel trans_model;
		nnet3::AmNnetSimple am_nnet;
		{
			bool binary;
			Input ki(nnet3_rxfilename, &binary);
			trans_model.Read(ki.Stream(), binary);
			am_nnet.Read(ki.Stream(), binary);
			SetBatchnormTestMode(true, &(am_nnet.GetNnet()));
			SetDropoutTestMode(true, &(am_nnet.GetNnet()));
			nnet3::CollapseModel(nnet3::CollapseModelConfig(), &(am_nnet.GetNnet()));
		}

		// this object contains precomputed stuff that is used by all decodable
		// objects.  It takes a pointer to am_nnet because if it has iVectors it has
		// to modify the nnet to accept iVectors at intervals.
		nnet3::DecodableNnetSimpleLoopedInfo decodable_info(decodable_opts,
				&am_nnet);

		KALDI_VLOG(1) << "Loading FST...";

		fst::Fst<fst::StdArc> *decode_fst = ReadFstKaldiGeneric(fst_rxfilename);

		fst::SymbolTable *word_syms = NULL;
		if (!word_syms_filename.empty())
			if (!(word_syms = fst::SymbolTable::ReadText(word_syms_filename)))
				KALDI_ERR << "Could not read symbol table from file "
				<< word_syms_filename;

		signal(SIGPIPE, SIG_IGN); // ignore SIGPIPE to avoid crashing when socket forcefully disconnected

		WordBoundaryInfo info(word_opts, word_boundary_rxfilename);
		QuestionFinder pitchAnalyzer(info, trans_model);

		TcpServer server(read_timeout);
		server.Listen(port_num);

		std::shared_ptr<LatticeConsummerInterface> latticeOutput = nullptr;
		std::shared_ptr<OutputLayerInterface> tcpClient = nullptr;
		std::shared_ptr<AsrOutputDataCollectorInterface> dataCollector = nullptr;

		try {
			if (remote_server_protocol == "https")
				tcpClient.reset(new HTTPSOutputLayer(remote_server, remote_server_port, remote_server_path));
			else if (remote_server_protocol == "http")
				tcpClient.reset(new HTTPOutputLayer(remote_server, std::stoi(remote_server_port)));
			else
				throw std::invalid_argument("Unknown protocol "+ remote_server_protocol);
		}
		catch (std::exception& e)
		{
			KALDI_ERR << "Tcp client creation error: " << e.what();
			return 1;
		}

		VADEventObserverInterfaceSharedPtr vadObserver = std::make_shared<VADEventObserver>(tcpClient);
		VAD->registerEventObserver(vadObserver);

		float am_scale = decodable_opts.acoustic_scale;
		KALDI_LOG << "Accoustic scale: " << am_scale;
		float lm_scale = 1.0/am_scale;

		std::unique_ptr<LatticeConverterInterface> latConverter = nullptr;
		if (produce_lattices) {
			latConverter.reset(new LatticeConverter(word_syms, am_scale, lm_scale));
		} else
		{
			latConverter.reset(new LatticeConverterEmptyData());
		}
		//TODO pass to LatticeConsummerTxtFST

		latticeOutput.reset(new LatticeConsummerTxtFST(tcpClient, std::move(latConverter)));

		if(not output_files_prefix.empty()) {
			dataCollector.reset(new AsrOutputDataCollector(output_files_prefix));
			latticeOutput.reset(new LatticeConsummerDecorator(latticeOutput, tcpClient, dataCollector));
			KALDI_LOG << "Output data will be saved in to file with prefix: " << output_files_prefix;
		} else
		{
			dataCollector.reset(new AsrOutputDataCollectorDummy());
		}
		KALDI_LOG << "Lattice output layer initialized";

		while (true) {

			server.Accept();

			int32 samp_count = 0;// this is used for output refresh rate
			size_t chunk_len = static_cast<size_t>(chunk_length_secs * samp_freq);
			int32 check_period = static_cast<int32>(samp_freq * output_period);
			int32 check_count = check_period;

			int32 frame_offset = 0;
			auto pich_frame_index = 0;

			bool EndOfStream = false;

			OnlineNnet2FeaturePipeline feature_pipeline(feature_info);
			SingleUtteranceNnet3Decoder decoder(decoder_opts, trans_model,
					decodable_info,
					*decode_fst, &feature_pipeline);
			OnlinePitchFeature pitch_(pitch_opts);              // Raw pitch

			std::string session_id = randomString(16);
			VAD->clearVadSessionCounter();
			VAD->setAsrSessionId(session_id);
			uint32 latticeInVadSessionCount = 1;
			server.WriteLn(session_id, "<session>");

			while (!EndOfStream) {

				decoder.InitDecoding(frame_offset);
				OnlineSilenceWeighting silence_weighting(
						trans_model,
						feature_info.silence_weighting_config,
						decodable_opts.frame_subsampling_factor);
				std::vector<std::pair<int32, BaseFloat>> delta_weights;

				while (true) {

					EndOfStream = !server.ReadChunk(chunk_len);

					if (EndOfStream) {
						feature_pipeline.InputFinished();
						pitch_.InputFinished();

						if (silence_weighting.Active() &&
								feature_pipeline.IvectorFeature() != NULL) {
							silence_weighting.ComputeCurrentTraceback(decoder.Decoder());
							silence_weighting.GetDeltaWeights(feature_pipeline.NumFramesReady(),
									frame_offset * decodable_opts.frame_subsampling_factor,
									&delta_weights);
							feature_pipeline.UpdateFrameWeights(delta_weights);
						}

						decoder.AdvanceDecoding();
						decoder.FinalizeDecoding();
						frame_offset += decoder.NumFramesDecoded();
						if (decoder.NumFramesDecoded() > 0) {
							CompactLattice lat;
							decoder.GetLattice(true, &lat);
							std::string msg = LatticeToString(lat, *word_syms);

							// get time-span from previous endpoint to end of audio,
							int32 t_beg = frame_offset - decoder.NumFramesDecoded();

							if (msg.size() > 0) {
								dataCollector->setBestPath(msg);
								auto questionProbabylity = pitchAnalyzer.probabilityOfQuestion(lat, t_beg);
								if ( questionProbabylity > 1.0) {
									msg += "?";
								}
								latticeOutput->send(lat, questionProbabylity, msg, session_id,
										GetTimeMsToEpochString(decoder.NumFramesDecoded(), frame_shift * frame_subsampling),
										GetTimeMsToEpochString(0, frame_shift * frame_subsampling),
										VAD->vadSessionCounter(), latticeInVadSessionCount);
								latticeInVadSessionCount++;
							}

							if (produce_time) {

								msg = GetTimeString(t_beg, frame_offset, frame_shift * frame_subsampling) + " " + msg;
							}

							KALDI_LOG << " EndOfAudio, sending message: " << msg;
							server.WriteLn(msg);
						} else
							server.Write("\n");
						server.Disconnect();
						break;
					}

					Vector<BaseFloat> wave_part = server.GetChunk();
					if (!VAD->isChunkSpeech(samp_freq, wave_part))
						continue;
					if (VAD->isVadDecisionChangedInLastCheck()) {
						latticeInVadSessionCount = 1;
					}
					feature_pipeline.AcceptWaveform(samp_freq, wave_part);

					pitch_.AcceptWaveform(samp_freq, wave_part);
					auto nframes = pitch_.NumFramesReady();
					Vector<BaseFloat> feats(2);
					for (; pich_frame_index < nframes; pich_frame_index+=1) {
						pitch_.GetFrame(pich_frame_index, &feats);
						KALDI_VLOG(3) << "Frame: " << pich_frame_index << ", PITCH: " << feats(1);
						pitchAnalyzer.addFrame(PitchChunk(pich_frame_index, (int)feats(1)));
					}

					samp_count += chunk_len;

					if (silence_weighting.Active() &&
							feature_pipeline.IvectorFeature() != NULL) {
						silence_weighting.ComputeCurrentTraceback(decoder.Decoder());
						silence_weighting.GetDeltaWeights(feature_pipeline.NumFramesReady(),
								frame_offset * decodable_opts.frame_subsampling_factor,
								&delta_weights);
						feature_pipeline.UpdateFrameWeights(delta_weights);
					}

					decoder.AdvanceDecoding();

					if (samp_count > check_count) {
						if (decoder.NumFramesDecoded() > 0) {
							Lattice lat;
							decoder.GetBestPath(false, &lat);
							TopSort(&lat); // for LatticeStateTimes(),
							std::string msg = LatticeToString(lat, *word_syms);

							// get time-span after previous endpoint,
							if (produce_time) {
								int32 t_beg = frame_offset;
								int32 t_end = frame_offset + GetLatticeTimeSpan(lat);
								msg = GetTimeString(t_beg, t_end, frame_shift * frame_subsampling) + " " + msg;
							}
							if (msg.size() > 0) {
								KALDI_VLOG(1) << " Temporary transcript: " << msg;
								server.WriteLn(msg, "\r");
							}
						}
						check_count += check_period;
					}


					if (decoder.EndpointDetected(endpoint_opts)) {
						decoder.FinalizeDecoding();
						frame_offset += decoder.NumFramesDecoded();
						CompactLattice lat;
						decoder.GetLattice(true, &lat);
						//						Lattice latBestPath;
						//						decoder.GetBestPath(true, &latBestPath);
						std::string msg = LatticeToString(lat, *word_syms);
						if (msg.size() > 0) {
							int32 t_beg = frame_offset - decoder.NumFramesDecoded();
							dataCollector->setBestPath(msg);
							auto questionProbabylity = pitchAnalyzer.probabilityOfQuestion(lat, t_beg);

							if ( questionProbabylity > 1.0) {
								msg += "?";
							}
							latticeOutput->send(lat, questionProbabylity, msg, session_id,
									GetTimeMsToEpochString(decoder.NumFramesDecoded(), frame_shift * frame_subsampling),
									GetTimeMsToEpochString(0, frame_shift * frame_subsampling),
									VAD->vadSessionCounter(), latticeInVadSessionCount);							// get time-span between endpoints,
							latticeInVadSessionCount++;

							if (produce_time) {
								msg = GetTimeString(t_beg, frame_offset, frame_shift * frame_subsampling) + " " + msg;
							}

							KALDI_LOG << " Endpoint, sending message: " << msg;
							server.WriteLn(msg);
						}
						break; // while (true)
					}
				}
			}
		}
	} catch (const std::exception &e) {
		std::cerr << e.what();
		return -1;
	}
} // main()
