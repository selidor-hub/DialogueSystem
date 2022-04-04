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

#include "LatticeConverter.h"
#include "base/kaldi-common.h"
#include "util/common-utils.h"
#include "fstext/fstext-lib.h"

namespace kaldi {

LatticeConverter::LatticeConverter(fst::SymbolTable* symbol_table,
		BaseFloat acoustic_scale, BaseFloat lm_scale):
					symbolTable(symbol_table),
					acousticScale(acoustic_scale),
					lmScale(lm_scale) {
}

LatticeConverter::~LatticeConverter() {
}

std::string LatticeConverterEmptyData::convert(const CompactLattice &lat) {
	return "";
}

std::string LatticeConverter::convert(const CompactLattice &lat) {
	CompactLattice clat = lat;
	const auto scale = fst::LatticeScale(lmScale, acousticScale);

	ScaleLattice(scale, &clat);
	RemoveAlignmentsFromCompactLattice(&clat);

	fst::VectorFst<fst::StdArc> fst;
	convertLatToFst(clat, &fst);
	fst::RemoveEpsLocal(&fst);

	std::stringstream ss;
	const bool acceptor = true, write_one = false;
	fst::FstPrinter<fst::StdArc> printer(fst, symbolTable, symbolTable,
			nullptr, acceptor, write_one, " ");
	printer.Print(&ss, "<unknown>");

	return ss.str()+"\n";
}

void LatticeConverter::convertLatToFst(const CompactLattice& clat, fst::VectorFst<fst::StdArc>* fst){
	Lattice lat;
	ConvertLattice(clat, &lat); // convert to non-compact form.. won't introduce
	// extra states because already removed alignments.
	ConvertLattice(lat, fst); // this adds up the (lm,acoustic) costs to get
	// the normal (tropical) costs.
	Project(fst, fst::PROJECT_OUTPUT); // Because in the standard Lattice format,
	// the words are on the output, and we want the word labels.
}

} /* namespace kaldi */
