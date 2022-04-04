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

#ifndef TIME_UTILS_H_
#define TIME_UTILS_H_
#include <string>
#include <chrono>
#include <sstream>

namespace time_utils {

std::string getTimeToEpoch_ms() {
	std::stringstream ss;
	auto now = std::chrono::system_clock::now().time_since_epoch();
	ss << std::chrono::duration_cast<std::chrono::milliseconds>(now).count();
	return ss.str();
}

}

#endif /* TIME_UTILS_H_ */
