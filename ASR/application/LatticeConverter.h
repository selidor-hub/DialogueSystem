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

#ifndef LATTICECONVERTER_H_
#define LATTICECONVERTER_H_

#include "base/kaldi-common.h"
#include "util/common-utils.h"
#include "fstext/fstext-lib.h"
#include "LatticeConverterInterface.h"

namespace kaldi {

class LatticeConverterEmptyData: public LatticeConverterInterface {
public:
	LatticeConverterEmptyData() = default;
	virtual ~LatticeConverterEmptyData() = default;

	virtual std::string convert(const CompactLattice& lat) override;
};

class LatticeConverter: public LatticeConverterInterface {
public:
	LatticeConverter(fst::SymbolTable* symbol_table,
			BaseFloat acoustic_scale, BaseFloat lm_scale);
	virtual ~LatticeConverter();

	virtual std::string convert(const CompactLattice& lat) override;

private:
	void convertLatToFst(const CompactLattice& clat, fst::VectorFst<fst::StdArc>* fst);

	fst::SymbolTable* symbolTable;
	BaseFloat acousticScale;
	BaseFloat lmScale;
};

} /* namespace kaldi */

#endif /* LATTICECONVERTER_H_ */
