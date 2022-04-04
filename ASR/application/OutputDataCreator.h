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

#ifndef OUTPUTDATACREATOR_H_
#define OUTPUTDATACREATOR_H_
#include <string>
#include <map>

enum class SadEvent {
	none,
	start,
	end
};

class OutputDataCreator {
public:
	OutputDataCreator();
	virtual ~OutputDataCreator();

	std::string create();
	OutputDataCreator& setSessionId(const std::string& id);
	OutputDataCreator& setText(const std::string& text);
	OutputDataCreator& setLattice(const std::string& lattice);
	OutputDataCreator& setLatticeTimeSpan(const std::string& time_start, const std::string& time_end);
	OutputDataCreator& setSadEvent(const SadEvent& event);
	OutputDataCreator& setSadEventTime(const std::string& time);
	OutputDataCreator& setSadSessionId(const std::string& sessionId);
	OutputDataCreator& setLatticeCounter(const std::string& latticeCount);
	OutputDataCreator& setQuestionPower(const std::string& questionPower);


private:
	const std::map<SadEvent, std::string> eventMap {
		{SadEvent::none, "none"},
		{SadEvent::start, "start"},
		{SadEvent::end, "end"}
	};

	std::string outputTemplate{R"###({"sad":{"event":"EEEE","time":"RRRR","sad_session_id":"FFFF"},"text":"TTTT","question_power":"QPQP","start_time":"QQQQ","end_time":"AAAA","grid_counter_per_sad_session":"ZZZZ","grid":"LLLL","session":"SSSS"})###"};

	const std::string latticeTag = "LLLL";
	const std::string textTag = "TTTT";
	const std::string sessionIdTag = "SSSS";
	const std::string startTimeIdTag = "QQQQ";
	const std::string endTimeIdTag = "AAAA";
	const std::string sadEventTag = "EEEE";
	const std::string sadTimeTag = "RRRR";
	const std::string sadSessionIdTag = "FFFF";
	const std::string latticeCounterTag = "ZZZZ";
	std::string questionPowerTag = "QPQP";
	std::string id{};
	std::string text{};
	std::string lattice{};
	std::string latStart{};
	std::string latEnd{};
	std::string sadEvent{"none"};
	std::string sadTime{};
	std::string sadSessionId{};
	std::string latticeCounter{};
	std::string questionPower{};

	bool prepareOutput(const std::string &from, const std::string &to);

};

#endif /* OUTPUTDATACREATOR_H_ */
