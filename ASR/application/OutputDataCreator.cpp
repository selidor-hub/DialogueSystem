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

#include "OutputDataCreator.h"
#include <boost/algorithm/string/replace.hpp>

OutputDataCreator::OutputDataCreator() {
}

OutputDataCreator::~OutputDataCreator() {
}

bool OutputDataCreator::prepareOutput(const std::string &from,
		const std::string &to) {
	size_t start_pos = outputTemplate.find(from);
	if (start_pos == std::string::npos)
		return false;

	outputTemplate.replace(start_pos, from.length(), to);
	return true;
}

std::string OutputDataCreator::create() {
	prepareOutput(sessionIdTag, id);
	prepareOutput(textTag, text);
	boost::algorithm::replace_all( lattice, "\n", "\\n" );// for python json parser
	prepareOutput(latticeTag, lattice);
	prepareOutput(startTimeIdTag, latStart);
	prepareOutput(endTimeIdTag, latEnd);
	prepareOutput(sadEventTag, sadEvent);
	prepareOutput(sadTimeTag, sadTime);
	prepareOutput(sadSessionIdTag, sadSessionId);
	prepareOutput(latticeCounterTag, latticeCounter);
	prepareOutput(questionPowerTag, questionPower);
	return outputTemplate;
}

OutputDataCreator& OutputDataCreator::setSessionId(const std::string &id) {
	this->id = id;
	return *this;
}

OutputDataCreator& OutputDataCreator::setText(const std::string &text) {
	this->text = text;
	return *this;
}

OutputDataCreator& OutputDataCreator::setLattice(const std::string &lattice) {
	this->lattice = lattice;
	return *this;
}

OutputDataCreator& OutputDataCreator::setLatticeTimeSpan(const std::string& time_start, const std::string& time_end) {
	this->latStart = time_start;
	this->latEnd = time_end;
	return *this;
}

OutputDataCreator& OutputDataCreator::setSadEvent(const SadEvent &event) {
	this->sadEvent = eventMap.at(event);
	return *this;
}

OutputDataCreator& OutputDataCreator::setSadEventTime(const std::string &time) {
	this->sadTime = time;
	return *this;
}

OutputDataCreator& OutputDataCreator::setSadSessionId(
		const std::string &sessionId) {
	this->sadSessionId = sessionId;
	return *this;
}

OutputDataCreator& OutputDataCreator::setLatticeCounter(
		const std::string &latticeCount) {
	this->latticeCounter = latticeCount;
	return *this;
}

OutputDataCreator& OutputDataCreator::setQuestionPower(
		const std::string &questionPower) {
	this->questionPower = questionPower;
	return *this;
}
