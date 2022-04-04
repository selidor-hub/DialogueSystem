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

#include "lat/lattice-functions.h"
#include "lat/kaldi-lattice.h"

#include <unistd.h>
#include <string>
#include <string>
#include <fstream>
#include "OutputLayerInterface.h"
#include "gtest/gtest.h"
#include <string>
#include "fstext/fstext-lib.h"
#include "lat/kaldi-lattice.h"
#include <boost/filesystem.hpp>
#include "LatticeConsummerTxtFST.h"

const char* LAT_RSPECIFIER_PATH = "ark:test/tak.lat.1";
const char* LAT_TEXT_FST_PATH = "test/tak.lat.1.words.fst.txt";
const char* LAT_TEXT_QUESTION_FST_PATH = "test/tak.question.lat.1.words.fst.txt";
const char* SYMBOLS_PATH = "test/words.txt";

class DummyOutputLayer : public OutputLayerInterface {
public:
	virtual ~DummyOutputLayer() {}

	virtual void send(const std::string& data) override {
		sentData = data;
	}

	virtual const std::string& getResponse() const override {
		return "";
	}

	virtual const std::string& getSentData() const override {
		return sentData;
	}

private:
	std::string sentData{};
};

using namespace kaldi;

TEST (ASR_Test, LatticeOutputTxtFST_output_test) {

	std::ifstream ftsIstr(LAT_TEXT_FST_PATH);
	ASSERT_TRUE(ftsIstr.is_open());

	std::string fst((std::istreambuf_iterator<char>(ftsIstr)),
	                 std::istreambuf_iterator<char>());

	auto dummyOutputPtr = std::shared_ptr<DummyOutputLayer>(new DummyOutputLayer());
	const double  acoustic_scale = 1.0, lm_scale = 12.0;
	DummyOutputLayer* outputPtr = static_cast<DummyOutputLayer*>(dummyOutputPtr.get());

	const fst::SymbolTableTextOptions opts;

	auto syms = std::unique_ptr<fst::SymbolTable>(fst::SymbolTable::ReadText(SYMBOLS_PATH, opts));
	ASSERT_TRUE(syms);

	LatticeConsummerTxtFST testObj(dummyOutputPtr,
			syms.get(),
			acoustic_scale,
			lm_scale);


	SequentialCompactLatticeReader clatReader(LAT_RSPECIFIER_PATH);
	CompactLattice clat = clatReader.Value();

	testObj.send(clat);

	ASSERT_STREQ(fst.c_str(), outputPtr->getSentData().c_str());
}

TEST (ASR_Test, LatticeOutputTxtFST_output_withPitch_test) {

	std::ifstream ftsIstr(LAT_TEXT_QUESTION_FST_PATH);
	ASSERT_TRUE(ftsIstr.is_open());

	std::string fst((std::istreambuf_iterator<char>(ftsIstr)),
	                 std::istreambuf_iterator<char>());

	auto dummyOutputPtr = std::shared_ptr<DummyOutputLayer>(new DummyOutputLayer());
	const double  acoustic_scale = 1.0, lm_scale = 12.0;
	DummyOutputLayer* outputPtr = static_cast<DummyOutputLayer*>(dummyOutputPtr.get());

	const fst::SymbolTableTextOptions opts;

	auto syms = std::unique_ptr<fst::SymbolTable>(fst::SymbolTable::ReadText(SYMBOLS_PATH, opts));
	ASSERT_TRUE(syms);

	LatticeConsummerTxtFST testObj(dummyOutputPtr,
			syms.get(),
			acoustic_scale,
			lm_scale);

	SequentialCompactLatticeReader clatReader(LAT_RSPECIFIER_PATH);
	CompactLattice clat = clatReader.Value();

	int pitchDiff = 33;

	testObj.send(clat, pitchDiff);

	ASSERT_STREQ(fst.c_str(), outputPtr->getSentData().c_str());
}

// This is not the test, this piece of code is only for fst file creation
/*
TEST (ASR_Test, make_lattice_for_all) {

	const boost::filesystem::path dir_path{"/data/DialogueSystem/ASR/lats/"};
    std::string ext(".1");
	ASSERT_TRUE(boost::filesystem::exists( dir_path ));

auto dummyOutputPtr = std::unique_ptr<DummyOutputLayer>(new DummyOutputLayer());
	const double  acoustic_scale = 1.0, lm_scale = 1.0;
	DummyOutputLayer* outputPtr = static_cast<DummyOutputLayer*>(dummyOutputPtr.get());

	const fst::SymbolTableTextOptions opts;
	auto syms = std::unique_ptr<fst::SymbolTable>(fst::SymbolTable::ReadText(SYMBOLS_PATH, opts));
	ASSERT_TRUE(syms);
	LatticeOutputTxtFST testObj(std::move(dummyOutputPtr),
			syms.get(),
			acoustic_scale,
			lm_scale);

	boost::filesystem::directory_iterator end_itr;
	for ( boost::filesystem::directory_iterator itr( dir_path );
			itr != end_itr;
			++itr )
	{
		if ( boost::filesystem::is_regular_file(itr->status())
			&& itr->path().extension() == ext )
		{
			std::cout << "@@@: " << itr->path().string() << "\n";
			SequentialCompactLatticeReader clatReader("ark:"+itr->path().string());
			CompactLattice clat = clatReader.Value();
			testObj.send(clat);
			std::ofstream ftsOstr(itr->path().string() + ".words.fst.txt");
			ASSERT_TRUE(ftsOstr.is_open());

			ftsOstr << outputPtr->getSentData();// save to file
		}
	}
}
*/

int main(int argc, char *argv[]) {
	::testing::InitGoogleTest(&argc, argv);
	return RUN_ALL_TESTS();
}
