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

#ifndef LATTICECONVERTERINTERFACE_H_
#define LATTICECONVERTERINTERFACE_H_
#include <string>
#include "lat/lattice-functions.h"
#include "fstext/fstext-lib.h"

class LatticeConverterInterface {
public:
	virtual ~LatticeConverterInterface() = default;
	virtual std::string convert(const kaldi::CompactLattice& lat) = 0;
};



#endif /* LATTICECONVERTERINTERFACE_H_ */
