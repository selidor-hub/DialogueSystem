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

#include <string>
#include "gtest/gtest.h"
#include "OutputDataCreator.h"

const char* emptyOutputData = R"###({"sad":{"event":"none","time":"","sad_session_id":""},"text":"","question_power":"","start_time":"","end_time":"","grid_counter_per_sad_session":"","grid":"","session":""})###";

const char* onlySessionOutputData = R"###({"sad":{"event":"none","time":"","sad_session_id":""},"text":"","question_power":"","start_time":"","end_time":"","grid_counter_per_sad_session":"","grid":"","session":"12321"})###";

const char* onlyTextOutputData = R"###({"sad":{"event":"none","time":"","sad_session_id":""},"text":"lalalala","question_power":"","start_time":"","end_time":"","grid_counter_per_sad_session":"","grid":"","session":""})###";

const char* onlyLatticeOutputData = R"###({"sad":{"event":"none","time":"","sad_session_id":""},"text":"","question_power":"","start_time":"","end_time":"","grid_counter_per_sad_session":"","grid":"1 2 test 1.1\n3 3 ? 0.1\n\n","session":""})###";

const char* allSetOutputData = R"###({"sad":{"event":"none","time":"","sad_session_id":""},"text":"lalalala","question_power":"","start_time":"12333","end_time":"12444","grid_counter_per_sad_session":"","grid":"1 2 test 1.1\n3 3 ? 0.1\n\n","session":"12321"})###";

const char* startEventData = R"###({"sad":{"event":"start","time":"123456","sad_session_id":"000001"},"text":"","question_power":"","start_time":"","end_time":"","grid_counter_per_sad_session":"","grid":"","session":""})###";

const char* onlyQuestionPowerData = R"###({"sad":{"event":"none","time":"","sad_session_id":""},"text":"","question_power":"1.5","start_time":"","end_time":"","grid_counter_per_sad_session":"","grid":"","session":""})###";


TEST (ASR_Test, OutputDataCreator_creatre) {

	OutputDataCreator creator;
	ASSERT_STREQ(emptyOutputData, creator.create().c_str());
}

TEST (ASR_Test, OutputDataCreator_setSessionId) {

	OutputDataCreator creator;
	ASSERT_STREQ(onlySessionOutputData, creator.setSessionId("12321").create().c_str());
}

TEST (ASR_Test, OutputDataCreator_setText) {

	OutputDataCreator creator;
	ASSERT_STREQ(onlyTextOutputData, creator.setText("lalalala").create().c_str());
}

TEST (ASR_Test, OutputDataCreator_setTextTwoTimes) {

	OutputDataCreator creator;
	creator.setText("nnnnnnnnnnnn");
	creator.setText("lalalala");
	ASSERT_STREQ(onlyTextOutputData, creator.create().c_str());
}

TEST (ASR_Test, OutputDataCreator_setLattice) {

	OutputDataCreator creator;
	ASSERT_STREQ(onlyLatticeOutputData, creator.setLattice("1 2 test 1.1\n3 3 ? 0.1\n\n").create().c_str());
}

TEST (ASR_Test, OutputDataCreator_setAll) {

	OutputDataCreator creator;
	ASSERT_STREQ(allSetOutputData, creator.setSessionId("12321").setText("lalalala").setLattice("1 2 test 1.1\n3 3 ? 0.1\n\n").setLatticeTimeSpan("12333","12444").create().c_str());
}

TEST (ASR_Test, setEventAll) {
	OutputDataCreator creator;
	ASSERT_STREQ(startEventData, creator.setSadEvent(SadEvent::start).setSadEventTime("123456").setSadSessionId("000001").create().c_str());
}


TEST (ASR_Test, setQuestionPower) {
	OutputDataCreator creator;
	ASSERT_STREQ(onlyQuestionPowerData, creator.setQuestionPower("1.5").create().c_str());
}

int main(int argc, char *argv[]) {
	::testing::InitGoogleTest(&argc, argv);
	return RUN_ALL_TESTS();
}
